import 'package:flutter/material.dart';
import '../../services/playlist_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreatePlaylistScreen extends StatefulWidget {
  const CreatePlaylistScreen({super.key});

  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  final titleController = TextEditingController();
  String mood = 'chill';

  bool loading = false;
  String error = '';

  Future<void> create() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      await PlaylistService().createPlaylist(
        titleController.text.trim(),
        mood,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        error = 'Create failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
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
            const SizedBox(height: 12),
            if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: loading ? null : create,
              child: loading ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}