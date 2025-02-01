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
  final TextEditingController _lastMaintenanceController = TextEditingController();
  final TextEditingController _nextMaintenanceController = TextEditingController();
  final TextEditingController _yearlyTaxController = TextEditingController();
  final TextEditingController _insuranceController = TextEditingController();
  final TextEditingController _mandatoryInsuranceController = TextEditingController();
  final FocusNode _kmFocusNode = FocusNode();
  final FocusNode _litersFocusNode = FocusNode();
  final FocusNode _lastMaintenanceFocusNode = FocusNode();
  final FocusNode _nextMaintenanceFocusNode = FocusNode();
  final FocusNode _yearlyTaxFocusNode = FocusNode();
  final FocusNode _insuranceFocusNode = FocusNode();
  final FocusNode _mandatoryInsuranceFocusNode = FocusNode();
  final List<Map<String, double>> _logs = [];
  double _averageConsumption = 0.0;
  String? _selectedVehicleId;
  bool _switchValue = false;
  final PageController _pageController = PageController();

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
      _loadVehicle(user.uid);
    }
  }

  Future<void> _loadVehicle(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['vehicle'] != null) {
        setState(() {
          _selectedVehicleId = data['vehicle']['id'];
          _averageConsumption = data['vehicle']['averageConsumption'];
          _lastMaintenanceController.text = data['vehicle']['lastMaintenance'] ?? '';
          _nextMaintenanceController.text = data['vehicle']['nextMaintenance'] ?? '';
          _yearlyTaxController.text = data['vehicle']['yearlyTax']?.toString() ?? '';
          _insuranceController.text = data['vehicle']['insurance']?.toString() ?? '';
          _mandatoryInsuranceController.text = data['vehicle']['mandatoryInsurance']?.toString() ?? '';
        });
      }
    }
  }

  Future<void> _updateVehicleDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FocusScope.of(context).unfocus();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'vehicle.lastMaintenance': _lastMaintenanceController.text,
        'vehicle.nextMaintenance': _nextMaintenanceController.text,
        'vehicle.yearlyTax': double.tryParse(_yearlyTaxController.text) ?? 0.0,
        'vehicle.insurance': double.tryParse(_insuranceController.text) ?? 0.0,
        'vehicle.mandatoryInsurance': double.tryParse(_mandatoryInsuranceController.text) ?? 0.0,
        // Add any other “vehicle.” fields if needed, matching the account page.
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Details updated successfully!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Remove or comment out direct focus calls:
    // FocusScope.of(context).requestFocus(_kmFocusNode);
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
      final double distance = (_logs[i]['kilometers']! - _logs[i - 1]['kilometers']!).abs();
      totalDistance += distance;
      totalLiters += _logs[i]['liters']!;
    }

    setState(() {
      _averageConsumption = (totalLiters / totalDistance) * 100;
    });
  }

  Future<void> _updateAverageConsumption(String userId) async {
    final logsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('logs')
        .where('vehicleId', isEqualTo: _selectedVehicleId)
        .orderBy('timestamp')
        .get();

    if (logsSnapshot.docs.length < 2) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'vehicle.averageConsumption': 0.0,
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
      final double distance = (log['kilometers'] - previousLog['kilometers']).abs();
      totalDistance += distance;
      totalLiters += log['liters'];
    }

    final averageConsumption = (totalLiters / totalDistance) * 100;

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'vehicle.averageConsumption': averageConsumption,
    });

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

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != DateTime.now()) {
      setState(() {
        controller.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Car Details', style: TextStyle(fontSize: 16)),
            Switch(
              value: _switchValue,
              onChanged: (value) {
                setState(() {
                  _switchValue = value;
                  _pageController.animateToPage(
                    value ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                });
              },
            ),
            const Text('Fuel Tracker', style: TextStyle(fontSize: 16)),
          ],
        ),
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
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildCarDetailsPage(),
          _buildFuelLogPage(user),
        ],
      ),
    );
  }

  Widget _buildCarDetailsPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildEditableField(
            label: 'Last Maintenance',
            controller: _lastMaintenanceController,
            onTap: () => _selectDate(context, _lastMaintenanceController),
          ),
          const SizedBox(height: 8),
          _buildEditableField(
            label: 'Next Maintenance',
            controller: _nextMaintenanceController,
            onTap: () => _selectDate(context, _nextMaintenanceController),
          ),
          const SizedBox(height: 8),
          _buildEditableField(
            label: 'Yearly Tax',
            controller: _yearlyTaxController,
          ),
          const SizedBox(height: 8),
          _buildEditableField(
            label: 'Insurance',
            controller: _insuranceController,
          ),
          const SizedBox(height: 8),
          _buildEditableField(
            label: 'Mandatory Insurance',
            controller: _mandatoryInsuranceController,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _updateVehicleDetails,
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        onTap: onTap,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _buildFuelLogPage(User? user) {
    return Padding(
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
                : 'Average Consumption: ${_averageConsumption.toStringAsFixed(2)} L/100km',
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
    );
  }

  @override
  void dispose() {
    _kmFocusNode.dispose();
    _litersFocusNode.dispose();
    _lastMaintenanceFocusNode.dispose();
    _nextMaintenanceFocusNode.dispose();
    _yearlyTaxFocusNode.dispose();
    _insuranceFocusNode.dispose();
    _mandatoryInsuranceFocusNode.dispose();
    _kmController.dispose();
    _litersController.dispose();
    _lastMaintenanceController.dispose();
    _nextMaintenanceController.dispose();
    _yearlyTaxController.dispose();
    _insuranceController.dispose();
    _mandatoryInsuranceController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
