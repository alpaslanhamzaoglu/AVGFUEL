import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final TextEditingController _lastMaintenanceController = TextEditingController();
  final TextEditingController _nextMaintenanceController = TextEditingController();
  final TextEditingController _yearlyTaxController = TextEditingController();
  final TextEditingController _insuranceController = TextEditingController();
  final TextEditingController _mandatoryInsuranceController = TextEditingController();
  String? _selectedVehicleId;
  Map<String, dynamic>? _selectedVehicle;
  List<Map<String, dynamic>> _vehicles = [];
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVehicles();
    });
  }

  Future<void> _loadVehicles() async {
    final user = FirebaseAuth.instance.currentUser;
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
          _lastMaintenanceController.text = _selectedVehicle!['lastMaintenance'] ?? '';
          _nextMaintenanceController.text = _selectedVehicle!['nextMaintenance'] ?? '';
          _yearlyTaxController.text = _selectedVehicle!['yearlyTax']?.toString() ?? '';
          _insuranceController.text = _selectedVehicle!['insurance']?.toString() ?? '';
          _mandatoryInsuranceController.text = _selectedVehicle!['mandatoryInsurance']?.toString() ?? '';
        }
      });
    }
  }

  Future<void> _updateVehicleDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _selectedVehicleId != null) {
      FocusScope.of(context).unfocus();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .doc(_selectedVehicleId)
          .update({
        'lastMaintenance': _lastMaintenanceController.text,
        'nextMaintenance': _nextMaintenanceController.text,
        'yearlyTax': double.tryParse(_yearlyTaxController.text) ?? 0.0,
        'insurance': double.tryParse(_insuranceController.text) ?? 0.0,
        'mandatoryInsurance': double.tryParse(_mandatoryInsuranceController.text) ?? 0.0,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Details updated successfully!'), backgroundColor: Colors.green),
      );
      setState(() {
        _isEditing = false;
      });
    }
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

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Vehicle Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _updateVehicleDetails();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
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
                          _lastMaintenanceController.text = newValue['lastMaintenance'] ?? '';
                          _nextMaintenanceController.text = newValue['nextMaintenance'] ?? '';
                          _yearlyTaxController.text = newValue['yearlyTax']?.toString() ?? '';
                          _insuranceController.text = newValue['insurance']?.toString() ?? '';
                          _mandatoryInsuranceController.text = newValue['mandatoryInsurance']?.toString() ?? '';
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
          if (!_isEditing)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last Maintenance: ${_lastMaintenanceController.text}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text('Next Maintenance: ${_nextMaintenanceController.text}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text('Yearly Tax: ${_yearlyTaxController.text}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text('Insurance: ${_insuranceController.text}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text('Mandatory Insurance: ${_mandatoryInsuranceController.text}', style: const TextStyle(fontSize: 18)),
              ],
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showUpdateDialog,
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _lastMaintenanceController.dispose();
    _nextMaintenanceController.dispose();
    _yearlyTaxController.dispose();
    _insuranceController.dispose();
    _mandatoryInsuranceController.dispose();
    super.dispose();
  }
}
