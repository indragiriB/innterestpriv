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
import 'package:innterest/screens/message_screen.dart';

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final DatabaseReference _postsRef =
      FirebaseDatabase.instance.ref().child('posts');
  Map<String, dynamic>? _userPosts;

  @override
  void initState() {
    super.initState();
    _loadUserPosts();
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
        setState(() {
          _userPosts = data.cast<String, dynamic>();
        });
        await prefs.setString(
            'user_posts_${widget.user.uid}', json.encode(_userPosts));
      } else {
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
          await prefs.remove('user_posts_${widget.user.uid}');
        } else {
          await prefs.setString(
              'user_posts_${widget.user.uid}', json.encode(_userPosts));
        }
      }
    });
  }

  Future<String?> _getProfilePicUrl(String userId) async {
    try {
      final url = await FirebaseStorage.instance
          .ref('profile_pics/$userId.jpg')
          .getDownloadURL();
      return url;
    } catch (e) {
      return null; // Return null if fetching profile picture fails
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
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
    super.build(context);
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 0, 0, 0),
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
                  'Profile Screen.', //, ${widget.user.displayName ?? 'User'}!//
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
          FutureBuilder<String?>(
            future: _getProfilePicUrl(widget.user.uid),
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
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor:
                                  const Color.fromARGB(167, 72, 71, 71),
                              backgroundImage: snapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? null
                                  : (snapshot.hasError || !snapshot.hasData)
                                      ? const AssetImage(
                                              'assets/images/user.png')
                                          as ImageProvider
                                      : NetworkImage(snapshot.data!),
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
                                horizontal: 24, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(
                                  color: Color.fromARGB(255, 75, 75, 75)),
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
