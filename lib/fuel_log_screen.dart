import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'forum_page.dart'; // Import the forum page

class FuelLogScreen extends StatefulWidget {
  const FuelLogScreen({super.key});

  @override
  FuelLogScreenState createState() => FuelLogScreenState();
}

class FuelLogScreenState extends State<FuelLogScreen> {
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _litersController = TextEditingController();
  final FocusNode _kmFocusNode = FocusNode();
  final FocusNode _litersFocusNode = FocusNode();
  final List<Map<String, double>> _logs = [];
  double _averageConsumption = 0.0;
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }

  Future<void> _checkAuthentication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      _loadVehicles(user.uid);
    }
  }

  Future<void> _loadVehicles(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['vehicles'] != null) {
        setState(() {
          _selectedVehicleId = data['vehicles'][0]['id'];
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    FocusScope.of(context).requestFocus(_kmFocusNode);
  }

  Future<void> _addLog() async {
    final double? kilometers = double.tryParse(_kmController.text);
    final double? liters = double.tryParse(_litersController.text);

    if (kilometers != null && liters != null && kilometers > 0 && liters > 0) {
      setState(() {
        _logs.add({'kilometers': kilometers, 'liters': liters});
        _calculateAverageConsumption();
      });

      _kmController.clear();
      _litersController.clear();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('logs')
            .add({
          'kilometers': kilometers,
          'liters': liters,
          'timestamp': FieldValue.serverTimestamp(),
          'vehicleId': _selectedVehicleId,
        });

        // Update average consumption in the vehicle
        await _updateAverageConsumption(user.uid);
      }
    }
  }

  void _calculateAverageConsumption() {
    if (_logs.length < 2) {
      setState(() {
        _averageConsumption = 0.0;
      });
      return;
    }

    double totalDistance = 0.0;
    double totalLiters = 0.0;

    for (int i = 1; i < _logs.length; i++) {
      final double distance = _logs[i]['kilometers']! - _logs[i - 1]['kilometers']!;
      totalDistance += distance;
      totalLiters += _logs[i]['liters']!;
    }

    setState(() {
      _averageConsumption = totalLiters / (totalDistance / 100);
    });
  }

  Future<void> _updateAverageConsumption(String userId) async {
    final logsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('logs')
        .where('vehicleId', isEqualTo: _selectedVehicleId)
        .orderBy('timestamp', descending: true)
        .get();

    if (logsSnapshot.docs.length < 2) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'vehicles': FieldValue.arrayUnion([
          {
            'id': _selectedVehicleId,
            'averageConsumption': 0.0,
          }
        ]),
      });
      setState(() {
        _averageConsumption = 0.0;
      });
      return;
    }

    double totalDistance = 0.0;
    double totalLiters = 0.0;

    for (int i = 1; i < logsSnapshot.docs.length; i++) {
      final log = logsSnapshot.docs[i].data();
      final previousLog = logsSnapshot.docs[i - 1].data();
      final double distance = log['kilometers'] - previousLog['kilometers'];
      totalDistance += distance;
      totalLiters += log['liters'];
    }

    final averageConsumption = totalLiters / (totalDistance / 100);

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userData = userDoc.data();
    if (userData != null && userData['vehicles'] != null) {
      final vehicles = List<Map<String, dynamic>>.from(userData['vehicles']);
      for (var vehicle in vehicles) {
        if (vehicle['id'] == _selectedVehicleId) {
          vehicle['averageConsumption'] = averageConsumption;
          break;
        }
      }
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'vehicles': vehicles,
      });
    }

    setState(() {
      _averageConsumption = averageConsumption;
    });
  }

  void _navigateToForumPage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ForumPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Tracker'),
        leading: IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            _navigateToForumPage(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              // Clear focus before navigating
              FocusScope.of(context).unfocus();
              Navigator.pushReplacementNamed(context, '/account');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('kmTextField'),
                    controller: _kmController,
                    keyboardType: TextInputType.number,
                    focusNode: _kmFocusNode,
                    decoration: const InputDecoration(labelText: 'Current Kilometers'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('fuelTextField'),
                    controller: _litersController,
                    keyboardType: TextInputType.number,
                    focusNode: _litersFocusNode,
                    decoration: const InputDecoration(labelText: 'Fuel Liters Purchased'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addLog,
              child: const Text('Save Log and Calculate'),
            ),
            const SizedBox(height: 16),
            Text(
              _logs.length > 1
                  ? 'Average Consumption: ${_averageConsumption.toStringAsFixed(2)} L/100km'
                  : 'Enter at least two logs to calculate average consumption.',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Divider(),
            Expanded(
              child: user != null
                  ? StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('logs')
                          .where('vehicleId', isEqualTo: _selectedVehicleId)
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text(
                            'No logs found. Please add some logs.',
                            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                          );
                        }
                        final logs = snapshot.data!.docs;
                        return ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index].data() as Map<String, dynamic>;
                            return ListTile(
                              title: Text('Kilometers: ${log['kilometers']}'),
                              subtitle: Text('Liters: ${log['liters']}'),
                            );
                          },
                        );
                      },
                    )
                  : const Text(
                      'Please log in to view your logs.',
                      style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _kmFocusNode.dispose();
    _litersFocusNode.dispose();
    _kmController.dispose();
    _litersController.dispose();
    super.dispose();
  }
}
