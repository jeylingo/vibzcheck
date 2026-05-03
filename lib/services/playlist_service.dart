import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlaylistService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> createPlaylist(String title, String mood) async {
    final user = auth.currentUser!;

    await db.collection('playlists').add({
      'title': title,
      'mood': mood,
      'ownerId': user.uid,
      'members': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getPlaylists() {
    final user = auth.currentUser;
    if (user == null) return const Stream.empty();
    return db.collection('playlists')
        .where('members', arrayContains: user.uid)
        .snapshots();
  }

  Future<void> addSong(
    String playlistId,
    String title,
    String artist,
    String genre,
    List<String> moods,
  ) async {
    final user = auth.currentUser!;

    await db.collection('playlists').doc(playlistId).collection('songs').add({
      'title': title,
      'artist': artist,
      'genre': genre.toLowerCase(),
      'moods': moods,
      'addedBy': user.uid,
      'voteScore': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getSongs(String playlistId) {
    return db
        .collection('playlists')
        .doc(playlistId)
        .collection('songs')
        .orderBy('voteScore', descending: true)
        .snapshots();
  }

  Future<void> voteSong(String playlistId, String songId, int voteValue) async {
    final user = auth.currentUser!;

    final songRef = db.collection('playlists').doc(playlistId).collection('songs').doc(songId);

    final voteRef = songRef.collection('votes').doc(user.uid);

    await db.runTransaction((transaction) async {
      final songSnap = await transaction.get(songRef);
      final voteSnap = await transaction.get(voteRef);

      int currentScore = songSnap['voteScore'] ?? 0;

      if (voteSnap.exists) {
        int oldVote = voteSnap['voteValue'];
        currentScore -= oldVote;
      }

      currentScore += voteValue;

      transaction.set(voteRef, {
        'userId': user.uid,
        'voteValue': voteValue,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(songRef, {
        'voteScore': currentScore,
      });
    });
  }
}