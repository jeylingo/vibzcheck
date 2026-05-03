import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> addHistory(String title, String artist, String genre, List<String> moods) async {
    final user = auth.currentUser!;
    final normalizedGenre = genre.toLowerCase();
    final normalizedMoods = moods
        .map((m) => m.trim().toLowerCase())
        .where((m) => m.isNotEmpty)
        .toList();

    await db.collection('listeningHistory').add({
      'userId': user.uid,
      'title': title,
      'artist': artist,
      'genre': normalizedGenre,
      'moods': normalizedMoods,
      'playedAt': FieldValue.serverTimestamp(),
    });

    final userRef = db.collection('users').doc(user.uid);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      final activity = (data['listeningActivity'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      final totalPlays = (activity['totalPlays'] ?? 0) as int;
      final genrePlayCounts = Map<String, dynamic>.from(activity['genrePlayCounts'] ?? <String, dynamic>{});
      final currentGenreCount = (genrePlayCounts[normalizedGenre] ?? 0) as int;
      genrePlayCounts[normalizedGenre] = currentGenreCount + 1;

      transaction.set(userRef, {
        'uid': user.uid,
        'email': user.email,
        'name': (data['name'] ?? user.displayName ?? user.email ?? user.uid).toString(),
        'photoUrl': (data['photoUrl'] ?? user.photoURL ?? '').toString(),
        'preferredGenres': List<String>.from(data['preferredGenres'] ?? const <String>[]),
        'listeningActivity': {
          'totalPlays': totalPlays + 1,
          'genrePlayCounts': genrePlayCounts,
          'lastPlayedAt': FieldValue.serverTimestamp(),
          'lastSong': {
            'title': title,
            'artist': artist,
            'genre': normalizedGenre,
            'moods': normalizedMoods,
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}