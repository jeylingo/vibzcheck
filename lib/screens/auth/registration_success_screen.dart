import 'package:flutter/material.dart';
import '../playlists/playlist_list_screen.dart';

class RegistrationSuccessScreen extends StatefulWidget {
  const RegistrationSuccessScreen({super.key});

  @override
  State<RegistrationSuccessScreen> createState() => _RegistrationSuccessScreenState();
}

class _RegistrationSuccessScreenState extends State<RegistrationSuccessScreen> {
  late int secondsRemaining;

  @override
  void initState() {
    super.initState();
    secondsRemaining = 3;
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          secondsRemaining--;
        });
        if (secondsRemaining > 0) {
          _startCountdown();
        } else {
          _navigateToPlaylist();
        }
      }
    });
  }

  void _navigateToPlaylist() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PlaylistListScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Registration Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Welcome to Vibzcheck',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            Text(
              'Navigating in $secondsRemaining...',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _navigateToPlaylist,
              child: const Text('Go to Playlists Now'),
            ),
          ],
        ),
      ),
    );
  }
}
