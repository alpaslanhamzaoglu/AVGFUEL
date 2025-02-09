import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String _username = '';
  String _email = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userData.exists) {
          final data = userData.data();
          if (data != null) {
            setState(() {
              _username = data['username'] ?? '';
              _email = data['email'] ?? '';
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserData(String username, String email, String password) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Re-authenticate the user with their current credentials
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password, // The current password is required
        );
        await user.reauthenticateWithCredential(credential);

        // Send email verification to the new email address
        await user.verifyBeforeUpdateEmail(email);

        // Update user information in Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'username': username,
          'email': email,
        });

        setState(() {
          _username = username;
          _email = email;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User data updated successfully! Please verify your new email address.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'requires-recent-login':
          errorMessage = 'You need to log in again before updating your email.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'This operation is not allowed. Check your Firebase settings.';
          break;
        case 'email-already-in-use':
          errorMessage = 'The email address is already in use by another account.';
          break;
        default:
          errorMessage = 'An error occurred. Please try again. Error code: ${e.code}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user data: $errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending password reset email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditDialog() {
    final TextEditingController usernameController = TextEditingController(text: _username);
    final TextEditingController emailController = TextEditingController(text: _email);
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit User Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Current Password'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _resetPassword,
                child: const Text('Reset Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                usernameController.dispose();
                emailController.dispose();
                passwordController.dispose();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _updateUserData(
                  usernameController.text.trim(),
                  emailController.text.trim(),
                  passwordController.text.trim(),
                );
                Navigator.pop(context);
                usernameController.dispose();
                emailController.dispose();
                passwordController.dispose();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              Center(
                child: ElevatedButton(
                  onPressed: _showEditDialog,
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Username: $_username',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Email: $_email',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
