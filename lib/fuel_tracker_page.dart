import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FuelTrackerPage extends StatefulWidget {
  final User? user;

  const FuelTrackerPage({super.key, required this.user});

  @override
  State<FuelTrackerPage> createState() => _FuelTrackerPageState();
}

class _FuelTrackerPageState extends State<FuelTrackerPage> {
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _litersController = TextEditingController();
  final FocusNode _kmFocusNode = FocusNode();
  final FocusNode _litersFocusNode = FocusNode();
  String? _selectedVehicleId;
  Map<String, dynamic>? _selectedVehicle;
  List<Map<String, dynamic>> _vehicles = [];
  DocumentSnapshot? _selectedLog1;
  DocumentSnapshot? _selectedLog2;
  double? _calculatedAverageConsumption;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVehicles();
    });
  }

  Future<void> _loadVehicles() async {
    final user = widget.user;
    if (user != null) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .get();
      final List<Map<String, dynamic>> vehicles = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      setState(() {
        _vehicles = vehicles;
        if (_vehicles.isNotEmpty) {
          _selectedVehicle = _vehicles[0];
          _selectedVehicleId = _selectedVehicle!['id'];
        }
      });
    }
  }

  Future<void> _addLog() async {
    final double? kilometers = double.tryParse(_kmController.text);
    final double? liters = double.tryParse(_litersController.text);

    if (kilometers != null && liters != null && kilometers > 0 && liters > 0) {
      final user = widget.user;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('vehicles')
            .doc(_selectedVehicleId)
            .collection('logs')
            .add({
          'kilometers': kilometers,
          'liters': liters,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update average consumption in the vehicle
        await _updateAverageConsumption(user.uid);
      }

      _kmController.clear();
      _litersController.clear();
    }
  }

  Future<void> _updateAverageConsumption(String userId) async {
    try {
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .doc(_selectedVehicleId)
          .collection('logs')
          .orderBy('timestamp')
          .get();

      if (logsSnapshot.docs.length < 2) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('vehicles')
            .doc(_selectedVehicleId)
            .update({
          'averageConsumption': 0.0,
        });
        return;
      }

      double totalDistance = 0.0;
      double totalLiters = 0.0;

      for (int i = 1; i < logsSnapshot.docs.length; i++) {
        final log = logsSnapshot.docs[i].data();
        final previousLog = logsSnapshot.docs[i - 1].data();
        final double distance = (log['kilometers'] - previousLog['kilometers']).abs();
        totalDistance += distance;
        totalLiters += log['liters'];
      }

      final averageConsumption = (totalLiters / totalDistance) * 100;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .doc(_selectedVehicleId)
          .update({
        'averageConsumption': averageConsumption,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firestore index is required. Please create the index in the Firebase console.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        rethrow;
      }
    }
  }

  void _calculateSelectedLogsAverage() {
    if (_selectedLog1 != null && _selectedLog2 != null) {
      final log1 = _selectedLog1!.data() as Map<String, dynamic>;
      final log2 = _selectedLog2!.data() as Map<String, dynamic>;

      final double distance = (log1['kilometers'] - log2['kilometers']).abs();
      final double liters = log1['liters'] + log2['liters'];

      setState(() {
        _calculatedAverageConsumption = (liters / distance) * 100;
      });
    } else {
      setState(() {
        _calculatedAverageConsumption = null;
      });
    }
  }

  void _toggleLogSelection(DocumentSnapshot log) {
    setState(() {
      if (_selectedLog1 == log) {
        _selectedLog1 = null;
      } else if (_selectedLog2 == log) {
        _selectedLog2 = null;
      } else if (_selectedLog1 == null) {
        _selectedLog1 = log;
      } else if (_selectedLog2 == null) {
        _selectedLog2 = log;
      } else {
        _selectedLog1 = log;
        _selectedLog2 = null;
      }
      _calculateSelectedLogsAverage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 120, // Adjust the width as needed
                child: Text('Selected Car:', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.0),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      value: _selectedVehicle,
                      onChanged: (Map<String, dynamic>? newValue) {
                        setState(() {
                          _selectedVehicle = newValue;
                          _selectedVehicleId = newValue!['id'];
                        });
                      },
                      items: _vehicles.map<DropdownMenuItem<Map<String, dynamic>>>((Map<String, dynamic> vehicle) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: vehicle,
                          child: Text(vehicle['name'] ?? vehicle['carBrand']),
                        );
                      }).toList(),
                      dropdownColor: Colors.white,
                      isExpanded: true,
                      itemHeight: 48,
                      menuMaxHeight: 300,
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .collection('vehicles')
                .doc(_selectedVehicleId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Text(
                  'No data found.',
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                );
              }
              final vehicleData = snapshot.data!.data() as Map<String, dynamic>;
              final averageConsumption = vehicleData['averageConsumption'] ?? 0.0;
              return Text(
                'Average Consumption: ${averageConsumption.toStringAsFixed(2)} L/100km',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              );
            },
          ),
          if (_calculatedAverageConsumption != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Selected Logs Average Consumption: ${_calculatedAverageConsumption!.toStringAsFixed(2)} L/100km',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          const Divider(),
          Expanded(
            child: user != null
                ? StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('vehicles')
                        .doc(_selectedVehicleId)
                        .collection('logs')
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
                          final log = logs[index];
                          final logData = log.data() as Map<String, dynamic>;
                          final isSelected = log == _selectedLog1 || log == _selectedLog2;
                          return GestureDetector(
                            onTap: () => _toggleLogSelection(log),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.withAlpha(51) : Colors.transparent, // 51 is 20% opacity
                                borderRadius: BorderRadius.circular(12.0),
                                border: isSelected ? Border.all(color: Colors.blue, width: 2.0) : null,
                              ),
                              child: ListTile(
                                title: Text('Kilometers: ${logData['kilometers']}'),
                                subtitle: Text('Liters: ${logData['liters']}'),
                              ),
                            ),
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