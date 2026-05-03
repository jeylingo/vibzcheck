import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecommendationService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  static const double _voteWeight = 0.45;
  static const double _historyWeight = 0.35;
  static const double _moodWeight = 0.20;

  static const double _sparseVoteWeight = 0.55;
  static const double _sparseHistoryWeight = 0.25;
  static const double _sparseMoodWeight = 0.20;

  Future<List<Map<String, dynamic>>> getRecommendations() async {
    final user = auth.currentUser;
    if (user == null) {
      return [];
    }

    final historySnap = await db
        .collection('listeningHistory')
        .where('userId', isEqualTo: user.uid)
        .orderBy('playedAt', descending: true)
        .limit(200)
        .get();

    final songsSnap = await db.collectionGroup('songs').get();
    if (songsSnap.docs.isEmpty) {
      return [];
    }

    final genreFrequency = <String, int>{};
    final moodFrequency = <String, int>{};
    final artistFrequency = <String, int>{};

    for (final doc in historySnap.docs) {
      final data = doc.data();
      final genre = (data['genre'] ?? '').toString().trim().toLowerCase();
      final artist = (data['artist'] ?? '').toString().trim().toLowerCase();
      final moods = List<String>.from(data['moods'] ?? const <String>[])
          .map((m) => m.trim().toLowerCase())
          .where((m) => m.isNotEmpty)
          .toList();

      if (genre.isNotEmpty) {
        genreFrequency[genre] = (genreFrequency[genre] ?? 0) + 1;
      }
      if (artist.isNotEmpty) {
        artistFrequency[artist] = (artistFrequency[artist] ?? 0) + 1;
      }
      for (final mood in moods) {
        moodFrequency[mood] = (moodFrequency[mood] ?? 0) + 1;
      }
    }

    final hasEnoughHistory = historySnap.docs.length >= 5;

    final allVoteScores = songsSnap.docs
        .map((doc) => (doc.data()['voteScore'] ?? 0) as int)
        .toList();
    final maxAbsVote = allVoteScores
        .map((v) => v.abs())
        .fold<int>(1, (a, b) => b > a ? b : a);
    final hasVoteSignal = allVoteScores.any((v) => v != 0);

    final voteWeight = hasEnoughHistory ? _voteWeight : _sparseVoteWeight;
    final historyWeight = hasEnoughHistory ? _historyWeight : _sparseHistoryWeight;
    final moodWeight = hasEnoughHistory ? _moodWeight : _sparseMoodWeight;

    final results = <Map<String, dynamic>>[];
    for (final doc in songsSnap.docs) {
      final song = doc.data();
      final title = (song['title'] ?? '').toString();
      final artist = (song['artist'] ?? '').toString().trim().toLowerCase();
      final genre = (song['genre'] ?? '').toString().trim().toLowerCase();
      final moods = List<String>.from(song['moods'] ?? const <String>[])
          .map((m) => m.trim().toLowerCase())
          .where((m) => m.isNotEmpty)
          .toList();
      final voteScore = (song['voteScore'] ?? 0) as int;

      final voteSignal = ((voteScore / maxAbsVote) + 1) / 2;

      final genreSignal = _normalizedSignal(genreFrequency, genre);
      final artistSignal = _normalizedSignal(artistFrequency, artist);

      double moodSignal = 0;
      if (moods.isNotEmpty) {
        final perMoodSignals = moods.map((m) => _normalizedSignal(moodFrequency, m));
        moodSignal = perMoodSignals.fold<double>(0, (a, b) => a + b) / moods.length;
      }

      final historySignal = (genreSignal * 0.6) + (artistSignal * 0.4);

      double fallbackBoost = 0;
      final fallbackRules = <String>[];
      if (!hasEnoughHistory) {
        fallbackBoost += 0.05;
        fallbackRules.add('Sparse history: boosted popularity weight');
      }
      if (!hasVoteSignal) {
        fallbackBoost += 0.05;
        fallbackRules.add('No vote signal: applied neutral vote fallback');
      }
      if (moods.isEmpty) {
        fallbackBoost += 0.03;
        fallbackRules.add('No mood tags on song: applied neutral mood fallback');
      }

      final weightedScore =
          (voteSignal * voteWeight) + (historySignal * historyWeight) + (moodSignal * moodWeight) + fallbackBoost;

      final scoreOutOf100 = (weightedScore * 100).clamp(0, 100).toDouble();
      final scoreBreakdown = {
        'weights': {
          'vote': voteWeight,
          'history': historyWeight,
          'mood': moodWeight,
        },
        'signals': {
          'vote': voteSignal,
          'history': historySignal,
          'mood': moodSignal,
          'genreMatch': genreSignal,
          'artistMatch': artistSignal,
        },
        'components': {
          'voteContribution': voteSignal * voteWeight * 100,
          'historyContribution': historySignal * historyWeight * 100,
          'moodContribution': moodSignal * moodWeight * 100,
          'fallbackContribution': fallbackBoost * 100,
        },
        'fallbackRules': fallbackRules,
      };

      results.add({
        ...song,
        'id': doc.id,
        'candidateType': 'playlist_candidate',
        'title': title,
        'recommendationScore': scoreOutOf100,
        'scoreBreakdown': scoreBreakdown,
        'scoreSummary':
            'Votes ${(voteSignal * 100).round()}%, History ${(historySignal * 100).round()}%, Mood ${(moodSignal * 100).round()}%',
      });
    }

    results.sort((a, b) =>
        (b['recommendationScore'] as double).compareTo(a['recommendationScore'] as double));
    return results;
  }

  double _normalizedSignal(Map<String, int> frequency, String key) {
    if (key.isEmpty || frequency.isEmpty) {
      return 0;
    }
    final keyFrequency = frequency[key] ?? 0;
    if (keyFrequency == 0) {
      return 0;
    }
    final maxFrequency = frequency.values.fold<int>(1, (a, b) => b > a ? b : a);
    return (keyFrequency / maxFrequency).clamp(0, 1).toDouble();
  }
}