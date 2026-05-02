import 'package:flutter/material.dart';
import '../../services/room_service.dart';
import 'room_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final codeController = TextEditingController();
  bool loading = false;
  String error = '';

  Future<void> join() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final roomId = await RoomService().joinRoomByCode(codeController.text.trim().toUpperCase());
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RoomScreen(roomId: roomId, code: codeController.text.trim().toUpperCase())),
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
      appBar: AppBar(title: const Text('Join Room')),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Room code')),
            const SizedBox(height: 12),
            if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)),
            ElevatedButton(onPressed: loading ? null : join, child: loading ? const CircularProgressIndicator() : const Text('Join')),
          ],
        ),
      ),
    );
  }
}
