import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../playlists/playlist_list_screen.dart';
import '../recommendations/recommendation_screen.dart';
import '../rooms/room_hub_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> logout(BuildContext context) async {
    await AuthService().logout();

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final profileStream = user == null ? null : AuthService().watchProfile(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibzcheck'),
        actions: [
          IconButton(
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Logged in as: ${user?.email ?? ''}'),
            const SizedBox(height: 16),
            if (profileStream != null)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: profileStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final profileDoc = snapshot.data;
                  final profile = profileDoc?.data() ?? <String, dynamic>{};
                  final name = (profile['name'] ?? '').toString();
                  final photoUrl = (profile['photoUrl'] ?? '').toString();
                  final preferredGenres = List<String>.from(profile['preferredGenres'] ?? const <String>[]);
                  final activity = profile['listeningActivity'] as Map<String, dynamic>? ?? <String, dynamic>{};
                  final totalPlays = (activity['totalPlays'] ?? 0) as int;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name.isNotEmpty ? name : (user?.email ?? ''),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('Preferred genres: ${preferredGenres.isEmpty ? 'None set' : preferredGenres.join(', ')}'),
                          const SizedBox(height: 4),
                          Text('Listening activity: $totalPlays plays logged'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RoomHubScreen()),
                );
              },
              child: const Text('Open Rooms'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlaylistListScreen(),
                  ),
                );
              },
              child: const Text('Open Playlists'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecommendationScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Open Recommendations'),
            ),
          ],
        ),
      ),
    );
  }
}
