import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'music_metadata_service.dart';
import 'notification_service.dart';

class RoomService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final MusicMetadataService metadataService = MusicMetadataService();
  final NotificationService notificationService = NotificationService();

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

    await notificationService.subscribeToRoomTopic(roomRef.id);

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

    await notificationService.subscribeToRoomTopic(roomId);

    return roomId;
  }

  Future<List<String>> _memberUserIds(String roomId) async {
    final members = await db.collection('rooms').doc(roomId).collection('members').get();
    return members.docs.map((d) => (d.data()['uid'] ?? '').toString()).where((uid) => uid.isNotEmpty).toList();
  }

  Future<void> _publishRoomEvent({
    required String roomId,
    required String type,
    required String title,
    required String body,
    required List<String> targetUserIds,
    Map<String, dynamic> payload = const {},
  }) async {
    if (targetUserIds.isEmpty) return;
    await db.collection('rooms').doc(roomId).collection('events').add({
      'type': type,
      'title': title,
      'body': body,
      'targetUserIds': targetUserIds,
      'actorUserId': auth.currentUser?.uid,
      'payload': payload,
      'createdAt': FieldValue.serverTimestamp(),
    });
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

    final memberIds = await _memberUserIds(roomId);
    final targets = memberIds.where((uid) => uid != user.uid).toList();
    await _publishRoomEvent(
      roomId: roomId,
      type: 'song_added',
      title: 'New Song Added',
      body: '${user.displayName ?? 'Someone'} added $title by $artist',
      targetUserIds: targets,
      payload: {
        'songId': songRef.id,
        'songTitle': title,
        'artist': artist,
      },
    );

    // Enrich song metadata asynchronously (fire-and-forget)
    _enrichSongAsync(roomId, songRef.id, title, artist);
  }

  /// Enrich song metadata asynchronously
  Future<void> _enrichSongAsync(String roomId, String songId, String title, String artist) async {
    try {
      final metadata = await metadataService.searchTrackMetadata(title: title, artist: artist);
      if (metadata != null) {
        final cachedUrl = await metadataService.cacheAlbumArt(
          roomId: roomId,
          songId: songId,
          albumArtUrl: metadata['albumArtUrl'] ?? '',
        );

        await metadataService.enrichSongInFirestore(
          roomId: roomId,
          songId: songId,
          metadata: metadata,
          cachedAlbumArtUrl: cachedUrl,
        );
      }
    } catch (e) {
    }
  }

  Future<void> voteOnSong({
    required String roomId,
    required String songId,
    required int voteValue,
  }) async {
    final user = auth.currentUser!;
    final songRef = db.collection('rooms').doc(roomId).collection('queue').doc(songId);
    final voteRef = songRef.collection('votes').doc(user.uid);

    final result = await _withStepTimeout(
      db.runTransaction<Map<String, dynamic>>((transaction) async {
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

        return {
          'ownerId': (songData['addedBy'] ?? '').toString(),
          'songTitle': (songData['title'] ?? '').toString(),
          'artist': (songData['artist'] ?? '').toString(),
          'currentScore': currentScore,
          'nextScore': nextScore,
        };
      }),
      'Voting on song',
      timeout: const Duration(seconds: 12),
    );

    final ownerId = (result['ownerId'] ?? '').toString();
    final wasUpvote = voteValue == 1;
    final scoreIncreased = (result['nextScore'] as int) > (result['currentScore'] as int);
    if (ownerId.isNotEmpty && ownerId != user.uid && wasUpvote && scoreIncreased) {
      await _publishRoomEvent(
        roomId: roomId,
        type: 'song_voted_up',
        title: 'Your Song Got Voted Up',
        body: 'Your song ${result['songTitle']} got an upvote.',
        targetUserIds: [ownerId],
        payload: {
          'songId': songId,
          'songTitle': result['songTitle'],
          'artist': result['artist'],
          'newScore': result['nextScore'],
        },
      );
    }

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

        final nextSnap = await queueRef.orderBy('position').orderBy('voteScore', descending: true).limit(2).get();
        if (nextSnap.docs.isEmpty) {
          await roomRef.set({'nowPlaying': null}, SetOptions(merge: true));
          return;
        }

        final nextDoc = nextSnap.docs.first;
        final nextData = nextDoc.data();
        final onDeck = nextSnap.docs.length > 1 ? nextSnap.docs[1].data() : null;
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

        final actorId = auth.currentUser?.uid ?? '';
        final memberIds = await _memberUserIds(roomId);
        final roomTargets = memberIds.where((uid) => uid != actorId).toList();

        await _publishRoomEvent(
          roomId: roomId,
          type: 'room_started',
          title: 'Room Started Playing',
          body: 'Now playing ${nextData['title'] ?? ''} by ${nextData['artist'] ?? ''}.',
          targetUserIds: roomTargets,
          payload: {
            'songId': nextDoc.id,
            'songTitle': nextData['title'],
            'artist': nextData['artist'],
          },
        );

        final onDeckUserId = (onDeck?['addedBy'] ?? '').toString();
        if (onDeckUserId.isNotEmpty && onDeckUserId != actorId) {
          await _publishRoomEvent(
            roomId: roomId,
            type: 'turn_to_act',
            title: 'Your Turn Is Coming Up',
            body: 'Your queued song ${onDeck?['title'] ?? ''} is up next. Get ready.',
            targetUserIds: [onDeckUserId],
            payload: {
              'songTitle': onDeck?['title'],
              'artist': onDeck?['artist'],
            },
          );
        }
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
