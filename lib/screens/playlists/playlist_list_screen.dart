import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/playlist_service.dart';
import 'create_playlist_screen.dart';
import 'playlist_detail_screen.dart';

class PlaylistListScreen extends StatelessWidget {
  const PlaylistListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PlaylistService();

    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePlaylistScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getPlaylists(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final playlists = snapshot.data!.docs;

          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final doc = playlists[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  title: Text(data['title'] ?? ''),
                  subtitle: Text('Mood: ${data['mood'] ?? ''}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(
                          playlistId: doc.id,
                          title: data['title'] ?? '',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}