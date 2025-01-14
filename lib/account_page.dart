import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  @override
  void initState() {
    super.initState();
    _loadBrands();
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

  void _navigateToLogScreen(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/fuel_log');
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
                    onPressed: () {
                      // Save details or perform other actions
                    },
                    child: const Text('Save Details'),
                  ),
                ],
              ),
      ),
    );
  }
}
