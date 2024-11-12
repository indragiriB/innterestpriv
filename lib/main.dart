import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'screens/login_screen.dart';
import 'screens/home_screen.dart'; // Pastikan Anda membuat HomeScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'innterest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Lato',
        primarySwatch: Colors.blue,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(
              fontSize: 24.0,
            ),
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          ),
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            fontSize: 46.0,
            color: Colors.blue.shade700,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: const TextStyle(fontSize: 18.0),
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.grey,
          selectedItemColor: Colors.red,
          unselectedItemColor: Colors.white70,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance
            .authStateChanges(), // Mendengarkan perubahan status autentikasi
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final User? user = snapshot.data;1
            if (user != null) {
              return HomeScreen(
                  user: user); // Arahkan ke HomeScreen dengan user
            } else {
              return const LoginScreen(); // Tampilkan LoginScreen jika belum login
            }
          }
          return const Center(
              child:
                  CircularProgressIndicator()); // Tampilkan loader saat menunggu
        },
      ),
    );
  }
}
