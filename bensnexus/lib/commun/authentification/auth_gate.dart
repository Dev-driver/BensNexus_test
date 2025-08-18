import 'package:bensnexus/commun/authentification/screen/onboarding_screen.dart';
import 'package:bensnexus/commun/authentification/screen/auth_screen.dart';
import 'package:bensnexus/home_screen.dart';
import 'package:bensnexus/home_screen_admin.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  /// Vérifie dans Firestore si l'utilisateur est un admin ou un driver.
  Future<String> _checkUserRole() async {
    final user = widget.user;
    final phoneNumber = user.phoneNumber;
    final email = user.email;

    // Si l'utilisateur n'a ni numéro de téléphone ni email, on ne peut pas vérifier son rôle.
    if ((phoneNumber == null || phoneNumber.isEmpty) && (email == null || email.isEmpty)) {
      await FirebaseAuth.instance.signOut();
      return 'logout';
    }

    final adminCollection = FirebaseFirestore.instance.collection('ops_admin');

    // 1. Vérifier si l'utilisateur est un administrateur par numéro de téléphone.
    // On vérifie le format international (ex: +221...) et un format local potentiel (les 9 derniers chiffres).
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final List<String> phoneFormats = [phoneNumber];
      // Ajoute le format sans le code pays si le numéro est assez long.
      if (phoneNumber.length > 9) {
        phoneFormats.add(phoneNumber.substring(phoneNumber.length - 9));
      }

      final adminQuery = await adminCollection
          .where('numero', whereIn: phoneFormats)
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        return 'admin';
      }
    }

    // 2. Si non trouvé par numéro, vérifier par email (si disponible).
    // Cela suppose que les documents admin peuvent avoir un champ 'email'.
    if (email != null && email.isNotEmpty) {
      final adminQuery =
          await adminCollection.where('email', isEqualTo: email).limit(1).get();
      if (adminQuery.docs.isNotEmpty) {
        return 'admin';
      }
    }

    // 3. Si ce n'est pas un admin, on considère que c'est un driver.
    // La logique de HomeScreen gère déjà le cas où un driver n'a pas d'opération active.
    return 'driver';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _checkUserRole(),
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