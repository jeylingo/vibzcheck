import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<T> _withStepTimeout<T>(Future<T> future, String step, {Duration timeout = const Duration(seconds: 10)}) {
    return future.timeout(timeout, onTimeout: () {
      throw Exception('$step timed out after ${timeout.inSeconds} seconds. Check Firestore rules, auth, and network.');
    });
  }

  String _generateCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _roomDoc(String roomId) {
    return db.collection('rooms').doc(roomId).get();
  }

  Future<bool> _isHost(String roomId) async {
    final roomSnap = await _roomDoc(roomId);
    final data = roomSnap.data();
    return data != null && data['ownerId'] == auth.currentUser?.uid;
  }

  Future<bool> _isMember(String roomId) async {
    final user = auth.currentUser;
    if (user == null) return false;
    final memberSnap = await db.collection('rooms').doc(roomId).collection('members').doc(user.uid).get();
    return memberSnap.exists;
  }

  Future<Map<String, String>> createRoom(String title, {bool isPrivate = false}) async {
    final user = auth.currentUser!;

    // Generate a short room code without querying Firestore first.
    // A pre-read on the rooms collection can be rejected by security rules.
    final code = _generateCode(6);

    final roomRef = db.collection('rooms').doc();
    final memberRef = roomRef.collection('members').doc(user.uid);

    final batch = db.batch();
    batch.set(roomRef, {
      'title': title,
      'ownerId': user.uid,
      'code': code,
      'isPrivate': isPrivate,
      'queueLocked': false,
      'nowPlaying': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(memberRef, {
      'uid': user.uid,
      'displayName': user.displayName ?? user.email ?? user.uid,
      'role': 'host',
      'joinedAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    });

    await _withStepTimeout(
      batch.commit(),
      'Creating room batch',
      timeout: const Duration(seconds: 12),
    );

    return {'roomId': roomRef.id, 'code': code};
  }

  Future<String> joinRoomByCode(String code) async {
    final user = auth.currentUser!;

    final snap = await _withStepTimeout(
      db.collection('rooms').where('code', isEqualTo: code).limit(1).get(),
      'Looking up room by code',
      timeout: const Duration(seconds: 8),
    );
    if (snap.docs.isEmpty) throw Exception('Room not found');

    final roomDoc = snap.docs.first;
    final roomId = roomDoc.id;

    await _withStepTimeout(
      db.collection('rooms').doc(roomId).collection('members').doc(user.uid).set({
        'uid': user.uid,
        'displayName': user.displayName ?? user.email ?? user.uid,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      }),
      'Saving room member record',
      timeout: const Duration(seconds: 10),
    );

    return roomId;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRoomQueue(String roomId) {
    return db.collection('rooms').doc(roomId).collection('queue').orderBy('position').orderBy('voteScore', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRoomMembers(String roomId) {
    return db.collection('rooms').doc(roomId).collection('members').snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoomState(String roomId) {
    return db.collection('rooms').doc(roomId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRoomHistory(String roomId) {
    return db.collection('rooms').doc(roomId).collection('history').orderBy('playedAt', descending: true).limit(10).snapshots();
  }

  Future<void> addSongToQueue({
    required String roomId,
    required String title,
    required String artist,
    required String genre,
    List<String> moods = const [],
  }) async {
    final user = auth.currentUser!;

    final isHost = await _isHost(roomId);
    final isMember = await _isMember(roomId);
    if (!isHost && !isMember) {
      throw Exception('You must join the room before adding songs.');
    }

    final roomRef = db.collection('rooms').doc(roomId);
    final queueRef = roomRef.collection('queue');
    final topSnap = await queueRef.orderBy('position', descending: true).limit(1).get();
    final nextPosition = topSnap.docs.isEmpty ? 0 : ((topSnap.docs.first.data()['position'] ?? 0) as int) + 1;

    final songRef = queueRef.doc();

    final roomSnap = await _roomDoc(roomId);
    final roomData = roomSnap.data();
    final queueLocked = roomData?['queueLocked'] == true;
    if (queueLocked && !isHost) {
      throw Exception('Queue is locked by the host.');
    }

    final batch = db.batch();
    batch.set(songRef, {
      'title': title,
      'artist': artist,
      'genre': genre.toLowerCase(),
      'moods': moods,
      'addedBy': user.uid,
      'voteScore': 0,
      'position': nextPosition,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _withStepTimeout(
      batch.commit(),
      'Adding song to room queue',
      timeout: const Duration(seconds: 12),
    );
  }

  Future<void> voteOnSong({
    required String roomId,
    required String songId,
    required int voteValue,
  }) async {
    final user = auth.currentUser!;
    final songRef = db.collection('rooms').doc(roomId).collection('queue').doc(songId);
    final voteRef = songRef.collection('votes').doc(user.uid);

    await _withStepTimeout(
      db.runTransaction((transaction) async {
        final songSnap = await transaction.get(songRef);
        if (!songSnap.exists) {
          throw Exception('Song not found');
        }

        final songData = songSnap.data() as Map<String, dynamic>;
        final currentScore = (songData['voteScore'] ?? 0) as int;

        int previousVote = 0;
        final voteSnap = await transaction.get(voteRef);
        if (voteSnap.exists) {
          final voteData = voteSnap.data() as Map<String, dynamic>;
          previousVote = (voteData['voteValue'] ?? 0) as int;
        }

        final nextScore = currentScore - previousVote + voteValue;

        transaction.set(voteRef, {
          'userId': user.uid,
          'voteValue': voteValue,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(songRef, {
          'voteScore': nextScore,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }),
      'Voting on song',
      timeout: const Duration(seconds: 12),
    );
  }

  Future<void> moveSongUp({
    required String roomId,
    required String songId,
  }) async {
    if (!await _isHost(roomId)) {
      throw Exception('Only the host can reorder the queue.');
    }

    final queueRef = db.collection('rooms').doc(roomId).collection('queue');
    final songRef = queueRef.doc(songId);

    await _withStepTimeout(
      () async {
        final songSnap = await songRef.get();
        if (!songSnap.exists) throw Exception('Song not found');

        final songData = songSnap.data() as Map<String, dynamic>;
        final currentPosition = (songData['position'] ?? 0) as int;
        if (currentPosition <= 0) return;

        final aboveSnap = await queueRef.where('position', isEqualTo: currentPosition - 1).limit(1).get();
        final batch = db.batch();

        if (aboveSnap.docs.isEmpty) {
          batch.update(songRef, {'position': currentPosition - 1, 'updatedAt': FieldValue.serverTimestamp()});
        } else {
          final aboveRef = aboveSnap.docs.first.reference;
          final aboveData = aboveSnap.docs.first.data();
          final abovePosition = (aboveData['position'] ?? currentPosition - 1) as int;

          batch.update(aboveRef, {'position': currentPosition, 'updatedAt': FieldValue.serverTimestamp()});
          batch.update(songRef, {'position': abovePosition, 'updatedAt': FieldValue.serverTimestamp()});
        }

        await batch.commit();
      }(),
      'Moving song up',
      timeout: const Duration(seconds: 12),
    );
  }

  Future<void> removeSong({
    required String roomId,
    required String songId,
  }) async {
    if (!await _isHost(roomId)) {
      throw Exception('Only the host can remove songs.');
    }

    await _withStepTimeout(
      db.collection('rooms').doc(roomId).collection('queue').doc(songId).delete(),
      'Removing song',
      timeout: const Duration(seconds: 10),
    );
  }

  Future<void> skipToNext({required String roomId}) async {
    if (!await _isHost(roomId)) {
      throw Exception('Only the host can skip songs.');
    }

    final roomRef = db.collection('rooms').doc(roomId);
    final queueRef = roomRef.collection('queue');
    final historyRef = roomRef.collection('history');

    await _withStepTimeout(
      () async {
        final roomSnap = await roomRef.get();
        final roomData = roomSnap.data();
        final currentNowPlaying = roomData?['nowPlaying'] as Map<String, dynamic>?;

        final nextSnap = await queueRef.orderBy('position').orderBy('voteScore', descending: true).limit(1).get();
        if (nextSnap.docs.isEmpty) {
          await roomRef.set({'nowPlaying': null}, SetOptions(merge: true));
          return;
        }

        final nextDoc = nextSnap.docs.first;
        final nextData = nextDoc.data();
        final batch = db.batch();

        if (currentNowPlaying != null) {
          final historyDoc = historyRef.doc();
          batch.set(historyDoc, {
            ...currentNowPlaying,
            'playedAt': FieldValue.serverTimestamp(),
          });
        }

        batch.set(roomRef, {
          ...(roomData ?? {}),
          'nowPlaying': {
            ...nextData,
            'songId': nextDoc.id,
            'startedAt': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));

        batch.delete(nextDoc.reference);
        await batch.commit();
      }(),
      'Skipping to next song',
      timeout: const Duration(seconds: 12),
    );
  }

  Future<void> setQueueLocked({
    required String roomId,
    required bool locked,
  }) async {
    if (!await _isHost(roomId)) {
      throw Exception('Only the host can lock the queue.');
    }

    await _withStepTimeout(
      db.collection('rooms').doc(roomId).update({'queueLocked': locked}),
      'Updating queue lock',
      timeout: const Duration(seconds: 10),
    );
  }
}
