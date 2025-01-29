import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final User currentUser;
  final Map<String, dynamic> chatUser;

  const ChatScreen({
    Key? key,
    required this.currentUser,
    required this.chatUser,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _messageController = TextEditingController();
  final _databaseRef = FirebaseDatabase.instance.ref();
  final _storage = FirebaseStorage.instance;
  late String chatPath;
  bool _isUploading = false;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    super.initState();
    chatPath = _getChatPath(widget.currentUser.uid, widget.chatUser['uid']);
    _updateOnlineStatus(true);
    _messageController.addListener(() {
      _updateTypingStatus(_messageController.text.isNotEmpty);
    });
    _markMessagesAsSeen();
    _loadCachedMessages(); // Load cached messages on init
  }

  @override
  void dispose() {
    _updateOnlineStatus(false);
    _scrollController.dispose(); // Dispose ScrollController
    super.dispose();
  }

  String _getChatPath(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '$uid1-$uid2' : '$uid2-$uid1';
  }

  void _updateOnlineStatus(bool isOnline) {
    _databaseRef.child('users/${widget.currentUser.uid}/online').set(isOnline);
  }

  void _updateTypingStatus(bool isTyping) {
    _databaseRef
        .child('chats/$chatPath/typing/${widget.currentUser.uid}')
        .set(isTyping);
  }

  Future<void> _markMessagesAsSeen() async {
    final snapshot = await _databaseRef.child('$chatPath/messages').get();
    if (snapshot.exists) {
      final messages = snapshot.value as Map;
      for (var entry in messages.entries) {
        final message = entry.value as Map;
        if (message['senderUid'] != widget.currentUser.uid &&
            message['isSeen'] == false) {
          _databaseRef
              .child('$chatPath/messages/${entry.key}/isSeen')
              .set(true);
        }
      }
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty && imageUrl == null) return;

    final newMessageRef = _databaseRef.child('$chatPath/messages').push();
    await newMessageRef.set({
      'senderUid': widget.currentUser.uid,
      'message': imageUrl == null ? messageText : null,
      'imageUrl': imageUrl,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isSeen': false,
    });

    _messageController.clear();
    _cacheMessage({
      'senderUid': widget.currentUser.uid,
      'message': imageUrl == null ? messageText : null,
      'imageUrl': imageUrl,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isSeen': false,
    });
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final confirmation = await _showConfirmationDialog(File(pickedFile.path));

      if (confirmation) {
        setState(() {
          _isLoading = true;
        });

        final file = File(pickedFile.path);

        final result = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          minWidth: 800,
          minHeight: 800,
          quality: 30,
        );

        if (result != null) {
          final compressedFile =
              File('${file.parent.path}/compressed_image.jpg');
          compressedFile.writeAsBytesSync(result);

          final storageRef = _storage.ref().child(
              'chat_images/${DateTime.now().millisecondsSinceEpoch}_${widget.currentUser.uid}.jpg');
          final uploadTask = storageRef.putFile(compressedFile);

          uploadTask.snapshotEvents.listen((taskSnapshot) {
            // Handle upload progress here if needed (e.g. showing progress)
          }, onError: (error) {
            setState(() {
              _isLoading = false;
            });
          });

          final snapshot = await uploadTask.whenComplete(() => null);
          final imageUrl = await snapshot.ref.getDownloadURL();

          await _sendMessage(imageUrl: imageUrl);

          setState(() {
            _isLoading = false;
          });
        } else {
          _showSnackbar('Image compression failed.');
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        _showSnackbar('Image upload canceled.');
      }
    } else {
      _showSnackbar('No image selected.');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _showConfirmationDialog(File imageFile) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Image Upload'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(
                imageFile,
                height: 250,
                width: 250,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 10),
              const Text('Do you want to send this image?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isCurrentUser = msg['senderUid'] == widget.currentUser.uid;

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
        child: Column(
          crossAxisAlignment:
              isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg['imageUrl'] != null)
              Container(
                padding: const EdgeInsets.all(5.0),
                child: GestureDetector(
                  onTap: () {
                    _showFullImageDialog(msg['imageUrl']);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      msg['imageUrl'],
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            if (msg['message'] != null)
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.blue : Colors.grey[800],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  msg['message'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            if (isCurrentUser)
              Icon(
                msg['isSeen'] ? Icons.done_all : Icons.done,
                size: 17,
                color: msg['isSeen'] ? Colors.blue : Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  void _showFullImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadCachedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedMessages = prefs.getStringList('cached_messages') ?? [];

    // Display cached messages
    for (var cachedMessage in cachedMessages) {
      // You can parse cachedMessage and display it in your UI if needed
    }
  }

  Future<void> _cacheMessage(Map<String, dynamic> message) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedMessages = prefs.getStringList('cached_messages') ?? [];
    cachedMessages.add(message.toString()); // Add the message as a string
    await prefs.setStringList('cached_messages', cachedMessages);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Call super to maintain state
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              widget.chatUser['name'],
              style: TextStyle(
                fontFamily: 'Lobster',
              ),
            ),
            StreamBuilder(
              stream: _databaseRef
                  .child('users/${widget.chatUser['uid']}/online')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.hasData &&
                    (snapshot.data! as DatabaseEvent).snapshot.value == true) {
                  return const Text(
                    ' (Online)',
                    style: TextStyle(fontSize: 18, color: Colors.green),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _databaseRef.child('$chatPath/messages').onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  final data =
                      snapshot.data!.snapshot.value as Map<Object?, Object?>;

                  final messages = data.map((key, value) {
                    return MapEntry(
                        key as String, Map<String, dynamic>.from(value as Map));
                  });

                  final sortedKeys = messages.keys.toList()
                    ..sort((a, b) =>
                        messages[b]?['timestamp'] - messages[a]?['timestamp']);

                  return ListView.builder(
                    reverse: true, // Pesan terbaru di bawah
                    controller: _scrollController,
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      final message = messages[sortedKeys[index]]!;
                      return _buildMessageBubble(message);
                    },
                  );
                }

                return const Center(child: Text('No messages yet.'));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _isUploading ? null : _pickAndUploadImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
