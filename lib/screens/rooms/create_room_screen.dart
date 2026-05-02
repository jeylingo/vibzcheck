import 'package:flutter/material.dart';
import '../../services/room_service.dart';
import 'room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final titleController = TextEditingController();
  bool isPrivate = false;
  bool loading = false;
  String error = '';

  Future<void> create() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        error = 'Please enter a room title.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      final res = await RoomService().createRoom(title, isPrivate: isPrivate);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RoomScreen(roomId: res['roomId']!, code: res['code']!)),
      );
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Room')),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Room title')),
            Row(
              children: [
                const Text('Private'),
                Switch(value: isPrivate, onChanged: (v) => setState(() => isPrivate = v)),
              ],
            ),
            if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: loading ? null : create, child: loading ? const CircularProgressIndicator() : const Text('Create')),
          ],
        ),
      ),
    );
  }
}
