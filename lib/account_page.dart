import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fuel_log_screen.dart'; // Import the FuelLogScreen

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final TextEditingController _carYearController = TextEditingController();
  String? _selectedBrand;
  String? _selectedModel;
  String? _selectedEngine;
  bool _isLoading = false;
  List<String> _brands = [];
  List<String> _models = [];
  List<String> _engines = [];
  Map<String, dynamic>? _carDetails;

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _loadCarDetails();
  }

  @override
  void dispose() {
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

  Future<void> _loadCarDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            setState(() {
              _carDetails = data;
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading car details: $e')),
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

  Future<void> _saveCarDetails() async {
    final carYear = _carYearController.text.trim();

    if (_selectedBrand == null || _selectedModel == null || _selectedEngine == null || carYear.isEmpty) {
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
          'carBrand': _selectedBrand,
          'carModel': _selectedModel,
          'carYear': DateTime(int.parse(carYear)),
          'engineType': _selectedEngine,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Car details saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Clear the controllers after saving the details
          _carYearController.clear();
          setState(() {
            _selectedBrand = null;
            _selectedModel = null;
            _selectedEngine = null;
            _carDetails = {
              'carBrand': _selectedBrand,
              'carModel': _selectedModel,
              'carYear': DateTime(int.parse(carYear)),
              'engineType': _selectedEngine,
            };
          });
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

  void _navigateToLogScreen(BuildContext context) {
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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _navigateToLogScreen(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
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
                    onPressed: _saveCarDetails,
                    child: const Text('Save Details'),
                  ),
                  const SizedBox(height: 24),
                  if (_carDetails != null)
                    Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Car Details:',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('Brand: ${_carDetails!['carBrand']}', style: const TextStyle(fontSize: 18)),
                            Text('Model: ${_carDetails!['carModel']}', style: const TextStyle(fontSize: 18)),
                            Text('Engine: ${_carDetails!['engineType']}', style: const TextStyle(fontSize: 18)),
                            Text('Year: ${(_carDetails!['carYear'] is Timestamp) ? (_carDetails!['carYear'] as Timestamp).toDate().year : _carDetails!['carYear']}', style: const TextStyle(fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
