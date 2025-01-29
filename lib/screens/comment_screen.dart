import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommentScreen extends StatefulWidget {
  final String postId;

  const CommentScreen({super.key, required this.postId});

  @override
  _CommentScreenState createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final _commentController = TextEditingController();
  final _editCommentController = TextEditingController();
  late DatabaseReference _commentsRef;
  String? _replyToUserId;
  String? _replyToUserName;
  Map<String, dynamic>? _cachedComments;
  String? _editingCommentId;

  @override
  void initState() {
    super.initState();
    _commentsRef = FirebaseDatabase.instance
        .ref()
        .child('posts')
        .child(widget.postId)
        .child('comments');
    _loadComments();
  }

  Future<void> _loadComments() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedComments = prefs.getString('cachedComments_${widget.postId}');

    if (cachedComments != null) {
      setState(() {
        _cachedComments = jsonDecode(cachedComments) as Map<String, dynamic>;
      });
    }

    _commentsRef.orderByChild('timestamp').onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final commentsMap = data.cast<String, dynamic>();
        setState(() {
          _cachedComments = commentsMap;
        });
        try {
          await prefs.setString(
              'cachedComments_${widget.postId}', jsonEncode(commentsMap));
        } catch (e) {
          print("Error saving comments to SharedPreferences: $e");
        }
      }
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;

      // Pastikan pengguna sudah login
      if (user != null) {
        // Ambil URL gambar profil dari Firebase Storage
        String profileUrl = '';
        try {
          profileUrl = await FirebaseStorage.instance
              .ref('profile_pics/${user.uid}.jpg')
              .getDownloadURL();
        } catch (e) {
          print("Gagal mengambil URL gambar profil: $e");
          profileUrl = ''; // Fallback jika URL tidak tersedia
        }

        final userName = user.displayName ??
            'Anonymous'; // Gunakan displayName atau fallback ke 'Anonymous'

        // Membuat referensi komentar baru
        DatabaseReference newCommentRef = _commentsRef.push();
        String commentId = newCommentRef.key!;

        await newCommentRef.set({
          'commentId': commentId,
          'text': _commentController.text,
          'userId': user.uid,
          'userName': userName, // Username dari database
          'profilePictureUrl':
              profileUrl, // URL gambar profil dari Firebase Storage
          'replyToUserId': _replyToUserId ?? '',
          'replyToUserName': _replyToUserName ?? '',
          'timestamp': ServerValue.timestamp,
        });

        // Perbarui jumlah komentar di post terkait
        final postRef =
            FirebaseDatabase.instance.ref().child('posts').child(widget.postId);
        final snapshot = await postRef.child('commentsCount').get();
        int currentCount = snapshot.value as int? ?? 0;
        await postRef.child('commentsCount').set(currentCount + 1);

        _commentController.clear();
        _clearReply();
      } else {
        print("Tidak ada pengguna yang login.");
      }
    }
  }

  Future<void> _editComment(String commentId, String newText) async {
    await _commentsRef.child(commentId).update({
      'text': newText,
      'timestamp': ServerValue.timestamp, // Update the timestamp when edited
    });

    setState(() {
      _editingCommentId = null;
      _editCommentController.clear();
    });
  }

  Future<void> _deleteComment(String commentId) async {
    await _commentsRef.child(commentId).remove();
    final postRef =
        FirebaseDatabase.instance.ref().child('posts').child(widget.postId);
    final snapshot = await postRef.child('commentsCount').get();
    int currentCount = snapshot.value as int? ?? 0;
    await postRef.child('commentsCount').set(currentCount - 1);
  }

  void _clearReply() {
    setState(() {
      _replyToUserId = null;
      _replyToUserName = null;
      _editingCommentId = null;
    });
  }

  void _replyToComment(String userId, String userName) {
    setState(() {
      _replyToUserId = userId;
      _replyToUserName = userName;
      _commentController.text = ' '; // Pre-fill text field
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Comments',
          style: TextStyle(fontFamily: 'Lobster'),
        ),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        actions: [
          StreamBuilder(
            stream: FirebaseDatabase.instance
                .ref()
                .child('posts')
                .child(widget.postId)
                .child('commentsCount')
                .onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final count = snapshot.data!.snapshot.value as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: Text(
                    '$count Comments',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_replyToUserName != null)
            Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to $_replyToUserName',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: _clearReply,
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder(
              stream: _commentsRef.orderByChild('timestamp').onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.snapshot.value;

                if (data is! Map) {
                  return const Center(
                      child: Text('No comments yet',
                          style: TextStyle(color: Colors.white)));
                }

                final comments = (data).values.toList()
                  ..sort((a, b) =>
                      (b['timestamp'] as int).compareTo(a['timestamp'] as int));

                if (comments.isEmpty) {
                  return const Center(
                      child: Text('No comments yet',
                          style: TextStyle(color: Colors.white)));
                }

                return ListView.builder(
                  cacheExtent: 9999,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final profilePictureUrl =
                        comment['profilePictureUrl'] as String?;
                    final hasReplies =
                        (comment['replies'] as Map?)?.isNotEmpty ?? false;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color.fromARGB(255, 132, 129, 129),
                            backgroundImage: profilePictureUrl != null &&
                                    profilePictureUrl.isNotEmpty
                                ? NetworkImage(profilePictureUrl)
                                : const AssetImage('assets/images/user.png')
                                    as ImageProvider,
                          ),
                          title: Text(
                            '${comment['userName']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lobster',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: _editingCommentId == comment['commentId']
                              ? TextField(
                                  controller: _editCommentController,
                                  decoration: const InputDecoration(
                                    labelText: 'Edit comment',
                                    labelStyle:
                                        TextStyle(color: Colors.white70),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white70),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white70),
                                    ),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      comment['text'],
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 18),
                                    ),
                                    Text(
                                      _formatTimeAgo(
                                          comment['timestamp'] as int),
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                    if (comment['replyToUserName'] != null &&
                                        comment['replyToUserName'] != '')
                                      Text(
                                        'Replying to ${comment['replyToUserName']}',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12),
                                      ),
                                  ],
                                ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white70),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor:
                                    const Color.fromARGB(255, 9, 9, 9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                ),
                                builder: (BuildContext context) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (FirebaseAuth
                                              .instance.currentUser!.uid ==
                                          comment['userId'])
                                        ListTile(
                                          leading: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.edit,
                                                color: Colors.white70),
                                          ),
                                          title: Text('Edit',
                                              style: TextStyle(
                                                  color: Colors.white70)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            setState(() {
                                              _editingCommentId =
                                                  comment['commentId'];
                                              _editCommentController.text =
                                                  comment['text'];
                                            });
                                          },
                                        ),
                                      if (FirebaseAuth
                                              .instance.currentUser!.uid ==
                                          comment['userId'])
                                        ListTile(
                                          leading: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.delete,
                                                color: Color.fromARGB(
                                                    179, 241, 0, 0)),
                                          ),
                                          title: Text('Delete',
                                              style: TextStyle(
                                                  color: Colors.redAccent)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _deleteComment(
                                                comment['commentId']);
                                          },
                                        ),
                                      ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.reply,
                                              color: Color.fromARGB(
                                                  179, 3, 132, 48)),
                                        ),
                                        title: Text('Reply',
                                            style: TextStyle(
                                                color: Colors.white70)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _replyToComment(comment['userId'],
                                              comment['userName']);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        if (_editingCommentId == comment['commentId'])
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () {
                              _editComment(comment['commentId'],
                                  _editCommentController.text);
                            },
                          ),
                        if (hasReplies)
                          Padding(
                            padding: const EdgeInsets.only(left: 64.0),
                            child: Column(
                              children: _buildReplies(comment['replies']),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                          255, 21, 21, 21), // Background color for TextField
                      borderRadius:
                          BorderRadius.circular(20), // Rounded corners
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(
                            color: Color.fromARGB(136, 255, 255, 255),
                            fontFamily: 'Lobster',
                            fontSize: 16),
                        border: InputBorder.none, // Remove default border
                      ),
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(
                        255, 255, 255, 255), // Background color for IconButton
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send,
                        color: Color.fromARGB(255, 0, 0, 0)),
                    onPressed: _addComment,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildReplies(Map<String, dynamic> replies) {
    return replies.entries.map((entry) {
      final reply = entry.value;
      final profilePictureUrl = reply['profilePictureUrl'] as String?;
      return ListTile(
        leading: CircleAvatar(
          backgroundImage: profilePictureUrl != null &&
                  profilePictureUrl.isNotEmpty
              ? NetworkImage(profilePictureUrl)
              : const AssetImage('assets/default_profile.png') as ImageProvider,
        ),
        title: Text(
          '${reply['userName']}: ${reply['text']}',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          _formatTimeAgo(reply['timestamp'] as int),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }).toList();
  }

  String _formatTimeAgo(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
