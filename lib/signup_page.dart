import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _carYearController = TextEditingController();
  String? _selectedBrand;
  String? _selectedModel;
  String? _selectedEngine;
  bool _isLoading = false;
  List<String> _brands = [];
  List<String> _models = [];
  List<String> _engines = [];

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _carYearController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8081/brands'));
      if (response.statusCode == 200) {
        final List<dynamic> brands = json.decode(response.body);
        setState(() {
          _brands = brands.cast<String>();
        });
      } else {
        throw Exception('Failed to load brands');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading brands: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadModels(String brand) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8081/models?brand=$brand'));
      if (response.statusCode == 200) {
        final List<dynamic> models = json.decode(response.body);
        setState(() {
          _models = models.cast<String>();
        });
      } else {
        throw Exception('Failed to load models');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading models: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEngines(String model) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8081/engines?model=$model'));
      if (response.statusCode == 200) {
        final List<dynamic> engines = json.decode(response.body);
        setState(() {
          _engines = engines.cast<String>();
        });
      } else {
        throw Exception('Failed to load engines');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading engines: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectYear(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: YearPicker(
            firstDate: DateTime(1900),
            lastDate: now,
            initialDate: now,
            selectedDate: now,
            onChanged: (DateTime dateTime) {
              Navigator.pop(context, dateTime);
            },
          ),
        );
      },
    );
    if (picked != null && picked.year.toString() != _carYearController.text) {
      setState(() {
        _carYearController.text = picked.year.toString();
      });
    }
  }

  Future<void> _signUp() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final carYear = _carYearController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty || _selectedBrand == null || _selectedModel == null || _selectedEngine == null || carYear.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create user in Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Save user details to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .set({
        'username': username,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'carBrand': _selectedBrand,
        'carModel': _selectedModel,
        'carYear': DateTime(int.parse(carYear)),
        'engineType': _selectedEngine,
      });

      // Create an empty document in the logs subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .collection('logs')
          .add({
        'kilometers': 0,
        'liters': 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Sign-up failed'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBrand,
              hint: const Text('Select Brand'),
              items: _brands.map((String brand) {
                return DropdownMenuItem<String>(
                  value: brand,
                  child: Text(brand),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedBrand = newValue;
                  _models = [];
                  _engines = [];
                  _selectedModel = null;
                  _selectedEngine = null;
                });
                if (newValue != null) {
                  _loadModels(newValue);
                }
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              hint: const Text('Select Model'),
              items: _models.map((String model) {
                return DropdownMenuItem<String>(
                  value: model,
                  child: Text(model),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedModel = newValue;
                  _engines = [];
                  _selectedEngine = null;
                });
                if (newValue != null) {
                  _loadEngines(newValue);
                }
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedEngine,
              hint: const Text('Select Engine'),
              items: _engines.map((String engine) {
                return DropdownMenuItem<String>(
                  value: engine,
                  child: Text(engine),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedEngine = newValue;
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _carYearController,
              readOnly: true,
              onTap: () => _selectYear(context),
              decoration: const InputDecoration(labelText: 'Year of Manufacture'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Sign Up'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
