import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:innterest/screens/home_screen.dart';
import 'dart:typed_data';

class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isUploading = false;
  String? _profilePicUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final userRef = FirebaseDatabase.instance.ref('users/${widget.user.uid}');
    final snapshot = await userRef.get();

    if (snapshot.exists) {
      final userData = snapshot.value as Map;
      setState(() {
        _usernameController.text = userData['username'] ?? '';
        _fullnameController.text = userData['fullname'] ?? '';
        _addressController.text = userData['address'] ?? '';
        _profilePicUrl = userData['profilePic'];
      });
    }
  }

  Future<void> _uploadProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        // Compress the image using the file path
        final compressedImageData = await FlutterImageCompress.compressWithFile(
          pickedFile.path,
          quality: 25, // Adjust the quality as needed
        );

        if (compressedImageData != null) {
          // Reference to Firebase Storage for profile pictures
          final storageRef = FirebaseStorage.instance
              .ref('profile_pics/${widget.user.uid}.jpg');

          // Upload the compressed image data
          await storageRef.putData(Uint8List.fromList(compressedImageData));
          String downloadUrl = await storageRef.getDownloadURL();

          setState(() {
            _profilePicUrl = downloadUrl;
            _isUploading = false;
          });
        }
      } catch (e) {
        print("Error uploading profile picture: $e");
        setState(() {
          _isUploading = false;
        });
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(user: widget.user)),
        (route) => false, // Remove all previous routes
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_usernameController.text.isNotEmpty) {
      await FirebaseAuth.instance.currentUser?.updateProfile(
        displayName: _usernameController.text,
        photoURL: _profilePicUrl,
      );

      // Update user data in Realtime Database
      await FirebaseDatabase.instance.ref('users/${widget.user.uid}').update({
        'username': _usernameController.text,
        'profilePic': _profilePicUrl,
      });

      // Update album name to match the new username
      await FirebaseDatabase.instance.ref('albums/${widget.user.uid}').update({
        'albumName': '${_usernameController.text}\'s Album',
      });

      // Refresh HomeScreen data
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(user: widget.user),
        ),
        (route) => false, // Remove all previous routes
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              backgroundImage: _profilePicUrl != null
                  ? NetworkImage(_profilePicUrl!)
                  : const AssetImage('assets/images/user.png') as ImageProvider,
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadProfilePicture,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.white),
                ),
              ),
              child: const Text('Change Profile Picture',
                  style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _fullnameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Fullname',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Address',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.white),
                ),
              ),
              child: const Text('Save Changes', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
