import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'comment_screen.dart';

class SearchScreen extends StatefulWidget {
  final String userId;

  const SearchScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final DatabaseReference _postsRef =
      FirebaseDatabase.instance.ref().child('posts');

  @override
  void initState() {
    super.initState();
    _loadCachedResults();
    _fetchAllPosts(); // Load all posts at start
    _searchController.addListener(() {
      _searchPosts(_searchController.text);
    });

    // Listen for Firebase updates
    _postsRef.onChildAdded.listen((event) {
      if (mounted) _fetchAllPosts();
    });
    _postsRef.onChildChanged.listen((event) {
      if (mounted) _fetchAllPosts();
    });
  }

  // Load cached search results
  Future<void> _loadCachedResults() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('search_cache');

    if (cachedData != null) {
      List<dynamic> cachedList = json.decode(cachedData);
      setState(() {
        _searchResults = cachedList.cast<Map<String, dynamic>>();
      });
    }
  }

  // Save search results to cache
  Future<void> _cacheSearchResults() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String jsonData = json.encode(_searchResults);
    await prefs.setString('search_cache', jsonData);
  }

  // Fetch all posts when screen is opened
  Future<void> _fetchAllPosts() async {
    _postsRef.once().then((snapshot) {
      if (snapshot.snapshot.value != null) {
        Map<String, dynamic> data =
            Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        setState(() {
          _searchResults = data.values
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
        _cacheSearchResults(); // Cache results
      }
    });
  }

  // Search posts by title
  Future<void> _searchPosts(String query) async {
    if (query.isEmpty) {
      _fetchAllPosts(); // Show all posts if search is empty
      return;
    }

    _postsRef
        .orderByChild('title')
        .startAt(query)
        .endAt(query + '\uf8ff')
        .once()
        .then((snapshot) {
      if (snapshot.snapshot.value != null) {
        Map<String, dynamic> data =
            Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        setState(() {
          _searchResults = data.values
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
        _cacheSearchResults();
      } else {
        setState(() {
          _searchResults.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Clear search when changing screen
  @override
  void deactivate() {
    _searchController.clear();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Posts'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        'No posts found',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final post = _searchResults[index];
                        final postId = post['postId'];

                        return ListTile(
                          title: Text(post['title'] ?? 'No title'),
                          subtitle: Text(post['caption'] ?? 'No caption'),
                          leading: Image.network(
                            post['imageUrl'] ?? '',
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CommentScreen(postId: postId),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
