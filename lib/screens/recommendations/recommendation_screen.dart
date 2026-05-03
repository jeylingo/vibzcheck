import 'package:flutter/material.dart';
import '../../services/recommendation_service.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  bool loading = true;
  List<Map<String, dynamic>> songs = [];
  String? error;

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final results = await RecommendationService().getRecommendations();
      if (!mounted) return;

      setState(() {
        songs = results;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        actions: [
          IconButton(
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : songs.isEmpty
                  ? const Center(
                      child: Text(
                        'No recommendation candidates yet.\nAdd songs and listening history first.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: songs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        final score = (song['recommendationScore'] as double?) ?? 0;
                        final breakdown =
                            (song['scoreBreakdown'] as Map<String, dynamic>?) ??
                                const <String, dynamic>{};
                        final components =
                            (breakdown['components'] as Map<String, dynamic>?) ??
                                const <String, dynamic>{};
                        final fallbackRules =
                            (breakdown['fallbackRules'] as List?)?.cast<String>() ??
                                const <String>[];

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${index + 1}. ${song['title'] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text('${song['artist'] ?? ''}'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade800,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Score ${score.toStringAsFixed(1)}',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        song['scoreSummary']?.toString() ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Breakdown',
                                  style: TextStyle(
                                    color: Colors.grey.shade300,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Vote: ${_num(components['voteContribution']).toStringAsFixed(1)}  |  '
                                  'History: ${_num(components['historyContribution']).toStringAsFixed(1)}  |  '
                                  'Mood: ${_num(components['moodContribution']).toStringAsFixed(1)}  |  '
                                  'Fallback: ${_num(components['fallbackContribution']).toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (fallbackRules.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: fallbackRules
                                        .map(
                                          (rule) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(999),
                                              color: Colors.orange.withValues(alpha: 0.2),
                                              border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
                                            ),
                                            child: Text(
                                              rule,
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }
}