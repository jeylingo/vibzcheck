import 'dart:io';

import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

class SpotifyPlaybackService {
  SpotifyPlaybackService._internal();
  static final SpotifyPlaybackService _instance = SpotifyPlaybackService._internal();
  factory SpotifyPlaybackService() => _instance;

  static const String _clientId = String.fromEnvironment(
    'SPOTIFY_CLIENT_ID',
    defaultValue: 'f5928f1551e54156a1cdf3d463885a04',
  );
  static const String _redirectUri = String.fromEnvironment(
    'SPOTIFY_REDIRECT_URI',
    defaultValue: 'vibzcheck://auth',
  );
  static const String _scope =
      'app-remote-control,user-read-playback-state,user-modify-playback-state,user-read-currently-playing';

  bool _connected = false;
  bool _authorizationFailed = false;

  bool get isConfigured => _clientId.isNotEmpty;
  bool get isConnected => _connected;
  bool get canAttemptConnection => isConfigured && !_authorizationFailed;

  Future<bool> ensureConnected() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return false;
    if (!canAttemptConnection) return false;
    if (_connected) return true;

    try {
      final connected = await SpotifySdk.connectToSpotifyRemote(
        clientId: _clientId,
        redirectUrl: _redirectUri,
        scope: _scope,
      );
      _connected = connected;
      print('Spotify connected: $connected');
      return connected;
    } catch (error) {
      _connected = false;
      final errorText = error.toString();
      print('Spotify connection error: $errorText');
      if (errorText.contains('UserNotAuthorizedException') ||
          errorText.contains('did not authorize') ||
          errorText.contains('Explicit user authorization is required')) {
        _authorizationFailed = true;
      }
      return false;
    }
  }

  Future<bool> playUri(String spotifyUri) async {
    print('Attempting to play URI: $spotifyUri');
    if (spotifyUri.isEmpty) return false;
    final connected = await ensureConnected();
    if (!connected) {
        print('Cannot play: Spotify is not connected.');
        return false;
    }

    try {
      await SpotifySdk.play(spotifyUri: spotifyUri);
      print('Successfully started playing $spotifyUri');
      return true;
    } catch (error) {
      print('Error playing Spotify URI: $error');
      return false;
    }
  }

  Future<void> pause() async {
    if (!await ensureConnected()) return;
    try {
      await SpotifySdk.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (!await ensureConnected()) return;
    try {
      await SpotifySdk.resume();
    } catch (_) {}
  }

  Future<void> seekTo(int milliseconds) async {
    if (!await ensureConnected()) return;
    try {
      await SpotifySdk.seekTo(positionedMilliseconds: milliseconds);
    } catch (_) {}
  }

  Future<PlayerState?> getPlayerState() async {
    if (!await ensureConnected()) return null;
    try {
      return await SpotifySdk.getPlayerState();
    } catch (_) {
      return null;
    }
  }

  Future<void> disconnect() async {
    if (!_connected) return;
    try {
      await SpotifySdk.disconnect();
    } catch (_) {
      // Best-effort disconnect.
    } finally {
      _connected = false;
    }
  }
}
