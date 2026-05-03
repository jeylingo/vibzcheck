import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../../services/chat_service.dart';
import '../../services/room_service.dart';
import '../../widgets/song_card.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String code;

  const RoomScreen({super.key, required this.roomId, required this.code});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final RoomService service = RoomService();
  final ChatService chatService = ChatService();
  bool addingSong = false;
  String error = '';
  
  // Track user's votes for each song: songId -> voteValue (-1, 0, or 1)
  final Map<String, int> userVotes = {};
  
  // Chat state
  final TextEditingController messageController = TextEditingController();
  bool showChat = true;
  Timer? typingTimer;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    messageController.dispose();
    typingTimer?.cancel();
    // Clear typing status when leaving
    chatService.clearTyping(widget.roomId);
    super.dispose();
  }

  Future<void> _fetchUserVote(String songId) async {
    if (currentUser == null) return;
    try {
      final voteDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('queue')
          .doc(songId)
          .collection('votes')
          .doc(currentUser!.uid)
          .get();
      
      if (voteDoc.exists) {
        setState(() {
          userVotes[songId] = (voteDoc.data()?['voteValue'] ?? 0) as int;
        });
      } else {
        setState(() {
          userVotes[songId] = 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching vote for $songId: $e');
    }
  }

  Future<void> _showAddSongDialog() async {
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    final genreController = TextEditingController();
    final moodsController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Song'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: artistController, decoration: const InputDecoration(labelText: 'Artist')),
                TextField(controller: genreController, decoration: const InputDecoration(labelText: 'Genre')),
                TextField(controller: moodsController, decoration: const InputDecoration(labelText: 'Moods (comma separated)')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final artist = artistController.text.trim();
                final genre = genreController.text.trim();
                final moods = moodsController.text
                    .split(',')
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toList();

                if (title.isEmpty || artist.isEmpty || genre.isEmpty) {
                  if (mounted) {
                    setState(() => error = 'Title, artist, and genre are required.');
                  }
                  return;
                }

                Navigator.pop(dialogContext);
                setState(() {
                  addingSong = true;
                  error = '';
                });

                try {
                  await service.addSongToQueue(
                    roomId: widget.roomId,
                    title: title,
                    artist: artist,
                    genre: genre,
                    moods: moods,
                  );
                } catch (e) {
                  if (mounted) {
                    setState(() => error = e.toString());
                  }
                } finally {
                  if (mounted) {
                    setState(() => addingSong = false);
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _vote(String songId, int value) async {
    setState(() => error = '');
    
    // If user already voted this way, toggle it off (unvote)
    final currentVote = userVotes[songId] ?? 0;
    final voteToSend = currentVote == value ? 0 : value;

    try {
      await service.voteOnSong(roomId: widget.roomId, songId: songId, voteValue: voteToSend);
      setState(() {
        userVotes[songId] = voteToSend;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _moveUp(String songId) async {
    try {
      await service.moveSongUp(roomId: widget.roomId, songId: songId);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _remove(String songId) async {
    try {
      await service.removeSong(roomId: widget.roomId, songId: songId);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  void _showHostMenu(String songId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.arrow_upward),
            title: const Text('Move Up'),
            onTap: () {
              Navigator.pop(context);
              _moveUp(songId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Remove'),
            onTap: () {
              Navigator.pop(context);
              _remove(songId);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _skip() async {
    try {
      await service.skipToNext(roomId: widget.roomId);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _toggleLock(bool locked) async {
    try {
      await service.setQueueLocked(roomId: widget.roomId, locked: locked);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _sendChatMessage() async {
    final content = messageController.text.trim();
    if (content.isEmpty) return;

    messageController.clear();
    await chatService.clearTyping(widget.roomId);
    typingTimer?.cancel();

    try {
      await chatService.sendMessage(
        roomId: widget.roomId,
        content: content,
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    }
  }

  void _onMessageInputChanged(String text) {
    typingTimer?.cancel();
    
    if (text.isEmpty) {
      chatService.clearTyping(widget.roomId);
      return;
    }

    // Set typing status when user starts typing
    chatService.setTyping(widget.roomId);
    
    // Clear typing status 2 seconds after last keystroke
    typingTimer = Timer(const Duration(seconds: 2), () {
      chatService.clearTyping(widget.roomId);
    });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueStream = service.watchRoomQueue(widget.roomId);
    final membersStream = service.watchRoomMembers(widget.roomId);
    final roomStateStream = service.watchRoomState(widget.roomId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Room • ${widget.code}'),
        actions: [
          IconButton(
            onPressed: addingSong ? null : _showAddSongDialog,
            icon: const Icon(Icons.queue_music),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: roomStateStream,
          builder: (context, roomSnapshot) {
            final roomData = roomSnapshot.data?.data();
            final isHost = roomData != null && currentUser != null && roomData['ownerId'] == currentUser!.uid;
            final queueLocked = roomData?['queueLocked'] == true;
            final nowPlaying = roomData?['nowPlaying'] as Map<String, dynamic>?;

            final queuePanel = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Room ID: ${widget.roomId}', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      if (error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(error, style: const TextStyle(color: Colors.red), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      Card(
                        child: ListTile(
                          title: const Text('Now Playing'),
                          subtitle: nowPlaying == null
                              ? const Text('Nothing is playing yet')
                              : Text('${nowPlaying['title'] ?? ''} • ${nowPlaying['artist'] ?? ''}', overflow: TextOverflow.ellipsis),
                          trailing: isHost
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(queueLocked ? 'Locked' : 'Open', style: const TextStyle(fontSize: 12)),
                                    Switch(value: queueLocked, onChanged: _toggleLock),
                                  ],
                                )
                              : Text(queueLocked ? 'Locked by host' : 'Open', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isHost)
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _skip,
                              icon: const Icon(Icons.skip_next),
                              label: const Text('Skip'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: addingSong ? null : _showAddSongDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Song'),
                            ),
                          ],
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: addingSong ? null : _showAddSongDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Song'),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text('Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(
                        height: 60,
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: membersStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            final docs = snapshot.data!.docs;
                            if (docs.isEmpty) return const Center(child: Text('No members yet'));
                            return ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: docs.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final data = docs[index].data();
                                return Chip(label: Text(data['displayName'] ?? data['uid'] ?? 'Member'));
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Up Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: queueStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            final docs = snapshot.data!.docs;
                            if (docs.isEmpty) return const Center(child: Text('Queue is empty'));
                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data();
                                final title = data['title'] ?? '';
                                final artist = data['artist'] ?? '';
                                final score = data['voteScore'] ?? 0;
                                
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!userVotes.containsKey(doc.id)) {
                                    _fetchUserVote(doc.id);
                                  }
                                });
                                
                                final userVote = userVotes[doc.id] ?? 0;

                                final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
                                final albumArtUrl = metadata['albumArtUrl'] as String?;
                                final genres = (metadata['genres'] as List?)?.cast<String>() ?? [];
                                final moods = (metadata['moods'] as List?)?.cast<String>() ?? [];
                                final popularity = metadata['popularity'] as int?;

                                return SongCard(
                                  title: title,
                                  artist: artist,
                                  voteScore: score,
                                  userVote: userVote,
                                  isHost: isHost,
                                  albumArtUrl: albumArtUrl,
                                  genres: genres,
                                  moods: moods,
                                  popularity: popularity,
                                  onUpvote: () => _vote(doc.id, 1),
                                  onDownvote: () => _vote(doc.id, -1),
                                  onMore: isHost ? () => _showHostMenu(doc.id) : null,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );

            final chatPanel = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 8),
                      // Chat messages
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: chatService.watchMessages(widget.roomId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            final messages = snapshot.data!.docs;
                            return ListView.separated(
                              reverse: false,
                              itemCount: messages.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final msgDoc = messages[index];
                                final msg = msgDoc.data();
                                final displayName = msg['displayName'] ?? 'User';
                                final content = msg['content'] ?? '';
                                final timestamp = msg['timestamp'] as Timestamp?;
                                final isOwnMessage = msg['userId'] == currentUser?.uid;

                                return Align(
                                  alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width < 700
                                          ? MediaQuery.of(context).size.width * 0.7
                                          : MediaQuery.of(context).size.width * 0.25,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOwnMessage ? Colors.blue[600] : Colors.grey[600],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          content,
                                          style: const TextStyle(fontSize: 11, color: Colors.white),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: const TextStyle(fontSize: 8, color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Typing indicators
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: chatService.watchTypingStatus(widget.roomId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                          final typing = snapshot.data!;
                          final typingNames = typing.map((t) => t['displayName']).join(', ');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '$typingNames is typing...',
                              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                      // Chat input
                      Container(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.grey[700]!)),
                        ),
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: messageController,
                                onChanged: _onMessageInputChanged,
                                decoration: InputDecoration(
                                  hintText: 'Message...',
                                  hintStyle: const TextStyle(fontSize: 12),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                  isDense: true,
                                ),
                                maxLines: null,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _sendChatMessage,
                              icon: const Icon(Icons.send, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

            final isCompact = MediaQuery.of(context).size.width < 900;

            if (isCompact) {
              return Column(
                children: [
                  Expanded(
                    child: queuePanel,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 260,
                    child: chatPanel,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: queuePanel,
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: chatPanel,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
