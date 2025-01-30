import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Read the JSON file
  final file = File('./backend/data.json');
  final contents = await file.readAsString();
  final List<dynamic> data = json.decode(contents);

  // Upload data to Firestore
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();

  for (final brandData in data) {
    final brandRef = firestore.collection('vehicle').doc(brandData['brand']);
    batch.set(brandRef, {'name': brandData['brand']});

    for (final modelData in brandData['models']) {
      final modelRef = brandRef.collection('models').doc(modelData['name']);
      batch.set(modelRef, {'name': modelData['name']});

      for (final engine in modelData['engines']) {
        final engineRef = modelRef.collection('engines').doc(engine);
        batch.set(engineRef, {'name': engine});
      }
    }
  }

  await batch.commit();
  print('Data uploaded successfully!');
}
