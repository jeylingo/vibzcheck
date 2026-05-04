# Vibzcheck: Project Overview & Scope

## 1. Problem Statement
Listening to music in group settings—whether at a party, studying remotely with friends, or on a road trip—often results in the "aux cord monopoly," where one person controls the playlist. This leaves others out of the loop, leading to conflicting music tastes and friction. Traditional music streaming platforms lack real-time, democratic queue management and synchronous listening experiences. There is a clear need for a collaborative platform where everyone has an equal say in what plays next.

## 2. Project Objectives
**Vibzcheck** was designed to democratize music listening by creating a shared, synchronous audio experience. The core objectives include:
- **Real-Time Collaboration:** Allow users to create virtual "Rooms" where multiple people can join and add songs to a shared queue.
- **Democratic Playback:** Implement a live voting system (upvote/downvote) that dynamically reorders the queue based on popular consensus.
- **Synchronized Audio:** Ensure that the music plays at the exact same time across all connected devices in the room.
- **Smart Recommendations:** Provide an intelligent recommendation engine that analyzes listening history, mood tags, and voting behavior to suggest the perfect next track.
- **Social Engagement:** Include real-time text chat with typing indicators so users can communicate while listening.

## 3. Design & Architecture
The application is built using a modern mobile tech stack focused on real-time capabilities and a premium user experience:
- **Frontend:** Flutter (Dart) for a high-performance, cross-platform mobile application.
- **Backend/Database:** Firebase Firestore for real-time NoSQL data synchronization (Rooms, Chat, Queue).
- **Authentication:** Firebase Authentication for secure user sign-in and profile management.
- **API Integration:** iTunes Search API for retrieving rich track metadata, album art, and 30-second audio previews without the strict limitations of the Spotify API.
- **UI/UX Aesthetics:** A custom Neon Cyberpunk Dark Theme featuring deep purples, vibrant magentas, glassmorphism cards, and glowing drop-shadows to emulate a premium nightlife/party vibe.

## 4. Testing Strategy
Vibzcheck was thoroughly tested using an end-to-end user journey approach on an Android Emulator:
- **Functional Testing:** Verified room creation, joining via codes, and live chat messaging.
- **Integration Testing:** Ensured the iTunes API correctly populates metadata and album art within the app.
- **Concurrency Testing:** Validated that the Firestore voting transaction system correctly handles multiple simultaneous upvotes/downvotes without data loss or race conditions.
- **Playback Synchronization Testing:** Verified that the Host's playback controls (play/pause/skip) correctly trigger state changes on all listener devices with a maximum drift threshold of 3 seconds.

## 5. Team Roles
- **Prosper (jeylingo) - Lead Developer & Product Owner:** Responsible for the core vision, testing, deploying, and ensuring the application meets the final project requirements.
- **Antigravity (AI Pair Programmer):** Assisted with infrastructure architecture, security rule optimization, API integration, and implementing the custom UI theme.

---

## 6. Code Evidence & Firebase Integration

### Firestore Real-Time Synchronization (Rooms & Queues)
The app relies heavily on Firestore's real-time listeners. When a user joins a room, a `StreamBuilder` immediately syncs the queue state.
```dart
// lib/screens/rooms/room_screen.dart
StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
  stream: queueStream,
  builder: (context, snapshot) {
    final docs = snapshot.data!.docs.toList();
    // Dynamic Sorting based on Vote Score
    docs.sort((a, b) {
      final scoreA = a.data()['voteScore'] ?? 0;
      final scoreB = b.data()['voteScore'] ?? 0;
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      return (a.data()['position'] ?? 0).compareTo((b.data()['position'] ?? 0));
    });
    // ... Returns ListView of SongCards
  }
)
```

### Atomic Transactions (Voting System)
To prevent race conditions when multiple users vote at once, Vibzcheck uses Firestore `runTransaction`.
```dart
// lib/services/room_service.dart
Future<void> voteSong(String roomId, String songId, int voteValue) async {
  final user = auth.currentUser!;
  final songRef = db.collection('rooms').doc(roomId).collection('queue').doc(songId);
  final voteRef = songRef.collection('votes').doc(user.uid);

  await db.runTransaction((transaction) async {
    final songSnap = await transaction.get(songRef);
    final voteSnap = await transaction.get(voteRef);

    int currentScore = songSnap['voteScore'] ?? 0;
    if (voteSnap.exists) {
      currentScore -= (voteSnap['voteValue'] as int); // Remove old vote
    }
    
    currentScore += voteValue; // Add new vote

    transaction.set(voteRef, {'userId': user.uid, 'voteValue': voteValue});
    transaction.update(songRef, {'voteScore': currentScore});
  });
}
```

### Synchronous Audio Playback
Using `just_audio`, the `PlaybackService` ensures the host's exact audio position is mirrored to all listeners in the room.
```dart
// lib/services/playback_service.dart
Future<void> _handleRoomState(Map<String, dynamic> roomData) async {
  final playbackState = roomData['playbackState'];
  if (!_isHost && playbackState != null) {
    final hostIsPlaying = playbackState['isPlaying'] == true;
    final hostPosMs = playbackState['positionMs'] ?? 0;
    
    // Auto-seek if listener falls more than 3 seconds behind the host
    final diff = (_player.position.inMilliseconds - hostPosMs).abs();
    if (diff > 3000) {
      await _player.seek(Duration(milliseconds: hostPosMs));
    }
  }
}
```

### Cost-Efficient Storage (Base64 Bypass)
Instead of relying on paid Firebase Storage buckets for small images, Vibzcheck compresses and encodes room covers directly into Firestore documents.
```dart
// lib/services/storage_service.dart
Future<String?> uploadProfilePicture(String userId, File imageFile) async {
  final bytes = await imageFile.readAsBytes();
  // Decode, resize to 400x400 max, and aggressively compress to JPEG
  img.Image? image = img.decodeImage(bytes);
  img.Image resized = img.copyResize(image!, width: 400);
  final compressed = img.encodeJpg(resized, quality: 60);
  
  // Save directly as a Base64 string to Firestore
  final base64String = base64Encode(compressed);
  return 'data:image/jpeg;base64,$base64String';
}
```
