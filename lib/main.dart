import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _initializeFirebase() async {
    await Firebase.initializeApp();
    return true;
  }

  Future<bool> _hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('intro_seen') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text("Failed to initialize Firebase"),
              ),
            ),
          );
        }

        return MaterialApp(
          title: 'innterest',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'Lato',
            // scaffoldBackgroundColor: Color.fromARGB(255, 53, 53, 53),
          ),
          routes: {
            '/home': (context) =>
                HomeScreen(user: FirebaseAuth.instance.currentUser!),
            '/intro': (context) => const IntroScreen(),
            '/login': (context) => const LoginScreen(),
          },
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final User? user = snapshot.data;
              if (user == null) {
                return const LoginScreen();
              }

              return FutureBuilder<bool>(
                future: _hasSeenIntro(),
                builder: (context, introSnapshot) {
                  if (introSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (introSnapshot.hasData && introSnapshot.data == true) {
                    return HomeScreen(user: user);
                  }
                  return const IntroScreen();
                },
              );
            },
          ),
        );
      },
    );
  }
}
