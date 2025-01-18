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
        });
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Tracker'),
        leading: IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            Navigator.pushNamed(context, '/forum_page');
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
