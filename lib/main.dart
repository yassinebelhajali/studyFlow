import 'package:flutter/material.dart';
import 'home.dart';
import 'cours_page.dart';
import 'tasks_page.dart';
import 'profile.dart';
import 'emploi.dart';
import 'login.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoginPage(),
  ));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  void _navigateFromHome(String page) {
    const pageIndex = <String, int>{
      'home': 0,
      'emploi': 1,
      'tasks': 2,
      'cours': 3,
      'profile': 4,
    };
    setState(() {
      _currentIndex = pageIndex[page] ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        userName: 'Sarah Johnson',
        onNavigate: _navigateFromHome,
      ),
      const StudyFlowApp(),
      const TasksPage(),
      CoursPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; 
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: "Emploi"),
          BottomNavigationBarItem(icon: Icon(Icons.check_box), label: "Tasks"),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: "Cours"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
