import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomScreen extends StatelessWidget {
  final String roomId;
  final String code;

  const RoomScreen({super.key, required this.roomId, required this.code});

  @override
  Widget build(BuildContext context) {
    final membersStream = FirebaseFirestore.instance.collection('rooms').doc(roomId).collection('members').snapshots();

    return Scaffold(
      appBar: AppBar(title: Text('Room • $code')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room ID: $roomId', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            const Text('Members:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: membersStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Text('No members yet');
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['displayName'] ?? data['uid'] ?? ''),
                        subtitle: Text(data['role'] ?? 'member'),
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
