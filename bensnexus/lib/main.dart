import 'package:bensnexus/commun/authentification/auth_gate.dart';
import 'package:bensnexus/commun/authentification/screen/auth_screen.dart';
import 'package:bensnexus/commun/authentification/screen/onboarding_screen.dart';
import 'package:bensnexus/home_screen.dart';
import 'package:bensnexus/moduleClient/screens/orders_screen.dart';
import 'package:flutter/material.dart';

// Importations Firebase
import 'package:firebase_core/firebase_core.dart';
// ignore: unused_import
import 'firebase_options.dart'; // Ce fichier est généré par FlutterFire CLI

void main() async {
  // Assure que les bindings Flutter sont prêts
  WidgetsFlutterBinding.ensureInitialized();
  // Initialise Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class DefaultFirebaseOptions {
  static var currentPlatform;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bens Nexus',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFD32F2F), // Rouge BGA
                primary: const Color(0xFFD32F2F),
              ),
              useMaterial3: true,
            ),
            routes: {
              '/onboarding': (context) => const OnboardingScreen(),
              '/auth': (context) => const AuthScreen(),
              '/driver': (context) => const HomeScreen(),
              '/client': (context) => const OrdersScreen(),
            },
      home: const AuthGate(), // Ce widget choisit la page à afficher (connecté ou non)
    );
  }
}