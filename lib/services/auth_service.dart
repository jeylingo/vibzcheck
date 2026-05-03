import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  User? get currentUser => auth.currentUser;

  Future<void> register(
    String name,
    String email,
    String password, {
    String photoUrl = '',
    List<String> preferredGenres = const [],
  }) async {
    final userCredential = await auth
        .createUserWithEmailAndPassword(
          email: email,
          password: password,
        )
        .timeout(const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Sign-up took too long. Check your connection.'));

    final normalizedGenres = preferredGenres
        .map((g) => g.trim().toLowerCase())
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList();

    await db.collection('users').doc(userCredential.user!.uid).set({
      'uid': userCredential.user!.uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'preferredGenres': normalizedGenres,
      'listeningActivity': {
        'totalPlays': 0,
        'genrePlayCounts': <String, int>{},
        'lastPlayedAt': null,
        'lastSong': null,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    })
        .timeout(const Duration(seconds: 10),
            onTimeout: () => throw Exception(
                'Saving profile took too long. Try again.'));
  }

  Future<void> login(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _ensureUserProfile(
      uid: credential.user!.uid,
      email: credential.user!.email ?? email,
      displayName: credential.user!.displayName ?? '',
      photoUrl: credential.user!.photoURL ?? '',
    );

    await db.collection('users').doc(credential.user!.uid).set({
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateProfile({
    required String uid,
    required String name,
    String? photoUrl,
    List<String>? preferredGenres,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (photoUrl != null) {
      payload['photoUrl'] = photoUrl;
    }

    if (preferredGenres != null) {
      payload['preferredGenres'] = preferredGenres
          .map((g) => g.trim().toLowerCase())
          .where((g) => g.isNotEmpty)
          .toSet()
          .toList();
    }

    await db.collection('users').doc(uid).set(payload, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile(String uid) {
    return db.collection('users').doc(uid).snapshots();
  }

  Future<void> _ensureUserProfile({
    required String uid,
    required String email,
    required String displayName,
    required String photoUrl,
  }) async {
    final ref = db.collection('users').doc(uid);
    final snapshot = await ref.get();
    if (snapshot.exists) return;

    await ref.set({
      'uid': uid,
      'name': displayName.isNotEmpty ? displayName : email.split('@').first,
      'email': email,
      'photoUrl': photoUrl,
      'preferredGenres': <String>[],
      'listeningActivity': {
        'totalPlays': 0,
        'genrePlayCounts': <String, int>{},
        'lastPlayedAt': null,
        'lastSong': null,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> logout() async {
    await auth.signOut();
  }
}