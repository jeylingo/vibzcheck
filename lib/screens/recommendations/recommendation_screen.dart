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

  Future<void> load() async {
    final results = await RecommendationService().getRecommendations();

    setState(() {
      songs = results;
      loading = false;
    });
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
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];

                return Card(
                  child: ListTile(
                    title: Text('${index + 1}. ${song['title'] ?? ''}'),
                    subtitle: Text(
                      '${song['artist'] ?? ''}\n'
                      'Score: ${song['recommendationScore']}\n'
                      '${song['reason']}',
                    ),
                  ),
                );
              },
            ),
    );
  }
}