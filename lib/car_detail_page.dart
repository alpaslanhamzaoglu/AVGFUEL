import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fuel_log_screen.dart'; 

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
  Map<String, dynamic>? _vehicle;

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _loadVehicle();
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
      final querySnapshot = await FirebaseFirestore.instance.collection('vehicleBrands').get();
      final List<String> brands = querySnapshot.docs.map((doc) => doc.id).toList();
      setState(() {
        _brands = brands;
      });
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
      final querySnapshot = await FirebaseFirestore.instance
          .collection('vehicleBrands')
          .doc(brand)
          .collection('models')
          .get();
      final List<String> models = querySnapshot.docs.map((doc) => doc.id).toList();
      setState(() {
        _models = models;
      });
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
      final querySnapshot = await FirebaseFirestore.instance
          .collection('vehicleBrands')
          .doc(_selectedBrand)
          .collection('models')
          .doc(model)
          .collection('engines')
          .get();
      final List<String> engines = querySnapshot.docs.map((doc) => doc['name'] as String).toList();
      setState(() {
        _engines = engines;
      });
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

  Future<void> _loadVehicle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['vehicle'] != null) {
            setState(() {
              _vehicle = data['vehicle'];
              _carYearController.text = _vehicle!['carYear'].toString();
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading vehicle: $e')),
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

  Future<void> _saveVehicle() async {
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
        final newVehicle = {
          'carBrand': _selectedBrand,
          'carModel': _selectedModel,
          'carYear': int.parse(carYear),
          'engineType': _selectedEngine,
          'averageConsumption': 0.0, // Initialize average consumption
          'lastMaintenance': '',
          'nextMaintenance': '',
          'yearlyTax': 0.0,
          'insurance': 0.0,
          'mandatoryInsurance': 0.0,
        };

        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'vehicle': newVehicle,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Clear the controllers after saving the details
          _carYearController.clear();
          setState(() {
            _selectedBrand = null;
            _selectedModel = null;
            _selectedEngine = null;
            _vehicle = newVehicle;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving vehicle: $e'),
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
    FocusScope.of(context).unfocus();
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
        title: const Text('Car Details'),
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
                    onPressed: _saveVehicle,
                    child: const Text('Save Vehicle'),
                  ),
                  const SizedBox(height: 24),
                  if (_vehicle != null)
                    Expanded(
                      child: Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vehicle Details:',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Brand: ${_vehicle!['carBrand']}', style: const TextStyle(fontSize: 18)),
                              Text('Model: ${_vehicle!['carModel']}', style: const TextStyle(fontSize: 18)),
                              Text('Engine: ${_vehicle!['engineType']}', style: const TextStyle(fontSize: 18)),
                              Text('Year: ${_vehicle!['carYear']}', style: const TextStyle(fontSize: 18)),
                              Text('Average Consumption: ${_vehicle!['averageConsumption']} L/100km', style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
