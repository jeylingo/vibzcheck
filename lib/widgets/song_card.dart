import 'package:flutter/material.dart';

/// Widget to display a song with album art, metadata, and controls
class SongCard extends StatelessWidget {
  final String title;
  final String artist;
  final String? albumArtUrl;
  final List<String> genres;
  final List<String> moods;
  final int? popularity;
  final int voteScore;
  final int userVote; // -1, 0, or 1
  final bool isHost;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback? onMore;

  const SongCard({
    super.key,
    required this.title,
    required this.artist,
    required this.voteScore,
    required this.userVote,
    required this.isHost,
    required this.onUpvote,
    required this.onDownvote,
    this.albumArtUrl,
    this.genres = const [],
    this.moods = const [],
    this.popularity,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: albumArtUrl != null && albumArtUrl!.isNotEmpty
                  ? Image.network(
                      albumArtUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _placeholderArt(),
                    )
                  : _placeholderArt(),
            ),
            const SizedBox(width: 12),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    artist,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (genres.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        genres.take(2).join(', '),
                        style: const TextStyle(fontSize: 8, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (moods.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Wrap(
                        spacing: 3,
                        runSpacing: 2,
                        children: moods.take(2).map((mood) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[900],
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              mood,
                              style: const TextStyle(fontSize: 7, color: Colors.white),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Vote score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: voteScore > 0 ? Colors.green[700] : voteScore < 0 ? Colors.red[700] : Colors.grey[700],
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                voteScore > 0 ? '+$voteScore' : '$voteScore',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10),
              ),
            ),
            const SizedBox(width: 3),
            // Popularity badge
            if (popularity != null)
              Tooltip(
                message: 'Spotify popularity: $popularity%',
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange[700],
                  ),
                  child: Text(
                    '${(popularity! / 10).round()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 8),
                  ),
                ),
              ),
            const SizedBox(width: 2),
            // Vote buttons
            SizedBox(
              width: 32,
              child: IconButton(
                onPressed: onUpvote,
                icon: const Icon(Icons.thumb_up),
                color: userVote == 1 ? Colors.green : Colors.grey,
                iconSize: 14,
                padding: EdgeInsets.zero,
              ),
            ),
            SizedBox(
              width: 32,
              child: IconButton(
                onPressed: onDownvote,
                icon: const Icon(Icons.thumb_down),
                color: userVote == -1 ? Colors.red : Colors.grey,
                iconSize: 14,
                padding: EdgeInsets.zero,
              ),
            ),
            if (isHost && onMore != null)
              SizedBox(
                width: 32,
                child: IconButton(
                  onPressed: onMore,
                  icon: const Icon(Icons.more_vert),
                  iconSize: 14,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderArt() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.music_note, size: 28),
    );
  }
}
