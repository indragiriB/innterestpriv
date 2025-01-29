import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_screen.dart';

class MessageScreen extends StatefulWidget {
  final User currentUser;

  const MessageScreen({required this.currentUser, Key? key}) : super(key: key);

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref(); // Realtime Database
  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final currentUserUid = widget.currentUser.uid;

    final snapshot = await _databaseRef.child('users').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      setState(() {
        users = data.entries
            .where((entry) => entry.key != currentUserUid)
            .map((entry) => {
                  'uid': entry.key,
                  'name': entry.value['fullname'] ?? 'Unknown',
                  'email': entry.value['email'] ?? '',
                })
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: users.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 75, 75, 75),
              ),
            )
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 30, // Membuat profile picture lebih besar
                      backgroundColor: const Color.fromARGB(255, 93, 93, 93),
                      child: Text(
                        user['name'][0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24, // Font lebih besar
                          fontFamily: 'Lobster',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      user['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      user['email'],
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            currentUser: widget.currentUser,
                            chatUser: user,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
