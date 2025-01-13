import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'fuel_log_screen.dart'; // Main app screen
import 'login_page.dart'; // Login screen
import 'signup_page.dart'; // Sign up screen
import 'account_page.dart'; // Account page
import 'firebase_options.dart'; // Firebase configuration file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(FuelTrackerApp());
}

class FuelTrackerApp extends StatelessWidget {
  const FuelTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fuel Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: FirebaseAuth.instance.currentUser == null ? '/login' : '/fuel_log',
      routes: {
        '/login': (context) => const LoginPage(),
        '/fuel_log': (context) => const FuelLogScreen(),
        '/signup': (context) => const SignUpPage(), // Sign Up page route
        '/account': (context) => const AccountPage(), // Account page route
      },
    );
  }
}
