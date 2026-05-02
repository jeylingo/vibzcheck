import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecommendationService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<List<Map<String, dynamic>>> getRecommendations() async {
    final user = auth.currentUser!;

    final historySnap = await db
        .collection('listeningHistory')
        .where('userId', isEqualTo: user.uid)
        .get();

    final songsSnap = await db.collectionGroup('songs').get();

    final listenedGenres = <String>{};
    final listenedMoods = <String>{};

    for (final doc in historySnap.docs) {
      final data = doc.data();
      listenedGenres.add((data['genre'] ?? '').toString());

      final moods = List<String>.from(data['moods'] ?? []);
      listenedMoods.addAll(moods);
    }

    final results = <Map<String, dynamic>>[];

    for (final doc in songsSnap.docs) {
      final song = doc.data();

      final voteScore = song['voteScore'] ?? 0;
      final genre = (song['genre'] ?? '').toString();
      final moods = List<String>.from(song['moods'] ?? []);

      int historyScore = listenedGenres.contains(genre) ? 3 : 0;
      int moodScore = 0;

      for (final mood in moods) {
        if (listenedMoods.contains(mood)) {
          moodScore += 2;
        }
      }

      final totalScore = voteScore + historyScore + moodScore;

      results.add({
        ...song,
        'recommendationScore': totalScore,
        'reason': 'Votes: $voteScore, History: $historyScore, Mood: $moodScore',
      });
    }

    results.sort((a, b) => b['recommendationScore'].compareTo(a['recommendationScore']));

    return results;
  }
}