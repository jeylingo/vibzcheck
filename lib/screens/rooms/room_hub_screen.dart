import 'package:flutter/material.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';

class RoomHubScreen extends StatelessWidget {
  const RoomHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
                );
              },
              child: const Text('Create Room'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
                );
              },
              child: const Text('Join Room by Code'),
            ),
          ],
        ),
      ),
    );
  }
}
