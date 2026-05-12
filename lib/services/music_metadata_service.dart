import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

class MusicMetadataService {
  final db = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;

  // Spotify API credentials - replace with your own
  // Get from: https://developer.spotify.com/dashboard/applications
  static const String spotifyClientId = 'f5928f1551e54156a1cdf3d463885a04';
  static const String spotifyClientSecret = 'f4521e249f5446c9adf96520d137a6dc';

  String? _accessToken;
  DateTime? _tokenExpiry;

  /// Get valid Spotify access token
  Future<String?> _getSpotifyToken() async {
    // Return existing token if still valid
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    if (spotifyClientId == 'YOUR_SPOTIFY_CLIENT_ID') {
      // Demo mode: Spotify not configured
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'client_credentials',
          'client_id': spotifyClientId,
          'client_secret': spotifyClientSecret,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _accessToken = json['access_token'];
        _tokenExpiry = DateTime.now().add(Duration(seconds: json['expires_in'] - 60));
        return _accessToken;
      } else {
        print('Spotify token error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Spotify exception: $e');
    }
    return null;
  }

  /// Search for a track on Spotify and get metadata
  Future<Map<String, dynamic>?> searchTrackMetadata({
    required String title,
    required String artist,
  }) async {
    final spotifyMetadata = await _searchTrackMetadataOnSpotify(title: title, artist: artist);
    if (spotifyMetadata != null) {
      return spotifyMetadata;
    }

    return _searchTrackMetadataOnItunes(title: title, artist: artist);
  }

  Future<Map<String, dynamic>?> _searchTrackMetadataOnSpotify({
    required String title,
    required String artist,
  }) async {
    final token = await _getSpotifyToken();
    if (token == null) return null;

    try {
      final query = Uri.encodeComponent('$title $artist');
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/search?q=$query&type=track&limit=1&market=US'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final tracks = json['tracks']['items'] as List?;

        if (tracks != null && tracks.isNotEmpty) {
          final track = tracks.first;
          final albumArtUrl = (track['album']['images'] as List?)?.isNotEmpty == true
              ? track['album']['images'][0]['url']
              : null;

          final genres = <String>[...(track['album']['genres'] ?? []) as List]
              .cast<String>()
              .take(3)
              .toList();
          final popularity = (track['popularity'] as num?)?.toInt() ?? 50;

          return {
            'spotifyTrackId': track['id'],
            'spotifyUri': track['uri'],
            'spotifyUrl': track['external_urls']['spotify'],
            'previewUrl': track['preview_url'],
            'albumArtUrl': albumArtUrl,
            'albumName': track['album']['name'],
            'releaseDate': track['album']['release_date'],
            'genres': genres,
            'explicit': track['explicit'],
            'duration': track['duration_ms'],
            'popularity': popularity,
            'moods': _inferMoods(genres, popularity),
            'source': 'spotify',
          };
        }
      }
    } catch (e) {
      print('Spotify search error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _searchTrackMetadataOnItunes({
    required String title,
    required String artist,
  }) async {
    try {
      final query = Uri.encodeComponent('$title $artist');
      final response = await http.get(
        Uri.parse('https://itunes.apple.com/search?term=$query&entity=song&limit=1'),
      );

      if (response.statusCode != 200) {
        print('iTunes metadata fallback error: ${response.statusCode} - ${response.body}');
        return null;
      }

      final json = jsonDecode(response.body);
      final results = json['results'] as List?;
      if (results == null || results.isEmpty) {
        return null;
      }

      final track = results.first;
      final albumArtUrl = (track['artworkUrl100'] as String?)?.replaceAll('100x100bb', '600x600bb');
      final genres = [track['primaryGenreName'] ?? 'Pop'];

      return {
        'spotifyTrackId': track['trackId']?.toString() ?? '',
        'spotifyUri': null,
        'spotifyUrl': track['trackViewUrl'],
        'previewUrl': track['previewUrl'],
        'albumArtUrl': albumArtUrl ?? track['artworkUrl100'],
        'albumName': track['collectionName'],
        'releaseDate': track['releaseDate'],
        'genres': genres,
        'explicit': track['trackExplicitness'] == 'explicit',
        'duration': track['trackTimeMillis'],
        'popularity': 50,
        'moods': _inferMoods(genres.cast<String>(), 50),
        'source': 'itunes_fallback',
      };
    } catch (e) {
      print('iTunes metadata fallback exception: $e');
      return null;
    }
  }

