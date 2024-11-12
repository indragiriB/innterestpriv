import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:innterest/screens/comment_screen.dart';
import 'package:innterest/screens/edit_profile_screen.dart';
import 'package:innterest/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseReference _postsRef =
      FirebaseDatabase.instance.ref().child('posts');
  Map<String, dynamic>? _userPosts;
  String? _profilePicUrl;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _loadUserPosts();
  }

  Future<void> _loadCachedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _profilePicUrl = prefs.getString('profile_pic_${widget.user.uid}');
    final cachedPosts = prefs.getString('user_posts_${widget.user.uid}');
    if (cachedPosts != null) {
      setState(() {
        _userPosts = Map<String, dynamic>.from(json.decode(cachedPosts));
      });
    }
  }

  Future<void> _loadUserPosts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    _postsRef
        .orderByChild('userId')
        .equalTo(widget.user.uid)
        .onValue
        .listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        // Update the state with the new posts data
        setState(() {
          _userPosts = data.cast<String, dynamic>();
        });
        // Cache the updated posts data
        await prefs.setString(
            'user_posts_${widget.user.uid}', json.encode(_userPosts));
      } else {
        // Clear the cached posts if no posts are found for the user
        setState(() {
          _userPosts = {};
        });
        await prefs.remove('user_posts_${widget.user.uid}');
      }
    });

    _postsRef
        .orderByChild('userId')
        .equalTo(widget.user.uid)
        .onChildRemoved
        .listen((event) async {
      final removedPostKey = event.snapshot.key;
      if (removedPostKey != null && _userPosts != null) {
        setState(() {
          _userPosts?.remove(removedPostKey);
        });
        if (_userPosts!.isEmpty) {
          // Remove cached posts entirely if no posts remain
          await prefs.remove('user_posts_${widget.user.uid}');
        } else {
          // Update the cache with the remaining posts
          await prefs.setString(
              'user_posts_${widget.user.uid}', json.encode(_userPosts));
        }
      }
    });
  }

  Future<String?> _getProfilePicUrl() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    try {
      final url = await FirebaseStorage.instance
          .ref('profile_pics/${widget.user.uid}.jpg')
          .getDownloadURL();
      await prefs.setString('profile_pic_${widget.user.uid}', url);
      return url;
    } catch (e) {
      return null;
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "innterest's",
          style: TextStyle(
            fontFamily: 'Lobster',
          ),
        ),
        backgroundColor: Color.fromARGB(255, 0, 0, 0),
      ),
      body: Column(
        children: [
          FutureBuilder<String?>(
            future: _profilePicUrl != null
                ? Future.value(_profilePicUrl)
                : _getProfilePicUrl(),
            builder: (context, snapshot) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: Color.fromARGB(167, 54, 53, 53),
                          radius: 50,
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: snapshot.data ?? '',
                              placeholder: (context, url) => Container(
                                color: Color.fromARGB(167, 54, 53, 53),
                                width: 100,
                                height: 100,
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey),
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.displayName ?? 'Username',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Lobster',
                                  fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.user.email ?? 'Email',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditProfileScreen(user: widget.user),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.white),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          child: const Text('EDIT PROFILE'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          child: const Text('LOGOUT'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _userPosts == null
                ? const Center(child: CircularProgressIndicator())
                : _userPosts!.isEmpty
                    ? const Center(
                        child: Text(
                          'No posts yet',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(4),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: _userPosts!.length,
                        itemBuilder: (context, index) {
                          final postId = _userPosts!.keys.elementAt(index);
                          final post = _userPosts![postId];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CommentScreen(postId: postId),
                                ),
                              );
                            },
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: CachedNetworkImage(
                                imageUrl: post['imageUrl'] ?? '',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Color.fromARGB(167, 54, 53, 53),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Color.fromARGB(167, 54, 53, 53),
                                  child: const Icon(Icons.error),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
