import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:innterest/screens/profile_screen.dart';
import 'package:innterest/screens/upload_screen.dart';
import 'package:innterest/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SavedPostsScreen extends StatefulWidget {
  final User user;

  const SavedPostsScreen({super.key, required this.user});

  @override
  _SavedPostsScreenState createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final DatabaseReference _userAlbumRef =
      FirebaseDatabase.instance.ref().child('albums');
  Map<String, dynamic>? _savedPosts = {};
  final int _selectedIndex = 2;

  String? _albumName;
  String? _albumDescription;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
    _loadAlbumDetails();
  }

  Future<void> _loadSavedPosts() async {
    DataSnapshot snapshot =
        await _userAlbumRef.child(widget.user.uid).child('postIds').get();
    if (snapshot.exists) {
      final savedPostIds =
          List<String>.from(snapshot.value as List<dynamic>? ?? []);
      final Map<String, dynamic> posts = {};

      for (String postId in savedPostIds) {
        final postSnapshot =
            await FirebaseDatabase.instance.ref('posts/$postId').get();
        if (postSnapshot.exists) {
          posts[postId] = postSnapshot.value;
        }
      }

      setState(() {
        _savedPosts = posts;
      });
    }
  }

  Future<void> _loadAlbumDetails() async {
    DataSnapshot albumSnapshot =
        await _userAlbumRef.child(widget.user.uid).get();
    if (albumSnapshot.exists) {
      setState(() {
        _albumName = albumSnapshot.child('albumName').value as String?;
        _albumDescription = albumSnapshot.child('description').value as String?;
      });
      print('Album Name: $_albumName, Description: $_albumDescription');
    } else {
      print('No album found for user: ${widget.user.uid}');
    }
  }

  Future<void> _editAlbumDescription() async {
    final TextEditingController _descriptionController =
        TextEditingController(text: _albumDescription);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Album Description'),
          content: TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Album Description',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newDescription = _descriptionController.text;
                await _userAlbumRef
                    .child(widget.user.uid)
                    .update({'description': newDescription});
                setState(() {
                  _albumDescription = newDescription;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeBookmark(String postId) async {
    final userAlbumRef =
        FirebaseDatabase.instance.ref('albums/${widget.user.uid}');
    DataSnapshot albumSnapshot = await userAlbumRef.get();
    if (albumSnapshot.exists) {
      Map<dynamic, dynamic> albumData =
          albumSnapshot.value as Map<dynamic, dynamic>;
      List<dynamic> postIds =
          List.from(albumData['postIds'] as List<dynamic>? ?? []);

      if (postIds.contains(postId)) {
        postIds.remove(postId);
        await userAlbumRef.update({'postIds': postIds});
        SharedPreferences prefs = await SharedPreferences.getInstance();
        List<String> savedPosts = prefs.getStringList('savedPosts') ?? [];
        savedPosts.remove(postId);
        await prefs.setStringList('savedPosts', savedPosts);
        setState(() {
          _savedPosts?.remove(postId);
        });
      }
    } else {
      print('No album found for user: ${widget.user.uid}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(
                left: 26.0, top: 50.0, right: 16.0, bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _albumName ?? 'Album Name',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Lobster',
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _editAlbumDescription,
                  child: Text(
                    _albumDescription ?? 'No description',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _savedPosts == null
                ? const Center(child: CircularProgressIndicator())
                : _savedPosts!.isEmpty
                    ? const Center(
                        child: Text(
                          'No saved posts',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : MasonryGridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        itemCount: _savedPosts!.length,
                        itemBuilder: (context, index) {
                          final post = _savedPosts!.values.elementAt(index);
                          final postId = _savedPosts!.keys.elementAt(index);
                          return Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return Dialog(
                                        backgroundColor: Colors.transparent,
                                        child: GestureDetector(
                                          onTap: () =>
                                              Navigator.of(context).pop(),
                                          child: CachedNetworkImage(
                                            imageUrl: post['imageUrl'] ?? '',
                                            fit: BoxFit.contain,
                                            placeholder: (context, url) =>
                                                CircularProgressIndicator(),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: post['imageUrl'] ?? '',
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey.shade800,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(165, 66, 66,
                                        66), // Background color suitable for dark mode
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.bookmark_remove_outlined,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                    onPressed: () => _removeBookmark(postId),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
