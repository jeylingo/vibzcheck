import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/playlist_service.dart';
import '../../services/history_service.dart';
import '../chat/chat_screen.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final String title;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.title,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final titleController = TextEditingController();
  final artistController = TextEditingController();
  final genreController = TextEditingController();
  final moodsController = TextEditingController();

  Future<void> addSong() async {
    final moods = moodsController.text
        .split(',')
        .map((m) => m.trim().toLowerCase())
        .where((m) => m.isNotEmpty)
        .toList();

    await PlaylistService().addSong(
      widget.playlistId,
      titleController.text.trim(),
      artistController.text.trim(),
      genreController.text.trim(),
      moods,
    );

    titleController.clear();
    artistController.clear();
    genreController.clear();
    moodsController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final service = PlaylistService();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(playlistId: widget.playlistId),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Song title'),
                ),
                TextField(
                  controller: artistController,
                  decoration: const InputDecoration(labelText: 'Artist'),
                ),
                TextField(
                  controller: genreController,
                  decoration: const InputDecoration(labelText: 'Genre'),
                ),
                TextField(
                  controller: moodsController,
                  decoration: const InputDecoration(labelText: 'Moods: hype, chill'),
                ),
                ElevatedButton(
                  onPressed: addSong,
                  child: const Text('Add Song'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: service.getSongs(widget.playlistId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final songs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final doc = songs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final moods = List<String>.from(data['moods'] ?? []);

                    return Card(
                      child: ListTile(
                        title: Text(data['title'] ?? ''),
                        subtitle: Text(
                          '${data['artist'] ?? ''} | ${data['genre'] ?? ''} | Votes: ${data['voteScore']}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () {
                                HistoryService().addHistory(
                                  data['title'] ?? '',
                                  data['artist'] ?? '',
                                  data['genre'] ?? '',
                                  moods,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.thumb_up),
                              onPressed: () {
                                service.voteSong(widget.playlistId, doc.id, 1);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.thumb_down),
                              onPressed: () {
                                service.voteSong(widget.playlistId, doc.id, -1);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}