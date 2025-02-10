import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fuel_log_screen.dart'; // Import the fuel log screen

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final TextEditingController _textController = TextEditingController();
  String? _selectedForumId;
  String? _selectedThreadId;
  Map<String, dynamic>? _selectedThreadData;

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isNotEmpty && _selectedForumId != null && _selectedThreadId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final username = userDoc.data()?['username'] ?? 'testuser';

        await FirebaseFirestore.instance
            .collection('forums')
            .doc(_selectedForumId!)
            .collection('threads')
            .doc(_selectedThreadId!)
            .collection('posts')
            .add({
          'content': text,
          'createdBy': user.uid,
          'username': username,
          'createdAt': FieldValue.serverTimestamp(),
          'likes': 0,
        });
        _textController.clear();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text and select a forum and thread')),
      );
    }
  }

  void _navigateToFuelLogScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const FuelLogScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _createNewForum() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Forum'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                if (title.isNotEmpty && description.isNotEmpty) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                    final username = userDoc.data()?['username'] ?? 'testuser';

                    await FirebaseFirestore.instance.collection('forums').add({
                      'title': title,
                      'description': description,
                      'createdAt': FieldValue.serverTimestamp(),
                      'createdBy': username,
                    });
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNewThread() async {
    final TextEditingController titleController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Thread'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                    final username = userDoc.data()?['username'] ?? 'testuser';

                    await FirebaseFirestore.instance
                        .collection('forums')
                        .doc(_selectedForumId!)
                        .collection('threads')
                        .add({
                      'title': title,
                      'createdAt': FieldValue.serverTimestamp(),
                      'createdBy': username,
                    });
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedThreadId != null) {
          setState(() {
            _selectedThreadId = null;
            _selectedThreadData = null;
          });
          return false;
        } else if (_selectedForumId != null) {
          setState(() {
            _selectedForumId = null;
          });
          return false;
        } else {
          _navigateToFuelLogScreen(context);
          return true;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _selectedThreadData != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedThreadData!['title'] ?? 'No Title'),
                    Text(
                      _selectedThreadData!['description'] ?? 'No Description',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Created by: ${_selectedThreadData!['createdBy'] ?? 'Unknown'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                )
              : const Text('Forum'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_selectedThreadId != null) {
                setState(() {
                  _selectedThreadId = null;
                  _selectedThreadData = null;
                });
              } else if (_selectedForumId != null) {
                setState(() {
                  _selectedForumId = null;
                });
              } else {
                _navigateToFuelLogScreen(context);
              }
            },
          ),
          actions: [
            if (_selectedForumId != null && _selectedThreadId == null)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _createNewThread,
              ),
            if (_selectedForumId == null)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _createNewForum,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _selectedForumId == null
                  ? _buildForumList()
                  : _selectedThreadId == null
                      ? _buildThreadList()
                      : _buildPostList(),
            ),
            if (_selectedForumId != null && _selectedThreadId != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Enter message',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                        ),
                        onSubmitted: (value) => _sendText(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: _sendText,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForumList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('forums').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No forums found.'));
        }
        final forums = snapshot.data!.docs;
        return ListView.builder(
          itemCount: forums.length,
          itemBuilder: (context, index) {
            final forum = forums[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              elevation: 0, // Remove shadow
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: ListTile(
                title: Text(forum['title'] ?? 'No Title'),
                subtitle: Text(forum['description'] ?? 'No Description'),
                onTap: () {
                  setState(() {
                    _selectedForumId = forum.id;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThreadList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('forums')
          .doc(_selectedForumId!)
          .collection('threads')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No threads found.'));
        }
        final threads = snapshot.data!.docs;
        return ListView.builder(
          itemCount: threads.length,
          itemBuilder: (context, index) {
            final thread = threads[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              elevation: 0, // Remove shadow
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: ListTile(
                title: Text(thread['title'] ?? 'No Title'),
                onTap: () async {
                  final threadData = thread.data() as Map<String, dynamic>;
                  setState(() {
                    _selectedThreadId = thread.id;
                    _selectedThreadData = threadData;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('forums')
          .doc(_selectedForumId!)
          .collection('threads')
          .doc(_selectedThreadId!)
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No posts found.'));
        }
        final posts = snapshot.data!.docs;
        return ListView.builder(
          reverse: true,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            final username = post['username'] ?? 'testuser';
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              elevation: 0, // Remove shadow
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: ListTile(
                title: Text(post['content'] ?? 'No Content'),
                subtitle: Text(username),
              ),
            );
          },
        );
      },
    );
  }
}
