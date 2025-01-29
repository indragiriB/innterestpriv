import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:innterest/screens/comment_screen.dart';
import 'package:innterest/screens/saved_posts_screen.dart';
import 'package:innterest/screens/profile_screen.dart';
import 'package:innterest/screens/upload_screen.dart';
import 'package:innterest/screens/message_screen.dart';
import 'package:innterest/screens/search_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:async/async.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  TextEditingController _descriptionController = TextEditingController();
  final DatabaseReference _postsRef =
      FirebaseDatabase.instance.ref().child('posts');
  final DatabaseReference _userRef =
      FirebaseDatabase.instance.ref().child('users');
  late PageController _pageController;
  int _selectedIndex = 0;

  late final List<Widget> pages;
  Map<String, dynamic>? _posts;
  Set<String> _savedPosts = <String>{};
  Map<String, dynamic>? _cachedPosts;
  Map<String, String?> _profilePicsCache = {};

  final Map<String, AsyncMemoizer<String?>> _profilePicMemoizers = {};
  final Map<String, AsyncMemoizer<List<Map<String, dynamic>>>>
      _commentsMemoizers = {};
  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadSavedPosts();
    _pageController = PageController();
  }

  Future<void> _loadPosts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedPosts = prefs.getString('cachedPosts');

    // Check if cached posts exist
    if (cachedPosts != null) {
      setState(() {
        _cachedPosts = jsonDecode(cachedPosts) as Map<String, dynamic>;
      });
    }

    // Listen to posts in the Realtime Database
    _postsRef.orderByChild('timestamp').onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        final postsMap = data.cast<String, dynamic>();

        // Sort posts by timestamp in descending order to ensure the latest post is at the top
        final sortedPosts = postsMap.entries.toList()
          ..sort((a, b) => (b.value['timestamp'] as int)
              .compareTo(a.value['timestamp'] as int));

        setState(() {
          _posts = Map.fromIterable(sortedPosts,
              key: (e) => e.key, value: (e) => e.value);
          _cachedPosts = _posts; // Update cached posts
        });

        // Try saving the posts to SharedPreferences
        try {
          await prefs.setString('cachedPosts', jsonEncode(_posts));
        } catch (e) {
          print("Error saving posts to SharedPreferences: $e");
        }
      }
    }, onError: (error) {
      print("Error listening to posts: $error");
    });

    // Listen specifically for deletions in the Realtime Database
    _postsRef.onChildRemoved.listen((event) async {
      final removedPostKey = event.snapshot.key;

      if (removedPostKey != null && _cachedPosts != null) {
        setState(() {
          _cachedPosts?.remove(removedPostKey);
        });

        // Update the SharedPreferences cache
        try {
          await prefs.setString('cachedPosts', jsonEncode(_cachedPosts));
        } catch (e) {
          print("Error updating cached posts in SharedPreferences: $e");
        }
      }
    });
  }

  Future<String?> _getProfilePicUrlWithMemo(String userId) {
    // Inisialisasi AsyncMemoizer untuk userId jika belum ada
    _profilePicMemoizers[userId] ??= AsyncMemoizer<String?>();
    // Gunakan memoizer per userId
    return _profilePicMemoizers[userId]!
        .runOnce(() => _getProfilePicUrl(userId));
  }

  Future<void> _loadSavedPosts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedPosts = prefs.getStringList('savedPosts') ?? [];

    setState(() {
      _savedPosts = savedPosts.toSet();
    });

    // Listen for changes in Firebase
    final userAlbumRef =
        FirebaseDatabase.instance.ref('albums/${widget.user.uid}');
    userAlbumRef.child('postIds').onValue.listen((event) async {
      final List<dynamic>? postIds = event.snapshot.value as List<dynamic>?;
      if (postIds != null) {
        setState(() {
          _savedPosts = postIds.cast<String>().toSet();
        });

        // Update SharedPreferences to reflect the latest saved posts
        await prefs.setStringList('savedPosts', _savedPosts.toList());
      } else {
        // If postIds is null (meaning no saved posts), clear local cache
        setState(() {
          _savedPosts.clear();
        });
        await prefs.remove('savedPosts');
      }
    });
  }

  void toggleSave(String postId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      if (_savedPosts.contains(postId)) {
        _savedPosts.remove(postId);
        _removeBookmark(postId); // Remove from Firebase as well
      } else {
        _savedPosts.add(postId);
        addPostToAlbum(postId); // Add to Firebase as well
      }
    });

    // Update saved posts in SharedPreferences
    await prefs.setStringList('savedPosts', _savedPosts.toList());
  }

  Future<void> _deletePost(String postId, String imageUrl) async {
    try {
      // Remove post from Realtime Database
      await _postsRef.child(postId).remove();

      // Delete image from Firebase Storage
      await FirebaseStorage.instance.refFromURL(imageUrl).delete();

      setState(() {
        _posts?.remove(postId);
      });
    } catch (e) {
      print('Error deleting post: $e');
    }
  }

  Future<void> _removeBookmark(String postId) async {
    // Reference to the user's album
    final userAlbumRef =
        FirebaseDatabase.instance.ref('albums/${widget.user.uid}');

    // Get the album data
    DataSnapshot albumSnapshot = await userAlbumRef.get();
    if (albumSnapshot.exists) {
      Map<dynamic, dynamic> albumData =
          albumSnapshot.value as Map<dynamic, dynamic>;

      // List to store post IDs from the user's album
      List<dynamic> postIds =
          List.from(albumData['postIds'] as List<dynamic>? ?? []);

      // Check if the postId exists in the album's postIds
      if (postIds.contains(postId)) {
        postIds.remove(postId); // Remove the postId

        // Update the album with the new list of postIds
        await userAlbumRef.update({'postIds': postIds});

        // Update SharedPreferences to remove the postId
        SharedPreferences prefs = await SharedPreferences.getInstance();
        List<String> savedPosts = prefs.getStringList('savedPosts') ?? [];
        savedPosts.remove(postId);
        await prefs.setStringList('savedPosts', savedPosts);

        // Update the local state to reflect the change
        setState(() {
          _savedPosts?.remove(
              postId); // Assuming _savedPosts contains the posts to display
        });
      }
    } else {
      print('No album found for user: ${widget.user.uid}');
    }
  }

  Future<void> addPostToAlbum(String postId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DatabaseReference albumRef =
        FirebaseDatabase.instance.ref('albums/${user.uid}/postIds');

    // Ambil daftar postIds yang ada dalam album
    DataSnapshot snapshot = await albumRef.get();
    List<dynamic> postIds = List.from(snapshot.value as List<dynamic>? ?? []);

    // Tambahkan postId jika belum ada
    if (!postIds.contains(postId)) {
      postIds.add(postId);
      await albumRef.set(postIds);
    }
  }

  Stream<List<Map<String, dynamic>>> _fetchComments(String postId) {
    final commentsRef = _postsRef.child(postId).child('comments');

    // Listen for changes in the comments node
    return commentsRef.orderByChild('timestamp').onValue.map((event) {
      final snapshot = event.snapshot;
      if (snapshot.exists) {
        final comments = snapshot.value as Map<dynamic, dynamic>;
        return comments.values
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    });
  }

  Future<String?> _getUserName(String userId) async {
    DataSnapshot snapshot = await FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(userId)
        .child('username')
        .get();
    if (snapshot.exists) {
      return snapshot.value as String?;
    }
    return null;
  }

  Future<String?> _getProfilePicUrl(String userId) async {
    // Check if profile picture URL is already cached
    if (_profilePicsCache.containsKey(userId)) {
      return _profilePicsCache[userId];
    }

    try {
      String? url = await FirebaseStorage.instance
          .ref('profile_pics/$userId.jpg')
          .getDownloadURL();
      // Cache the profile picture URL
      _profilePicsCache[userId] = url;
      return url;
    } catch (e) {
      return null;
    }
  }

  Future<void> _likePost(String postId) async {
    final DatabaseReference postRef = _postsRef.child(postId);

    // Retrieve the current post data
    DataSnapshot snapshot = await postRef.get();

    if (snapshot.exists) {
      Map post = snapshot.value as Map;
      int currentLikes = post['likes'] ?? 0;
      Map likedBy = post['likedBy'] ?? {};

      // Check if the user has already liked this post
      bool isLiked = likedBy.containsKey(widget.user.uid);

      if (isLiked) {
        // Unlike the post
        currentLikes -= 1;
        likedBy.remove(widget.user.uid);
      } else {
        // Like the post
        currentLikes += 1;
        likedBy[widget.user.uid] = {
          'likeId': postRef.child('likedBy').push().key,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Update the database with new likes and likedBy values
      await postRef.update({
        'likes': currentLikes,
        'likedBy': likedBy,
      });

      // Update the UI immediately
      setState(() {
        _cachedPosts![postId] = {
          ...post,
          'likes': currentLikes,
          'likedBy': likedBy,
        };
      });
    }
  }

  Future<bool> _isFollowing(String userId) async {
    try {
      final uid = widget.user.uid;
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(uid)
          .child('following')
          .child(userId)
          .get();
      return snapshot.exists;
    } catch (e) {
      print("Error checking following status: $e");
      return false;
    }
  }

  Future<void> _followUser(String userId) async {
    try {
      final uid = widget.user.uid;
      final ref = FirebaseDatabase.instance.ref();

      // Add to the following list of the current user
      await ref
          .child('users')
          .child(uid)
          .child('following')
          .child(userId)
          .set(true);

      // Add to the followers list of the target user
      await ref
          .child('users')
          .child(userId)
          .child('followers')
          .child(uid)
          .set(true);
    } catch (e) {
      print("Error following user: $e");
    }
  }

  Future<void> _unfollowUser(String userId) async {
    try {
      final uid = widget.user.uid;
      final ref = FirebaseDatabase.instance.ref();

      // Remove from the following list of the current user
      await ref
          .child('users')
          .child(uid)
          .child('following')
          .child(userId)
          .remove();

      // Remove from the followers list of the target user
      await ref
          .child('users')
          .child(userId)
          .child('followers')
          .child(uid)
          .remove();
    } catch (e) {
      print("Error unfollowing user: $e");
    }
  }

  Future<void> _editPost(String postId, String newCaption) async {
    try {
      await _postsRef.child(postId).update({'caption': newCaption});
      setState(() {
        _posts?[postId]['caption'] = newCaption;
      });
    } catch (e) {
      print('Error editing post: $e');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 4 && hour < 10) {
      return 'Good morning.'; // 04:00 - 09:59
    } else if (hour >= 10 && hour < 15) {
      return 'Good afternoon.'; // 10:00 - 14:59
    } else if (hour >= 15 && hour < 18) {
      return 'Good evening.'; // 15:00 - 17:59
    } else if (hour >= 18 && hour < 22) {
      return 'Good night.'; // 18:00 - 21:59
    } else {
      return 'Sleep well.'; // 22:00 - 03:59
    }
  }

// Inside the _HomeScreenState class

  String _getTimeAgo(int timestamp) {
    final postDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final duration = DateTime.now().difference(postDate);

    if (duration.inDays >= 1) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''} ago';
    } else if (duration.inHours >= 1) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''} ago';
    } else if (duration.inMinutes >= 1) {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'just now';
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Function to show a dialog for editing caption
  void _showEditPostDialog(String postId, String currentCaption) {
    TextEditingController captionController =
        TextEditingController(text: currentCaption);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Post'),
        content: TextField(
          controller: captionController,
          decoration: const InputDecoration(labelText: 'Caption'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _editPost(postId, captionController.text);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTimeBasedIcon() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return {
        'icon': Icons.wb_sunny_rounded, // Ikon matahari yang lebih jelas
        'color':
            Colors.orangeAccent, // Pagi - Ikon matahari dengan warna oranye
      };
    } else if (hour >= 12 && hour < 17) {
      return {
        'icon': Icons.brightness_5_rounded, // Ikon matahari cerah
        'color': const Color.fromARGB(
            255, 241, 159, 5), // Siang - Ikon matahari dengan warna biru terang
      };
    } else if (hour >= 17 && hour < 20) {
      return {
        'icon': Icons.wb_twilight_rounded, // Ikon senja
        'color': Colors
            .deepOrangeAccent, // Sore - Ikon senja dengan warna oranye tua
      };
    } else {
      return {
        'icon': Icons.nights_stay_rounded, // Ikon bulan malam
        'color': Colors.indigo, // Malam - Ikon bulan dengan warna indigo
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Call super to maintain state
    final List<Widget> pages = [
      Scaffold(
        backgroundColor: Color.fromARGB(255, 53, 53, 53),
        appBar: AppBar(
          toolbarHeight: 80,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 21, 21, 21),
                  Color.fromARGB(255, 21, 21, 21),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // const Padding(
                //   padding: EdgeInsets.only(right: 10.0),
                //   child: CircleAvatar(
                //     backgroundImage: AssetImage('assets/images/innterest.png'),
                //     radius: 20,
                //     backgroundColor: Color.fromARGB(167, 54, 53, 53),
                //   ),
                // ),
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: Icon(
                    _getTimeBasedIcon()['icon'],
                    color: _getTimeBasedIcon()['color'],
                    size: 30,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${_getGreeting()}', //, ${widget.user.displayName ?? 'User'}!//
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontFamily: 'Lobster',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.message, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              MessageScreen(currentUser: widget.user)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
                child: _cachedPosts == null
                    ? const Center(child: CircularProgressIndicator())
                    : _cachedPosts!.isEmpty
                        ? const Center(
                            child: Text('No posts available',
                                style: TextStyle(color: Colors.white)))
                        : ListView.builder(
                            cacheExtent: 999999,
                            itemCount: _cachedPosts!.length,
                            itemBuilder: (context, index) {
                              final postId =
                                  _cachedPosts!.keys.elementAt(index);
                              final post = _cachedPosts![postId];
                              final bool isLiked = post['likedBy'] != null &&
                                  post['likedBy'][widget.user.uid] == true;
                              bool isSaved = _savedPosts.contains(postId);
                              final timestamp = post[
                                  'timestamp']; // assuming 'timestamp' holds the time data for post creation

                              return GestureDetector(
                                onDoubleTap: () => _likePost(postId),
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color.fromARGB(255, 21, 21, 21),
                                        Color.fromARGB(255, 21, 21, 21)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          Row(
                                            children: [
                                              FutureBuilder<String?>(
                                                future:
                                                    _getProfilePicUrlWithMemo(
                                                        post['userId']),
                                                builder: (context, snapshot) {
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      color: const Color
                                                          .fromARGB(
                                                          163,
                                                          227,
                                                          226,
                                                          226), // Background color
                                                      shape: BoxShape.circle,
                                                    ),
                                                    padding: const EdgeInsets
                                                        .all(
                                                        2), // Padding around the avatar
                                                    child: CircleAvatar(
                                                      radius: 20,
                                                      backgroundColor:
                                                          const Color.fromARGB(
                                                              167, 54, 53, 53),
                                                      backgroundImage: snapshot
                                                                  .connectionState ==
                                                              ConnectionState
                                                                  .waiting
                                                          ? null
                                                          : (snapshot.hasError ||
                                                                  !snapshot
                                                                      .hasData)
                                                              ? const AssetImage(
                                                                      'assets/images/user.png')
                                                                  as ImageProvider
                                                              : NetworkImage(
                                                                  snapshot
                                                                      .data!),
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  post['userName'] ??
                                                      'Anonymous',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    fontFamily: 'Lobster',
                                                  ),
                                                ),
                                              ),
                                              // Show edit/delete options if the post belongs to the current user
                                              if (post['userId'] ==
                                                  widget.user.uid)
                                                GestureDetector(
                                                  onTap: () {
                                                    showModalBottomSheet(
                                                      context: context,
                                                      backgroundColor:
                                                          Colors.black,
                                                      shape:
                                                          const RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.vertical(
                                                                top: Radius
                                                                    .circular(
                                                                        16)),
                                                      ),
                                                      builder: (BuildContext
                                                          context) {
                                                        return Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            ListTile(
                                                              leading:
                                                                  Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(8),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .white
                                                                      .withOpacity(
                                                                          0.2),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                                child: const Icon(
                                                                    Icons.edit,
                                                                    color: Colors
                                                                        .white70),
                                                              ),
                                                              title: const Text(
                                                                  'Edit',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white70)),
                                                              onTap: () {
                                                                Navigator.pop(
                                                                    context);
                                                                _showEditPostDialog(
                                                                    postId,
                                                                    post['caption'] ??
                                                                        '');
                                                              },
                                                            ),
                                                            ListTile(
                                                              leading:
                                                                  Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(8),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .redAccent
                                                                      .withOpacity(
                                                                          0.2),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                                child: const Icon(
                                                                    Icons
                                                                        .delete,
                                                                    color: Colors
                                                                        .redAccent),
                                                              ),
                                                              title: const Text(
                                                                  'Delete',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .redAccent)),
                                                              onTap: () {
                                                                Navigator.pop(
                                                                    context);
                                                                _deletePost(
                                                                    postId,
                                                                    post['imageUrl'] ??
                                                                        '');
                                                              },
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          const Color.fromARGB(
                                                                  255,
                                                                  138,
                                                                  137,
                                                                  137)
                                                              .withOpacity(0.2),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                        Icons.more_vert,
                                                        color: Color.fromARGB(
                                                            255, 0, 0, 0)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Stack(
                                            children: [
                                              Row(
                                                children: [
                                                  FutureBuilder<String?>(
                                                    future:
                                                        _getProfilePicUrlWithMemo(
                                                            post['userId']),
                                                    builder:
                                                        (context, snapshot) {
                                                      return Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color
                                                              .fromARGB(
                                                              163,
                                                              227,
                                                              226,
                                                              226), // Background color
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        padding: const EdgeInsets
                                                            .all(
                                                            2), // Padding around the avatar
                                                        child: CircleAvatar(
                                                          radius: 20,
                                                          backgroundColor:
                                                              const Color
                                                                  .fromARGB(167,
                                                                  54, 53, 53),
                                                          backgroundImage: snapshot
                                                                      .connectionState ==
                                                                  ConnectionState
                                                                      .waiting
                                                              ? null
                                                              : (snapshot.hasError ||
                                                                      !snapshot
                                                                          .hasData)
                                                                  ? const AssetImage(
                                                                          'assets/images/user.png')
                                                                      as ImageProvider
                                                                  : NetworkImage(
                                                                      snapshot
                                                                          .data!),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      post['userName'] ??
                                                          'Anonymous',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        fontFamily: 'Lobster',
                                                      ),
                                                    ),
                                                  ),
                                                  // Show edit/delete options if the post belongs to the current user
                                                  if (post['userId'] ==
                                                      widget.user.uid)
                                                    GestureDetector(
                                                      onTap: () {
                                                        showModalBottomSheet(
                                                          context: context,
                                                          backgroundColor:
                                                              const Color
                                                                  .fromARGB(255,
                                                                  30, 29, 29),
                                                          shape:
                                                              const RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.vertical(
                                                                    top: Radius
                                                                        .circular(
                                                                            26)),
                                                          ),
                                                          builder: (BuildContext
                                                              context) {
                                                            return Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                ListTile(
                                                                  leading:
                                                                      Container(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            8),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: Colors
                                                                          .white
                                                                          .withOpacity(
                                                                              0.2),
                                                                      shape: BoxShape
                                                                          .circle,
                                                                    ),
                                                                    child: const Icon(
                                                                        Icons
                                                                            .edit,
                                                                        color: Colors
                                                                            .white70),
                                                                  ),
                                                                  title: const Text(
                                                                      'Edit',
                                                                      style: TextStyle(
                                                                          color:
                                                                              Colors.white70)),
                                                                  onTap: () {
                                                                    Navigator.pop(
                                                                        context);
                                                                    _showEditPostDialog(
                                                                        postId,
                                                                        post['caption'] ??
                                                                            '');
                                                                  },
                                                                ),
                                                                ListTile(
                                                                  leading:
                                                                      Container(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            8),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: Colors
                                                                          .redAccent
                                                                          .withOpacity(
                                                                              0.2),
                                                                      shape: BoxShape
                                                                          .circle,
                                                                    ),
                                                                    child: const Icon(
                                                                        Icons
                                                                            .delete,
                                                                        color: Colors
                                                                            .redAccent),
                                                                  ),
                                                                  title: const Text(
                                                                      'Delete',
                                                                      style: TextStyle(
                                                                          color:
                                                                              Colors.redAccent)),
                                                                  onTap: () {
                                                                    Navigator.pop(
                                                                        context);
                                                                    _deletePost(
                                                                        postId,
                                                                        post['imageUrl'] ??
                                                                            '');
                                                                  },
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        );
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color
                                                                  .fromARGB(255,
                                                                  255, 255, 255)
                                                              .withOpacity(0.9),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                            Icons.more_vert,
                                                            color:
                                                                Color.fromARGB(
                                                                    255,
                                                                    0,
                                                                    0,
                                                                    0)),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: FutureBuilder<bool>(
                                                  future: _isFollowing(
                                                      post['userId']),
                                                  builder: (context, snapshot) {
                                                    if (snapshot
                                                            .connectionState ==
                                                        ConnectionState
                                                            .waiting) {
                                                      ; // Loading indicator
                                                    }
                                                    if (snapshot.hasError ||
                                                        !snapshot.hasData) {
                                                      return Container(); // Handle error or no data case
                                                    }
                                                    final isFollowing =
                                                        snapshot.data!;

                                                    // Show follow/unfollow button only if the post is not by the current user
                                                    if (post['userId'] ==
                                                        widget.user.uid) {
                                                      return Container(); // No button for own posts
                                                    }

                                                    return GestureDetector(
                                                      onTap: () async {
                                                        if (isFollowing) {
                                                          await _unfollowUser(
                                                              post['userId']);
                                                        } else {
                                                          await _followUser(
                                                              post['userId']);
                                                        }
                                                        setState(
                                                            () {}); // Update the state to reflect the change
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 15,
                                                                vertical: 7),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isFollowing
                                                              ? const Color
                                                                      .fromARGB(
                                                                      255,
                                                                      219,
                                                                      5,
                                                                      5)
                                                                  .withOpacity(
                                                                      0.5)
                                                              : const Color
                                                                      .fromARGB(
                                                                      255,
                                                                      94,
                                                                      93,
                                                                      95)
                                                                  .withOpacity(
                                                                      0.5),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: Text(
                                                          isFollowing
                                                              ? 'Unfollow'
                                                              : 'Follow',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                            color: Colors.white,
                                                            fontFamily:
                                                                'Lobster',
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 15),
                                      Stack(
                                        children: [
                                          // Gesture detector to detect a single tap on the image
                                          GestureDetector(
                                            onTap: () {
                                              // Show the full image in a dialog
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return Dialog(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    child: GestureDetector(
                                                      onTap: () =>
                                                          Navigator.of(context)
                                                              .pop(),
                                                      child: CachedNetworkImage(
                                                        imageUrl:
                                                            post['imageUrl'] ??
                                                                '',
                                                        fit: BoxFit.contain,
                                                        placeholder: (context,
                                                                url) =>
                                                            CircularProgressIndicator(),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            const Icon(
                                                                Icons.error),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                            child: AspectRatio(
                                              aspectRatio:
                                                  .75, // Adjust the aspect ratio as needed
                                              child: CachedNetworkImage(
                                                imageUrl:
                                                    post['imageUrl'] ?? '',
                                                fit: BoxFit.cover,
                                                width: double
                                                    .infinity, // Full width
                                                placeholder: (context, url) =>
                                                    Container(
                                                        color: Colors
                                                            .grey.shade800),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(Icons.error),
                                              ),
                                            ),
                                          ),
                                          // Timestamp at the top right
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.6),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _getTimeAgo(timestamp),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      if (post['title'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 4.0),
                                          child: Text(
                                            post['title'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Lobster',
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      if (post['caption'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 4.0),
                                          child: Text(
                                            post['caption'],
                                            style: const TextStyle(
                                                color: Colors.white70),
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () async {
                                              await _likePost(
                                                  postId); // Call the like/unlike function
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _cachedPosts != null &&
                                                        _cachedPosts![postId]
                                                                ?['likedBy'] !=
                                                            null &&
                                                        _cachedPosts![postId]![
                                                                    'likedBy'][
                                                                widget.user
                                                                    .uid] !=
                                                            null
                                                    ? Colors.red
                                                        .withOpacity(0.2)
                                                    : Colors.white
                                                        .withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                _cachedPosts != null &&
                                                        _cachedPosts![postId]
                                                                ?['likedBy'] !=
                                                            null &&
                                                        _cachedPosts![postId]![
                                                                    'likedBy'][
                                                                widget.user
                                                                    .uid] !=
                                                            null
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color: Colors
                                                    .red, // You can also make this dynamic if desired
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          GestureDetector(
                                            onTap: () => toggleSave(postId),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isSaved
                                                    ? const Color.fromARGB(
                                                            255, 177, 177, 177)
                                                        .withOpacity(0.2)
                                                    : Colors.white
                                                        .withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isSaved
                                                    ? Icons.bookmark
                                                    : Icons.bookmark_border,
                                                color: isSaved
                                                    ? const Color.fromARGB(
                                                        255, 255, 255, 255)
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      CommentScreen(
                                                          postId: postId),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.comment,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const Spacer(), // Add spacer to push the text to the right
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 12.0),
                                            child: Text(
                                              '${_cachedPosts?[postId]?['likes'] ?? 0} likes, ${_cachedPosts?[postId]?['commentsCount'] ?? 0} comments',
                                              style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )),
          ],
        ),
      ),
      UploadScreen(user: widget.user),
      SavedPostsScreen(user: widget.user),
      SearchScreen(userId: widget.user.uid),
      ProfileScreen(user: widget.user),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 32, 32, 32), // Start color
              Color.fromARGB(255, 20, 20, 20), // End color (adjust as needed)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor:
              Colors.transparent, // Set to transparent to see the gradient
          selectedItemColor: const Color.fromARGB(
              255, 255, 255, 255), // Change color for selected icon
          unselectedItemColor: Colors.grey, // Color for unselected icons
          showUnselectedLabels: false,
          showSelectedLabels: false,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled, size: 25), // Filled home icon
              label: '', // No title
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline,
                  size: 25), // Outline upload icon
              label: '', // No title
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_border,
                  size: 25), // Outline bookmark icon
              label: '', // No title
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search, size: 25), // Add the search icon
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 25), // Outline person icon
              label: '', // No title
            ),
          ],
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
