import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'fuel_log_screen.dart'; // Main app screen
import 'login_page.dart'; // Login screen
import 'signup_page.dart'; // Sign up screen
import 'car_detail_page.dart'; // Car detail page
import 'forum_page.dart'; // Forum page
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
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return _buildPageRoute(const LoginPage(), settings);
          case '/fuel_log':
            return _buildPageRoute(const FuelLogScreen(), settings);
          case '/signup':
            return _buildPageRoute(const SignUpPage(), settings);
          case '/account':
            return _buildPageRoute(const CarDetailPage(), settings);
          case '/forum_page':
            return _buildPageRoute(const ForumPage(), settings);
          default:
            return null;
        }
      },
    );
  }

  PageRouteBuilder _buildPageRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
}
