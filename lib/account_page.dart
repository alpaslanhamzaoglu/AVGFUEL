import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final TextEditingController _carModelController = TextEditingController();
  final TextEditingController _carYearController = TextEditingController();
  final TextEditingController _engineTypeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCarDetails();
  }

  @override
  void dispose() {
    _carModelController.dispose();
    _carYearController.dispose();
    _engineTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadCarDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          if (mounted) {
            setState(() {
              // Remove the code that sets the TextEditingController values from the database
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading car details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveCarDetails() async {
    final carModel = _carModelController.text.trim();
    final carYear = _carYearController.text.trim();
    final engineType = _engineTypeController.text.trim();

    if (carModel.isEmpty || carYear.isEmpty || engineType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All fields are required!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'carModel': carModel,
          'carYear': carYear,
          'engineType': engineType,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Car details saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Clear the controllers after saving the details
          _carModelController.clear();
          _carYearController.clear();
          _engineTypeController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving car details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/fuel_log');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _carModelController,
                      decoration: const InputDecoration(labelText: 'Car Model'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _carYearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Year of Manufacture'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _engineTypeController,
                      decoration: const InputDecoration(labelText: 'Engine Type'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveCarDetails,
                      child: const Text('Save Details'),
                    ),
                    const SizedBox(height: 24),
                    if (user != null)
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const Text(
                              'No car details found. Please enter your car details.',
                              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                            );
                          }
                          final carDetails = snapshot.data!.data() as Map<String, dynamic>;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Car Details:',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Model: ${carDetails['carModel']}', style: const TextStyle(fontSize: 16)),
                              Text('Year: ${carDetails['carYear']}', style: const TextStyle(fontSize: 16)),
                              Text('Engine: ${carDetails['engineType']}', style: const TextStyle(fontSize: 16)),
                            ],
                          );
                        },
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
