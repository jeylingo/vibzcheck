import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> sendMessage(String playlistId, String text) async {
    final user = auth.currentUser!;

    await db.collection('playlists').doc(playlistId).collection('messages').add({
      'text': text,
      'senderId': user.uid,
      'senderEmail': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getMessages(String playlistId) {
    return db
        .collection('playlists')
        .doc(playlistId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}