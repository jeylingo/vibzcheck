import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'room_service.dart';
import 'spotify_playback_service.dart';

class PlaybackService {
  PlaybackService._internal();
  static final PlaybackService _instance = PlaybackService._internal();
  factory PlaybackService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  final SpotifyPlaybackService _spotifyPlayback = SpotifyPlaybackService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _roomSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  String? _currentRoomId;
  String? _currentSongId;
  bool _isHost = false;
  bool _usingSpotifyRemote = false;
  bool _spotifyIsPlaying = false;

  bool get isPlaying => _usingSpotifyRemote ? _spotifyIsPlaying : _player.playing;

  Future<void> joinRoom(String roomId) async {
    _currentRoomId = roomId;

    await _roomSubscription?.cancel();
    _roomSubscription = _db.collection('rooms').doc(roomId).snapshots().listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final currentUser = _auth.currentUser;
      final newIsHost = currentUser != null && data['ownerId'] == currentUser.uid;
      
      if (newIsHost != _isHost) {
        _isHost = newIsHost;
        if (_isHost) {
          _setupHostSync();
        }
      }

      _handleRoomState(data);
    });
  }

  void _setupHostSync() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();

    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (_currentRoomId != null && _currentSongId != null) {
        _syncStateToFirestore();
      }

      if (state.processingState == ProcessingState.completed) {
        _handleSongCompleted();
      }
    });

    _positionSubscription = _player.positionStream.listen((pos) {
      // Sync every 5 seconds to avoid spamming Firestore, or when state changes
      if (pos.inSeconds % 5 == 0 && _currentRoomId != null && _player.playing) {
        _syncStateToFirestore();
      }
    });
  }

  Future<void> _handleSongCompleted() async {
    if (_isHost && _currentRoomId != null) {
      final roomService = RoomService();
      try {
        await roomService.skipToNext(roomId: _currentRoomId!);
      } catch (_) {}
    }
  }

  Future<void> _syncStateToFirestore() async {
    if (_currentRoomId == null || !_isHost) return;

    try {
      var isPlaying = _player.playing;
      var positionMs = _player.position.inMilliseconds;
      var durationMs = _player.duration?.inMilliseconds ?? 0;

      if (_usingSpotifyRemote) {
        final spotifyState = await _spotifyPlayback.getPlayerState();
        if (spotifyState != null) {
          isPlaying = !spotifyState.isPaused;
          positionMs = spotifyState.playbackPosition;
          durationMs = spotifyState.track?.duration ?? 0;
          _spotifyIsPlaying = isPlaying;
        }
      }

      await _db.collection('rooms').doc(_currentRoomId).update({
        'playbackState': {
          'isPlaying': isPlaying,
          'positionMs': positionMs,
          'durationMs': durationMs,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      });
    } catch (_) {
      // Ignore sync errors
    }
  }

  Future<void> _handleRoomState(Map<String, dynamic> roomData) async {
    final nowPlaying = roomData['nowPlaying'] as Map<String, dynamic>?;
    final playbackState = roomData['playbackState'] as Map<String, dynamic>?;

    if (nowPlaying == null) {
      _currentSongId = null;
      _usingSpotifyRemote = false;
      await _player.stop();
      return;
    }

    final newSongId = nowPlaying['songId'] as String?;
    if (newSongId != _currentSongId) {
      _currentSongId = newSongId;
      await _loadAndPlaySong(nowPlaying);
    } else if (!_isHost && playbackState != null) {
      final metadata = nowPlaying['metadata'] as Map<String, dynamic>?;
      final spotifyUri = (metadata?['spotifyUri'] ?? '').toString();

      if (_usingSpotifyRemote && spotifyUri.isNotEmpty) {
        final hostIsPlaying = playbackState['isPlaying'] == true;
        final hostPosMs = playbackState['positionMs'] as int? ?? 0;
        final updatedAt = playbackState['updatedAt'] as Timestamp?;

        if (hostIsPlaying) {
          await _spotifyPlayback.resume();
          _spotifyIsPlaying = true;
        } else {
          await _spotifyPlayback.pause();
          _spotifyIsPlaying = false;
        }

        if (updatedAt != null && hostIsPlaying) {
          final elapsedSinceUpdate = DateTime.now().difference(updatedAt.toDate()).inMilliseconds;
          final estimatedHostPos = hostPosMs + elapsedSinceUpdate;

          final spotifyState = await _spotifyPlayback.getPlayerState();
          final localPos = spotifyState?.playbackPosition ?? 0;
          final diff = (localPos - estimatedHostPos).abs();
          if (diff > 3000) {
            await _spotifyPlayback.seekTo(estimatedHostPos);
          }
        }
        return;
      }

      // Sync listener to host's playback state
      final hostIsPlaying = playbackState['isPlaying'] == true;
      final hostPosMs = playbackState['positionMs'] as int? ?? 0;
      final updatedAt = playbackState['updatedAt'] as Timestamp?;
      
      if (hostIsPlaying != _player.playing) {
        if (hostIsPlaying) {
          _player.play();
        } else {
          _player.pause();
        }
      }

      if (updatedAt != null && hostIsPlaying) {
        final elapsedSinceUpdate = DateTime.now().difference(updatedAt.toDate()).inMilliseconds;
        final estimatedHostPos = hostPosMs + elapsedSinceUpdate;
        
        final diff = (_player.position.inMilliseconds - estimatedHostPos).abs();
        // If listener is out of sync by more than 3 seconds, seek to catch up
        if (diff > 3000) {
          await _player.seek(Duration(milliseconds: estimatedHostPos));
        }
      }
    }
  }

  Future<void> _loadAndPlaySong(Map<String, dynamic> nowPlaying) async {
    final metadata = nowPlaying['metadata'] as Map<String, dynamic>?;
    if (metadata == null) return;

    final spotifyUri = (metadata['spotifyUri'] ?? '').toString();
    if (spotifyUri.isNotEmpty) {
      final playedInSpotify = await _spotifyPlayback.playUri(spotifyUri);
      if (playedInSpotify) {
        _usingSpotifyRemote = true;
        _spotifyIsPlaying = true;
        await _player.stop();
        if (_isHost) {
          await _syncStateToFirestore();
        }
        return;
      }
    }

    _usingSpotifyRemote = false;
    _spotifyIsPlaying = false;

    final previewUrl = metadata['previewUrl'] as String?;
    if (previewUrl == null || previewUrl.isEmpty) return;

    try {
      final cachedFile = await _cachePreview(previewUrl, _currentSongId!);
      if (cachedFile != null && await cachedFile.exists()) {
        await _player.setFilePath(cachedFile.path);
      } else {
        // Fallback to network
        await _player.setUrl(previewUrl);
      }
      
      await _player.play();
    } catch (e) {
      // Playback error
    }
  }

  Future<File?> _cachePreview(String url, String songId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/preview_$songId.mp3');

      if (await file.exists()) {
        return file;
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      // Ignore caching errors
    }
    return null;
  }

  Future<void> togglePlayPause() async {
    if (!_isHost) return; // Only host controls playback directly

    if (_usingSpotifyRemote) {
      final state = await _spotifyPlayback.getPlayerState();
      if (state == null || state.isPaused) {
        await _spotifyPlayback.resume();
        _spotifyIsPlaying = true;
      } else {
        await _spotifyPlayback.pause();
        _spotifyIsPlaying = false;
      }
    } else {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    }
    await _syncStateToFirestore();
  }

  Future<void> leaveRoom() async {
    _currentRoomId = null;
    _currentSongId = null;
    _isHost = false;
    _usingSpotifyRemote = false;
    _spotifyIsPlaying = false;
    await _roomSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _player.stop();
    await _spotifyPlayback.disconnect();
  }
}
