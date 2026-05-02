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

  Future<Map<String, String>> createRoom(String title, {bool isPrivate = false}) async {
    final user = auth.currentUser!;

    String code = _generateCode(6);
    for (int i = 0; i < 5; i++) {
      final snap = await db
          .collection('rooms')
          .where('code', isEqualTo: code)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8), onTimeout: () {
        throw Exception('Room code check timed out. Check Firestore access.');
      });
      if (snap.docs.isEmpty) break;
      code = _generateCode(6);
    }

    final roomRef = db.collection('rooms').doc();
    final memberRef = roomRef.collection('members').doc(user.uid);

    final batch = db.batch();
    batch.set(roomRef, {
      'title': title,
      'ownerId': user.uid,
      'code': code,
      'isPrivate': isPrivate,
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
    return db.collection('rooms').doc(roomId).collection('queue').orderBy('voteScore', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRoomMembers(String roomId) {
    return db.collection('rooms').doc(roomId).collection('members').snapshots();
  }

  Future<void> addSongToQueue({
    required String roomId,
    required String title,
    required String artist,
    required String genre,
    List<String> moods = const [],
  }) async {
    final user = auth.currentUser!;
    final songRef = db.collection('rooms').doc(roomId).collection('queue').doc();

    final batch = db.batch();
    batch.set(songRef, {
      'title': title,
      'artist': artist,
      'genre': genre.toLowerCase(),
      'moods': moods,
      'addedBy': user.uid,
      'voteScore': 0,
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
}
