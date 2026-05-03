import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  /// Send a message to a room
  Future<String> sendMessage({
    required String roomId,
    required String content,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Verify user is a member
    final memberDoc = await db.collection('rooms').doc(roomId).collection('members').doc(user.uid).get();
    if (!memberDoc.exists) {
      throw Exception('You are not a member of this room');
    }

    final displayName = memberDoc.data()?['displayName'] ?? user.email ?? 'User';

    final messageRef = db.collection('rooms').doc(roomId).collection('messages').doc();
    await messageRef.set({
      'userId': user.uid,
      'displayName': displayName,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return messageRef.id;
  }

  /// Send a message to a playlist (legacy support)
  Future<void> sendPlaylistMessage(String playlistId, String text) async {
    final user = auth.currentUser!;

    await db.collection('playlists').doc(playlistId).collection('messages').add({
      'text': text,
      'senderId': user.uid,
      'senderEmail': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Watch all messages in a room (ordered by timestamp, newest last)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String roomId) {
    return db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Get playlist messages (legacy support)
  Stream<QuerySnapshot> getMessages(String playlistId) {
    return db
        .collection('playlists')
        .doc(playlistId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Add a reaction to a message
  Future<void> addReaction({
    required String roomId,
    required String messageId,
    required String emoji,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .doc(user.uid)
        .set({
      'emoji': emoji,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a reaction from a message
  Future<void> removeReaction({
    required String roomId,
    required String messageId,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .doc(user.uid)
        .delete();
  }

  /// Get all reactions for a message
  Future<Map<String, int>> getReactions({
    required String roomId,
    required String messageId,
  }) async {
    final snapshot = await db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .get();

    final reactions = <String, int>{};
    for (final doc in snapshot.docs) {
      final emoji = doc.data()['emoji'] as String?;
      if (emoji != null) {
        reactions[emoji] = (reactions[emoji] ?? 0) + 1;
      }
    }
    return reactions;
  }

  /// Set typing status for current user
  Future<void> setTyping(String roomId) async {
    final user = auth.currentUser;
    if (user == null) return;

    final memberDoc = await db.collection('rooms').doc(roomId).collection('members').doc(user.uid).get();
    final displayName = memberDoc.data()?['displayName'] ?? user.email ?? 'User';

    await db
        .collection('rooms')
        .doc(roomId)
        .collection('typingStatus')
        .doc(user.uid)
        .set({
      'displayName': displayName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Clear typing status for current user
  Future<void> clearTyping(String roomId) async {
    final user = auth.currentUser;
    if (user == null) return;

    await db
        .collection('rooms')
        .doc(roomId)
        .collection('typingStatus')
        .doc(user.uid)
        .delete();
  }

  /// Watch typing status (filters out old entries > 3 seconds)
  Stream<List<Map<String, dynamic>>> watchTypingStatus(String roomId) {
    return db
        .collection('rooms')
        .doc(roomId)
        .collection('typingStatus')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final filtered = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final timestamp = (doc.data()['timestamp'] as Timestamp?)?.toDate();
        if (timestamp != null && now.difference(timestamp).inSeconds < 3) {
          filtered.add({
            'userId': doc.id,
            'displayName': doc.data()['displayName'] ?? 'User',
          });
        }
      }

      return filtered;
    });
  }
}