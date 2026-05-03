import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/playlist_service.dart';
import '../../services/history_service.dart';
import '../chat/chat_screen.dart';

import '../../services/music_metadata_service.dart';

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
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _error = '';

  Future<void> _searchAndAdd(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() {
      _isSearching = true;
      _error = '';
    });
    try {
      final res = await MusicMetadataService().searchSpotifyTracks(query);
      if (mounted) setState(() => _searchResults = res);
    } catch (e) {
      if (mounted) setState(() => _error = 'Search failed');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _addTrack(Map<String, dynamic> track) async {
    final genres = (track['genres'] as List?)?.cast<String>() ?? [];
    final genre = genres.isNotEmpty ? genres.first : 'pop';
    final moods = (track['moods'] as List?)?.cast<String>() ?? [];

    await PlaylistService().addSong(
      widget.playlistId,
      track['title'] ?? 'Unknown',
      track['artist'] ?? 'Unknown',
      genre,
      moods,
    );

    setState(() {
      _searchResults = [];
      titleController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = PlaylistService();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Playlist?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await service.deletePlaylist(widget.playlistId);
                if (mounted) Navigator.pop(context);
              }
            },
          ),
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      hintText: 'Search for a song...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (query) => _searchAndAdd(query),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isSearching)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: () => _searchAndAdd(titleController.text),
                    child: const Text('Search'),
                  ),
              ],
            ),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(_error, style: const TextStyle(color: Colors.red)),
            ),
          if (_searchResults.isNotEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final track = _searchResults[index];
                  return ListTile(
                    leading: track['albumArtUrl'] != null
                        ? Image.network(track['albumArtUrl'], width: 40, height: 40, fit: BoxFit.cover)
                        : const Icon(Icons.music_note),
                    title: Text(track['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(track['artist'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _addTrack(track),
                  );
                },
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