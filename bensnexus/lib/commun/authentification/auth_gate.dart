import 'package:bensnexus/commun/authentification/screen/onboarding_screen.dart';
import 'package:bensnexus/commun/authentification/screen/auth_screen.dart';
import 'package:bensnexus/commun/services/user_service.dart';
import 'package:bensnexus/home_screen.dart';
import 'package:bensnexus/home_screen_admin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// CHANGEMENT ICI : Importer le nouveau package
import 'package:loading_animation_widget/loading_animation_widget.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _isFirstLaunch;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Un petit délai pour mieux voir l'animation (à supprimer en production)
    await Future.delayed(const Duration(seconds: 2)); 
    
    final prefs = await SharedPreferences.getInstance();
    final alreadyOpened = prefs.getBool('alreadyOpened') ?? false;

    if (!alreadyOpened) {
      await prefs.setBool('alreadyOpened', true);
      _isFirstLaunch = true;
    } else {
      _isFirstLaunch = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tant qu'on ne sait pas si c'est le premier lancement ou non
    if (_isFirstLaunch == null) {
      return Scaffold(
        body: Center(
          // CHANGEMENT ICI : Utilisation de l'animation du package
          child: LoadingAnimationWidget.threeArchedCircle(
            color: Theme.of(context).primaryColor, // Utilise la couleur primaire du thème
            size: 50,
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return Scaffold(
            body: Center(
              // CHANGEMENT ICI : Utilisation de l'animation du package
              child: LoadingAnimationWidget.threeArchedCircle(
                color: Theme.of(context).primaryColor,
                size: 50,
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return _isFirstLaunch! ? const OnboardingScreen() : const AuthScreen();
        }

        // Une fois l'utilisateur connecté, on vérifie son rôle pour le rediriger.
        return RoleDispatcher(user: user);
      },
    );
  }
}

/// Un widget qui détermine l'écran à afficher en fonction du rôle de l'utilisateur.
class RoleDispatcher extends StatefulWidget {
  final User user;
  const RoleDispatcher({super.key, required this.user});

  @override
  State<RoleDispatcher> createState() => _RoleDispatcherState();
}

class _RoleDispatcherState extends State<RoleDispatcher> {
  final UserService _userService = UserService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _userService.getUserRole(widget.user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: LoadingAnimationWidget.threeArchedCircle(color: Theme.of(context).primaryColor, size: 50)));
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == 'logout') {
          // En cas d'erreur ou si le rôle n'est pas trouvé, on déconnecte l'utilisateur
          // pour éviter qu'il ne soit bloqué sur un écran de chargement ou d'erreur.
          // La redirection vers AuthScreen sera gérée par le StreamBuilder parent qui écoute authStateChanges.
          if (FirebaseAuth.instance.currentUser != null) {
            Future.microtask(() => FirebaseAuth.instance.signOut());
          }
          return const Scaffold(body: Center(child: Text("Erreur de vérification du rôle.")));
        }

        return snapshot.data == 'admin' ? const HomeScreenAdmin() : const HomeScreen();
      },
    );
  }
}