import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fuel_log_screen.dart';
import 'account_page.dart'; // Import the account page

class CarDetailPage extends StatefulWidget {
  const CarDetailPage({super.key});

  @override
  State<CarDetailPage> createState() => _CarDetailPageState();
}

class _CarDetailPageState extends State<CarDetailPage> with SingleTickerProviderStateMixin {
  final TextEditingController _carYearController = TextEditingController();
  final TextEditingController _carNameController = TextEditingController();
  String? _selectedBrand;
  String? _selectedModel;
  String? _selectedEngine;
  bool _isLoading = false;
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late PageController _pageController;
  int _selectedPageIndex = 0;
  List<String> _brands = [];
  List<String> _models = [];
  List<String> _engines = [];
  List<Map<String, dynamic>> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _loadVehicles();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _pageController = PageController(initialPage: _selectedPageIndex);
  }

  @override
  void dispose() {
    _carYearController.dispose();
    _carNameController.dispose();
    _animationController.dispose();
    _pageController.dispose();
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

  Future<void> _loadEngines(String brand, String model) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('vehicleBrands')
          .doc(brand)
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

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('vehicles')
            .get();
        final List<Map<String, dynamic>> vehicles = querySnapshot.docs.map((doc) => doc.data()).toList();
        setState(() {
          _vehicles = vehicles;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading vehicles: $e')),
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
    final carName = _carNameController.text.trim();

    if (_selectedBrand == null || _selectedModel == null || _selectedEngine == null || carYear.isEmpty || carName.isEmpty) {
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
          'name': carName,
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

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('vehicles')
            .add(newVehicle);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Clear the controllers after saving the details
          _carYearController.clear();
          _carNameController.clear();
          setState(() {
            _selectedBrand = null;
            _selectedModel = null;
            _selectedEngine = null;
            _vehicles.add(newVehicle);
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

  void _navigateToPage(int pageIndex) {
    setState(() {
      _selectedPageIndex = pageIndex;
    });
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _onMenuSelected(String value) {
    setState(() {
      _isMenuOpen = false;
    });
    if (value == 'Account') {
      _navigateToPage(1);
    } else if (value == 'Car Details') {
      _navigateToPage(0);
    }
  }

  void _showAddCarDialog() {
    String? tempSelectedBrand;
    String? tempSelectedModel;
    String? tempSelectedEngine;
    List<String> tempModels = [];
    List<String> tempEngines = [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Car'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.8, // Make the dialog wider
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _carNameController,
                      decoration: const InputDecoration(labelText: 'Vehicle Name'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: tempSelectedBrand,
                      hint: const Text('Select Brand'),
                      items: _brands.map((String brand) {
                        return DropdownMenuItem<String>(
                          value: brand,
                          child: Text(brand),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          tempSelectedBrand = newValue;
                          tempModels = [];
                          tempEngines = [];
                          tempSelectedModel = null;
                          tempSelectedEngine = null;
                        });
                        if (newValue != null) {
                          _loadModels(newValue).then((_) {
                            setState(() {
                              tempModels = _models;
                            });
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: tempSelectedModel,
                      hint: const Text('Select Model'),
                      items: tempModels.map((String model) {
                        return DropdownMenuItem<String>(
                          value: model,
                          child: Text(model),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          tempSelectedModel = newValue;
                          tempEngines = [];
                          tempSelectedEngine = null;
                        });
                        if (newValue != null && tempSelectedBrand != null) {
                          _loadEngines(tempSelectedBrand!, newValue).then((_) {
                            setState(() {
                              tempEngines = _engines;
                            });
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: tempSelectedEngine,
                      hint: const Text('Select Engine'),
                      items: tempEngines.map((String engine) {
                        return DropdownMenuItem<String>(
                          value: engine,
                          child: Text(engine),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          tempSelectedEngine = newValue;
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
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  tempSelectedBrand = null;
                  tempSelectedModel = null;
                  tempSelectedEngine = null;
                });
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedBrand = tempSelectedBrand;
                  _selectedModel = tempSelectedModel;
                  _selectedEngine = tempSelectedEngine;
                });
                _saveVehicle();
                Navigator.pop(context);
              },
              child: const Text('Save Vehicle'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _navigateToLogScreen(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _navigateToPage(0),
                child: Text(
                  'Car Details',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedPageIndex == 0 ? Colors.black : Colors.grey[700],
                    fontWeight: _selectedPageIndex == 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _navigateToPage(1),
                child: Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedPageIndex == 1 ? Colors.black : Colors.grey[700],
                    fontWeight: _selectedPageIndex == 1 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
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
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildCarDetailsPage(),
            const AccountPage(), // Use the AccountPage widget
          ],
        ),
      ),
    );
  }

  Widget _buildCarDetailsPage() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: ElevatedButton(
                  onPressed: _showAddCarDialog,
                  child: const Text('Add New Car'),
                ),
              ),
              const SizedBox(height: 16),
              if (_vehicles.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = _vehicles[index];
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                vehicle['name'] ?? 'Vehicle Details:',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Brand: ${vehicle['carBrand']}', style: const TextStyle(fontSize: 18)),
                              Text('Model: ${vehicle['carModel']}', style: const TextStyle(fontSize: 18)),
                              Text('Engine: ${vehicle['engineType']}', style: const TextStyle(fontSize: 18)),
                              Text('Year: ${vehicle['carYear']}', style: const TextStyle(fontSize: 18)),
                              Text('Average Consumption: ${vehicle['averageConsumption']} L/100km', style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_isMenuOpen)
          FadeTransition(
            opacity: _opacityAnimation,
            child: ModalBarrier(
              dismissible: true,
              color: Colors.black54,
              onDismiss: () {
                _toggleMenu();
              },
            ),
          ),
        if (_isMenuOpen)
          Center(
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      _onMenuSelected('Car Details');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.white,
                      child: const Text('Car Details', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _onMenuSelected('Account');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.white,
                      child: const Text('Account', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
