import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:innterest/screens/saved_posts_screen.dart';
import 'package:innterest/screens/profile_screen.dart';
import 'package:innterest/screens/home_screen.dart';
import 'dart:typed_data';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class UploadScreen extends StatefulWidget {
  final User user;

  const UploadScreen({super.key, required this.user});

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final DatabaseReference _postsRef =
      FirebaseDatabase.instance.ref().child('posts');
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  File? _image;
  String? _imageUrl;
  bool _isUploading = false;
  int _selectedIndex = 1; // Set default index to 1 for Upload

  final DatabaseReference _userRef =
      FirebaseDatabase.instance.ref().child('users'); // Referensi pengguna
  List<String> _savedPosts =
      []; // Inisialisasi list kosong untuk post yang disimpan

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) return;

    _showLoadingDialog(); // Show loading dialog

    String postId = _postsRef.push().key ?? ''; // Generate a unique post ID
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference storageRef =
        FirebaseStorage.instance.ref().child('posts').child(fileName);

    try {
      // Compress the image
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _image!.absolute.path,
        quality: 25, // Set compression quality as needed
      );

      if (compressedImage != null) {
        // Upload the compressed image to Firebase Storage
        await storageRef.putData(Uint8List.fromList(compressedImage));
        _imageUrl = await storageRef.getDownloadURL();

        // Save the post data with the generated ID in Realtime Database
        await _postsRef.child(postId).set({
          'postId': postId,
          'userId': widget.user.uid,
          'userName': widget.user.displayName ?? 'Anonymous',
          'imageUrl': _imageUrl,
          'caption': _captionController.text,
          'title': _titleController.text,
          'timestamp': ServerValue.timestamp,
          'likes': 0,
          'likedBy': {}, // Initialize to store user IDs who liked the post
          'commentsCount': 0,
          // AlbumId initialization here if needed
        });

        _captionController.clear();
        _titleController.clear();
        setState(() {
          _image = null; // Clear the image after upload
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post added successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload image.')),
      );
    } finally {
      _hideLoadingDialog(); // Hide loading dialog
      // Navigate back to the HomeScreen and clear navigation history
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(user: widget.user)),
        (route) => false, // Remove all previous routes
      );
    }
  }

// Fungsi untuk menambahkan post ke Album (menggunakan albumId)
  Future<void> _addAlbum(String postId) async {
    // Get the username from the database
    DataSnapshot userSnapshot = await _userRef.child(widget.user.uid).get();
    String username = userSnapshot.child('username').value as String? ??
        'User'; // Default to 'User' if username not found

    // Create album name using the fetched username
    String albumName = '$username\'s album';

    // Retrieve the user's current saved posts
    DataSnapshot snapshot =
        await _userRef.child(widget.user.uid).child('albumId').get();
    List<dynamic> savedPosts =
        List.from(snapshot.value as List<dynamic>? ?? []);

    if (savedPosts.contains(postId)) {
      // If the post is already saved, remove it
      savedPosts.remove(postId);
      await _userRef.child(widget.user.uid).child('albumId').set(savedPosts);
      setState(() {
        _savedPosts.remove(postId);
      });
    } else {
      // If the post is not saved, add it to the album
      savedPosts.add(postId);
      await _userRef.child(widget.user.uid).child('albumId').set(savedPosts);

      // Generate a unique albumId using push() and store album details
      String albumId =
          _userRef.child(widget.user.uid).child('albums').push().key ?? '';
      await _userRef.child(widget.user.uid).child('albums').child(albumId).set({
        'name': albumName,
        'postIds': [postId], // Initialize with the current post
      });

      setState(() {
        _savedPosts.add(postId);
      });
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
                const SizedBox(width: 20),
                const Text(
                  "Uploading ur image",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

// Fungsi untuk menambahkan Like ID (likeId)
  // Fungsi untuk menambahkan Like ID (likeId) dan tanggal like (tanggallike)
  Future<void> _addLike(String postId) async {
    final DatabaseReference _postsRef =
        FirebaseDatabase.instance.ref().child('posts');

    try {
      DataSnapshot snapshot =
          await _postsRef.child(postId).child('likedBy').get();
      Map<dynamic, dynamic> likedBy =
          Map.from(snapshot.value as Map<dynamic, dynamic>? ?? {});

      if (likedBy.containsKey(widget.user.uid)) {
        // Hapus like jika sudah ada
        likedBy.remove(widget.user.uid);
        await _postsRef.child(postId).child('likedBy').set(likedBy);
      } else {
        // Tambahkan likeId dan tanggallike
        String tanggallike =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        likedBy[widget.user.uid] = tanggallike; // Simpan UID dan tanggallike
        await _postsRef.child(postId).child('likedBy').set(likedBy);
      }

      // Update jumlah likes
      await _postsRef.child(postId).child('likes').set(likedBy.length);
    } catch (e) {
      print('Error adding like: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Upload',
          style: TextStyle(
            fontFamily: 'Lobster',
          ),
        ),
        backgroundColor: Color.fromARGB(255, 0, 0, 0),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.grey,
                              radius: 20,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              widget.user.displayName ?? 'Anonymous',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AspectRatio(
                          aspectRatio: 1,
                          child: _image != null
                              ? Image.file(
                                  _image!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Text(
                                      'No Image',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _captionController.text.isEmpty
                              ? 'No caption'
                              : _captionController.text,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(136, 47, 46, 46),
                      borderRadius:
                          BorderRadius.circular(8.0), // Sudut melengkung
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Lobster', // Gunakan font Lobster
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.transparent),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.transparent),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(136, 47, 46, 46),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      controller: _captionController,
                      decoration: const InputDecoration(
                        labelText: 'Caption',
                        labelStyle: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Lobster', // Gunakan font Lobster
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.transparent),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.transparent),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_a_photo,
                              color: Colors.white, size: 16),
                          label: const Text(
                            'PICK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _uploadImage,
                          icon: const Icon(Icons.upload,
                              color: Colors.white, size: 16),
                          label: const Text(
                            'UPLOAD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
}
