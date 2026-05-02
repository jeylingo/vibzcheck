import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/room_service.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String code;

  const RoomScreen({super.key, required this.roomId, required this.code});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final RoomService service = RoomService();
  bool addingSong = false;
  String error = '';

  Future<void> _showAddSongDialog() async {
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    final genreController = TextEditingController();
    final moodsController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Song'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: artistController, decoration: const InputDecoration(labelText: 'Artist')),
                TextField(controller: genreController, decoration: const InputDecoration(labelText: 'Genre')),
                TextField(controller: moodsController, decoration: const InputDecoration(labelText: 'Moods (comma separated)')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final artist = artistController.text.trim();
                final genre = genreController.text.trim();
                final moods = moodsController.text
                    .split(',')
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toList();

                if (title.isEmpty || artist.isEmpty || genre.isEmpty) {
                  if (mounted) {
                    setState(() {
                      error = 'Title, artist, and genre are required.';
                    });
                  }
                  return;
                }

                Navigator.pop(dialogContext);
                setState(() {
                  addingSong = true;
                  error = '';
                });

                try {
                  await service.addSongToQueue(
                    roomId: widget.roomId,
                    title: title,
                    artist: artist,
                    genre: genre,
                    moods: moods,
                  );
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      error = e.toString();
                    });
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      addingSong = false;
                    });
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _vote(String songId, int value) async {
    setState(() {
      error = '';
    });

    try {
      await service.voteOnSong(roomId: widget.roomId, songId: songId, voteValue: value);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueStream = service.watchRoomQueue(widget.roomId);
    final membersStream = service.watchRoomMembers(widget.roomId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Room • ${widget.code}'),
        actions: [
          IconButton(
            onPressed: addingSong ? null : _showAddSongDialog,
            icon: const Icon(Icons.queue_music),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room ID: ${widget.roomId}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              ),
            const Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 84,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: membersStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text('No members yet'));
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      return Chip(label: Text(data['displayName'] ?? data['uid'] ?? 'Member'));
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Queue', style: TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: addingSong ? null : _showAddSongDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Song'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: queueStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text('Queue is empty'));
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final title = data['title'] ?? '';
                      final artist = data['artist'] ?? '';
                      final score = data['voteScore'] ?? 0;
                      final genre = data['genre'] ?? '';

                      return Card(
                        child: ListTile(
                          title: Text(title),
                          subtitle: Text('$artist • $genre'),
                          leading: CircleAvatar(child: Text('$score')),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                onPressed: () => _vote(doc.id, 1),
                                icon: const Icon(Icons.thumb_up),
                              ),
                              IconButton(
                                onPressed: () => _vote(doc.id, -1),
                                icon: const Icon(Icons.thumb_down),
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
      ),
    );
  }
}