  /// Search tracks with Spotify first, then fall back to iTunes when needed.
  Future<List<Map<String, dynamic>>> searchSpotifyTracks(String query) async {
    if (query.trim().isEmpty) return [];

    final spotifyResults = await _searchTracksOnSpotify(query);
    if (spotifyResults.isNotEmpty) {
      return spotifyResults;
    }

    return _searchTracksOnItunes(query);
  }

  Future<List<Map<String, dynamic>>> _searchTracksOnSpotify(String query) async {
    final token = await _getSpotifyToken();
    if (token == null) return [];

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/search?q=$encodedQuery&type=track&limit=10&market=US'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        print('Spotify search list error: ${response.statusCode} - ${response.body}');
        return [];
      }

      final json = jsonDecode(response.body);
      final tracks = (json['tracks']?['items'] as List?) ?? const [];

      return tracks.map((track) {
        final artists = (track['artists'] as List?) ?? const [];
        final artistNames = artists
            .map((a) => (a['name'] ?? '').toString())
            .where((name) => name.isNotEmpty)
            .toList();

        final albumImages = (track['album']?['images'] as List?) ?? const [];
        final albumArtUrl = albumImages.isNotEmpty ? albumImages.first['url'] as String? : null;

        final popularity = (track['popularity'] as num?)?.toInt() ?? 50;
        final genreSeed = <String>['pop'];

        return {
          'spotifyTrackId': (track['id'] ?? '').toString(),
          'spotifyUri': track['uri'],
          'title': track['name'] ?? 'Unknown',
          'artist': artistNames.isNotEmpty ? artistNames.join(', ') : 'Unknown',
          'spotifyUrl': track['external_urls']?['spotify'],
          'previewUrl': track['preview_url'],
          'albumArtUrl': albumArtUrl,
          'albumName': track['album']?['name'],
          'releaseDate': track['album']?['release_date'],
          'genres': genreSeed,
          'explicit': track['explicit'] == true,
          'duration': track['duration_ms'],
          'popularity': popularity,
          'moods': _inferMoods(genreSeed, popularity),
          'source': 'spotify',
        };
      }).toList();
    } catch (e) {
      print('Spotify list search exception: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchTracksOnItunes(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse('https://itunes.apple.com/search?term=$encodedQuery&entity=song&limit=15'),
      );

      if (response.statusCode != 200) {
        print('iTunes fallback error: ${response.statusCode} - ${response.body}');
        return [];
      }

      final json = jsonDecode(response.body);
      final results = json['results'] as List?;
      if (results == null) return [];

      return results.map((track) {
        final albumArtUrl = (track['artworkUrl100'] as String?)?.replaceAll('100x100bb', '600x600bb');
        final genres = [track['primaryGenreName'] ?? 'Pop'];

        return {
          'spotifyTrackId': track['trackId']?.toString() ?? '',
          'spotifyUri': null,
          'title': track['trackName'] ?? 'Unknown',
          'artist': track['artistName'] ?? 'Unknown',
          'spotifyUrl': track['trackViewUrl'],
          'previewUrl': track['previewUrl'],
          'albumArtUrl': albumArtUrl ?? track['artworkUrl100'],
          'albumName': track['collectionName'],
          'releaseDate': track['releaseDate'],
          'genres': genres,
          'explicit': track['trackExplicitness'] == 'explicit',
          'duration': track['trackTimeMillis'],
          'popularity': 50,
          'moods': _inferMoods(genres.cast<String>(), 50),
          'source': 'itunes_fallback',
        };
      }).toList();
    } catch (e) {
      print('iTunes fallback exception: $e');
      return [];
    }
  }

  /// Cache album art in Firebase Storage
  Future<String?> cacheAlbumArt({
    required String roomId,
    required String songId,
    required String albumArtUrl,
  }) async {
    if (albumArtUrl.isEmpty) return null;

    try {
      // Check if already cached
      final ref = storage.ref('albums/$roomId/$songId.jpg');
      try {
        await ref.getMetadata();
        return await ref.getDownloadURL();
      } catch (e) {
        // File doesn't exist yet, proceed with upload
      }

      // Download image and upload to Firebase Storage
      final imageResponse = await http.get(Uri.parse(albumArtUrl));
      if (imageResponse.statusCode == 200) {
        await ref.putData(imageResponse.bodyBytes);
        return await ref.getDownloadURL();
      }
    } catch (e) {
    }
    return null;
  }

  /// Store enriched song metadata in Firestore
  Future<void> enrichSongInFirestore({
    required String roomId,
    required String songId,
    required Map<String, dynamic> metadata,
    String? cachedAlbumArtUrl,
  }) async {
    try {
      await db
          .collection('rooms')
          .doc(roomId)
          .collection('queue')
          .doc(songId)
          .update({
        'metadata': {
          'spotifyTrackId': metadata['spotifyTrackId'],
          'spotifyUri': metadata['spotifyUri'],
          'spotifyUrl': metadata['spotifyUrl'],
          'previewUrl': metadata['previewUrl'],
          'albumName': metadata['albumName'],
          'releaseDate': metadata['releaseDate'],
          'genres': metadata['genres'],
          'moods': metadata['moods'],
          'explicit': metadata['explicit'],
          'duration': metadata['duration'],
          'popularity': metadata['popularity'],
          'source': metadata['source'],
          'albumArtUrl': cachedAlbumArtUrl ?? metadata['albumArtUrl'],
          'enrichedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
    }
  }

  /// Infer moods from genres and popularity
  List<String> _inferMoods(List<String> genres, int popularity) {
    final moods = <String>[];

    // Genre-based mood mapping
    final genreMoodMap = {
      'energy': ['edm', 'dance', 'electronic', 'rock', 'metal', 'punk'],
      'relaxed': ['ambient', 'chillhop', 'lo-fi', 'reggae', 'chill'],
      'melancholic': ['sad', 'blues', 'slow', 'ballad', 'emotional'],
      'joyful': ['pop', 'dance', 'funk', 'disco', 'house'],
      'focus': ['ambient', 'electronic', 'lo-fi', 'instrumental', 'classical'],
      'party': ['edm', 'dance', 'house', 'techno', 'hip-hop', 'trap'],
      'workout': ['hip-hop', 'rock', 'metal', 'edm', 'electronic'],
      'romantic': ['soul', 'r&b', 'pop', 'ballad', 'indie'],
    };

    for (final entry in genreMoodMap.entries) {
      final mood = entry.key;
      final keywords = entry.value;
      if (genres.any((g) => keywords.any((k) => g.toLowerCase().contains(k)))) {
        moods.add(mood);
      }
    }

    // Popularity-based adjustments
    if (popularity > 75) moods.add('trending');
    if (popularity < 30) moods.add('underground');

    // Return unique moods, max 5
    return moods.toSet().toList().take(5).toList();
  }

  /// Get all enriched songs in a room queue
  Future<List<Map<String, dynamic>>> getEnrichedQueue(String roomId) async {
    try {
      final snapshot = await db
          .collection('rooms')
          .doc(roomId)
          .collection('queue')
          .get();

      final docs = snapshot.docs;
      docs.sort((a, b) {
        final scoreA = a.data()['voteScore'] ?? 0;
        final scoreB = b.data()['voteScore'] ?? 0;
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        final posA = a.data()['position'] ?? 0;
        final posB = b.data()['position'] ?? 0;
        return posA.compareTo(posB);
      });

      return docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  /// Batch enrich multiple songs
  Future<void> batchEnrichSongs({
    required String roomId,
    required List<Map<String, dynamic>> songs,
  }) async {
    for (final song in songs) {
      final title = song['title'] as String?;
      final artist = song['artist'] as String?;
      final songId = song['id'] as String?;

      if (title == null || artist == null || songId == null) continue;

      // Skip if already enriched
      if (song['metadata'] != null) continue;

      try {
        final metadata = await searchTrackMetadata(title: title, artist: artist);
        if (metadata != null) {
          final cachedUrl = await cacheAlbumArt(
            roomId: roomId,
            songId: songId,
            albumArtUrl: metadata['albumArtUrl'] ?? '',
          );

          await enrichSongInFirestore(
            roomId: roomId,
            songId: songId,
            metadata: metadata,
            cachedAlbumArtUrl: cachedUrl,
          );
        }
      } catch (e) {
      }

      // Rate limiting - Spotify API limits
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
}
