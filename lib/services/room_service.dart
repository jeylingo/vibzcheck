import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

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

    // create unique short code
    String code = _generateCode(6);
    // ensure uniqueness (simple loop)
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
}
