import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../helper/firebase_auth.dart';
import '../helper/validator.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isProcessing = false;

  Future<FirebaseApp> _initializeFirebase() async {
    FirebaseApp firebaseApp = await Firebase.initializeApp();
    return firebaseApp;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder(
        future: _initializeFirebase(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lobster',
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Create an account to get started',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Card(
                      color: Colors.grey[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              TextFormField(
                                controller: _usernameController,
                                style: const TextStyle(color: Colors.white),
                                validator: (value) => Validator.validateField(
                                    field: value, fieldName: 'UserName'),
                                decoration: InputDecoration(
                                  hintText: "Username",
                                  hintStyle:
                                      const TextStyle(color: Colors.white54),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none),
                                  fillColor: Colors.grey[800],
                                  filled: true,
                                  prefixIcon: const Icon(
                                    Icons.person,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16.0),
                              // Email Input
                              TextFormField(
                                controller: _emailController,
                                style: const TextStyle(color: Colors.white),
                                validator: (value) =>
                                    Validator.validateEmail(email: value),
                                decoration: InputDecoration(
                                  hintText: "Email",
                                  hintStyle:
                                      const TextStyle(color: Colors.white54),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none),
                                  fillColor: Colors.grey[800],
                                  filled: true,
                                  prefixIcon: const Icon(
                                    Icons.email,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16.0),
                              // Password Input
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                style: const TextStyle(color: Colors.white),
                                validator: (value) =>
                                    Validator.validatePassword(password: value),
                                decoration: InputDecoration(
                                  hintText: "Password",
                                  hintStyle:
                                      const TextStyle(color: Colors.white54),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none),
                                  fillColor: Colors.grey[800],
                                  filled: true,
                                  prefixIcon: const Icon(
                                    Icons.lock,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16.0),
                              // Full Name Input
                              TextFormField(
                                controller: _fullNameController,
                                style: const TextStyle(color: Colors.white),
                                validator: (value) => Validator.validateField(
                                    field: value, fieldName: 'Full Name'),
                                decoration: InputDecoration(
                                  hintText: "Full Name",
                                  hintStyle:
                                      const TextStyle(color: Colors.white54),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none),
                                  fillColor: Colors.grey[800],
                                  filled: true,
                                  prefixIcon: const Icon(
                                    Icons.account_circle,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16.0),
                              // Address Input
                              TextFormField(
                                controller: _addressController,
                                style: const TextStyle(color: Colors.white),
                                validator: (value) => Validator.validateField(
                                    field: value, fieldName: 'Address'),
                                decoration: InputDecoration(
                                  hintText: "Address",
                                  hintStyle:
                                      const TextStyle(color: Colors.white54),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none),
                                  fillColor: Colors.grey[800],
                                  filled: true,
                                  prefixIcon: const Icon(
                                    Icons.location_on,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24.0),
                              // Sign Up Button
                              _isProcessing
                                  ? const CircularProgressIndicator()
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              if (_formKey.currentState!
                                                  .validate()) {
                                                setState(() {
                                                  _isProcessing = true;
                                                });

                                                User? user =
                                                    await FirebaseAuthHelper
                                                        .registerUsingEmailPassword(
                                                  name:
                                                      _usernameController.text,
                                                  email: _emailController.text,
                                                  password:
                                                      _passwordController.text,
                                                  fullname:
                                                      _fullNameController.text,
                                                  address:
                                                      _addressController.text,
                                                );

                                                setState(() {
                                                  _isProcessing = false;
                                                });

                                                if (user != null) {
                                                  Navigator.of(context)
                                                      .pop(); // Navigate to another screen if needed
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20.0,
                                                      vertical: 15.0),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              backgroundColor: Colors.grey[700],
                                              alignment: Alignment
                                                  .center, // Menjaga teks tetap di tengah
                                            ),
                                            child: const Text(
                                              'SIGN UP',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Color.fromARGB(
                                                    255, 225, 224, 224),
                                                fontWeight: FontWeight
                                                    .bold, // Membuat teks menjadi tebal
                                              ),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
