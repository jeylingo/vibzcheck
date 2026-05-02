import 'package:flutter/material.dart';
import '../../services/playlist_service.dart';

class CreatePlaylistScreen extends StatefulWidget {
  const CreatePlaylistScreen({super.key});

  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  final titleController = TextEditingController();
  String mood = 'chill';

  Future<void> create() async {
    await PlaylistService().createPlaylist(
      titleController.text.trim(),
      mood,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final moods = ['chill', 'hype', 'party', 'sad', 'study'];

    return Scaffold(
      appBar: AppBar(title: const Text('Create Playlist')),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Playlist title'),
            ),
            DropdownButton<String>(
              value: mood,
              items: moods.map((m) {
                return DropdownMenuItem(value: m, child: Text(m));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  mood = value!;
                });
              },
            ),
            ElevatedButton(
              onPressed: create,
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}