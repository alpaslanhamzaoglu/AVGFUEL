import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/firebase_options.dart'; // Firebase config

Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Read the JSON file
  final file = File('./data.json');
  if (!await file.exists()) {
    print('Error: JSON file not found!');
    return;
  }

  final fileContent = await file.readAsString();
  final List<dynamic> dataList = jsonDecode(fileContent);

  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();

  for (var brandData in dataList) {
    final brandRef = firestore.collection('vehicleData').doc(brandData['brand']);

    for (var model in brandData['models']) {
      final modelRef = brandRef.collection('models').doc(model['name']);

      batch.set(modelRef, {
        'name': model['name'],
        'engines': model['engines'], // Save engines as an array
      });
    }
  }

  await batch.commit();
  print('Data upload complete!');
}
