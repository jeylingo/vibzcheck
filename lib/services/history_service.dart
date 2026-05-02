import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> addHistory(String title, String artist, String genre, List<String> moods) async {
    final user = auth.currentUser!;

    await db.collection('listeningHistory').add({
      'userId': user.uid,
      'title': title,
      'artist': artist,
      'genre': genre.toLowerCase(),
      'moods': moods,
      'playedAt': FieldValue.serverTimestamp(),
    });
  }
}