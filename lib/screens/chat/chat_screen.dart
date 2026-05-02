import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String playlistId;

  const ChatScreen({
    super.key,
    required this.playlistId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageController = TextEditingController();

  Future<void> send() async {
    await ChatService().sendMessage(
      widget.playlistId,
      messageController.text.trim(),
    );

    messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final service = ChatService();

    return Scaffold(
      appBar: AppBar(title: const Text('Playlist Chat')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: service.getMessages(widget.playlistId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;

                    return ListTile(
                      title: Text(data['text'] ?? ''),
                      subtitle: Text(data['senderEmail'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
              ),
              IconButton(
                onPressed: send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}