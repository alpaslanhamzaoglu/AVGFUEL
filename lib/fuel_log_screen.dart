import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'forum_page.dart'; // Import the forum page
import 'maintenance_page.dart'; // Import the maintenance page
import 'fuel_tracker_page.dart'; // Import the fuel tracker page

class FuelLogScreen extends StatefulWidget {
  const FuelLogScreen({super.key});

  @override
  FuelLogScreenState createState() => FuelLogScreenState();
}

class FuelLogScreenState extends State<FuelLogScreen> {
  final PageController _pageController = PageController();
  int _selectedPageIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _navigateToPage(0),
              child: Text(
                'Maintenance',
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedPageIndex == 0 ? Colors.black : Colors.grey[700],
                  fontWeight: _selectedPageIndex == 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _navigateToPage(1),
              child: Text(
                'Fuel Tracker',
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
          icon: Image.asset('assets/forum_icon.png'),
          onPressed: () {
            _navigateToForumPage(context);
          },
        ),
        actions: [
          IconButton(
            icon: Image.asset('assets/licence.png'),
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
          MaintenancePage(), // Use the MaintenancePage widget
          FuelTrackerPage(user: user), // Use the FuelTrackerPage widget
        ],
      ),
    );
  }
}
