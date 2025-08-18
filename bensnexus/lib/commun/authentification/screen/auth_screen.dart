import 'package:bensnexus/commun/authentification/otp_screen.dart'; // Assurez-vous que ce chemin est correct
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bensnexus/home_screen_admin.dart';
import 'package:bensnexus/home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Clés et Contrôleurs
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController(); // Pour le mot de passe (email)
  final _otpController = TextEditingController(); // Pour le code OTP

  // Logique de Firebase et état de l'UI
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;

  // Pour gérer les différents états d'authentification
  bool _isEmailMode = false;
  bool _isOtpSent = false;
  String? _verificationId; // Pour mobile
  ConfirmationResult? _confirmationResult; // Pour le web

  @override
  void dispose() {
    _contactController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// Détermine si l'entrée est un email ou un téléphone et lance l'authentification.
  void _submitAuth() async {
    // Si le code OTP a été envoyé, on vérifie le code entré.
    if (_isOtpSent && !_isEmailMode) {
      if (kIsWeb) {
        _verifyOtpWeb();
      }
      // La vérification mobile se fait dans l'écran OTP, donc pas de logique ici.
      return;
    }

    // Valide les champs du formulaire
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String contactInput = _contactController.text.trim();

    // Si on est en mode email (déterminé par l'input)
    if (_isEmailMode) {
      _handleEmailAuth(contactInput, _passwordController.text);
    }
    // Sinon, on suppose que c'est un numéro de téléphone
    else {
      // On formate le numéro pour l'authentification Firebase
      String phoneNumber = contactInput.replaceAll(' ', ''); // Supprime les espaces

      // Gère les cas où l'utilisateur entre ou non l'indicatif
      if (phoneNumber.startsWith('+221')) {
        // Numéro déjà correct.
      } else if (phoneNumber.startsWith('221')) {
        phoneNumber = '+$phoneNumber';
      } else {
        phoneNumber = '+221$phoneNumber';
      }
      _sendOtp(phoneNumber);
    }
  }

  /// Gère la logique pour l'authentification par email lors de la connexion
  Future<void> _handleEmailAuth(String email, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      // L'authentification a réussi, on vérifie le rôle et on navigue.
      await _onAuthSuccess(userCredential);
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Une erreur d'authentification est survenue.";
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = "L'email ou le mot de passe est incorrect.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Le format de l'email est invalide.";
      }
      _handleError(errorMessage);
    } catch (e) {
      _handleError("Une erreur inattendue est survenue. Veuillez réessayer.");
    }
  }

  /// Envoie le code OTP via Firebase (logique du Bloc A)
  Future<void> _sendOtp(String phoneNumber) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (kIsWeb) {
      try {
        // Sur le web, on utilise reCAPTCHA. Assurez-vous d'avoir un div avec id='recaptcha-container' dans votre index.html
        _confirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);
        setState(() {
          _isLoading = false;
          _isOtpSent = true; // Affiche le champ OTP
        });
      } on FirebaseAuthException catch (e) {
        _handleError("Erreur reCAPTCHA : ${e.message}");
      }
    } else {
      // Logique existante pour mobile
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          setState(() => _isLoading = false);
          // La vérification est automatique, on connecte et on enregistre si besoin
          final userCredential = await _auth.signInWithCredential(credential);
          await _onAuthSuccess(userCredential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _handleErrorFromException(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          // Sur mobile, on navigue vers un écran dédié pour l'OTP
          _navigateToOtpScreen(verificationId, phoneNumber, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Géré si nécessaire
        },
      );
    }
  }

  /// Gère la navigation vers l'écran OTP sur mobile.
  void _navigateToOtpScreen(String verificationId, String phoneNumber, int? resendToken) async {
    setState(() => _isLoading = false);
    if (mounted) {
      // Navigue vers l'écran OTP et attend le code en retour
      final otpCode = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            verificationId: verificationId,
            phoneNumber: phoneNumber,
            resendToken: resendToken,
          ),
        ),
      );

      // Si l'utilisateur a entré un code et est revenu
      if (otpCode != null && otpCode.isNotEmpty) {
        setState(() => _isLoading = true);
        try {
          PhoneAuthCredential credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: otpCode,
          );
          final userCredential = await _auth.signInWithCredential(credential);
          await _onAuthSuccess(userCredential);
        } on FirebaseAuthException {
          _handleError("Le code OTP est incorrect ou a expiré. Veuillez réessayer.");
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    }
  }

  /// Gère la vérification du code OTP sur le web.
  Future<void> _verifyOtpWeb() async {
    if (_confirmationResult == null) {
      _handleError("Erreur interne, veuillez recommencer.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userCredential = await _confirmationResult!.confirm(_otpController.text.trim());
      await _onAuthSuccess(userCredential);
    } on FirebaseAuthException catch (e) {
      _handleError(e.code == 'invalid-verification-code'
          ? "Le code OTP est incorrect. Veuillez réessayer."
          : "Une erreur est survenue: ${e.message}");
    }
  }

  /// Gère les erreurs de `verifyPhoneNumber`
  void _handleErrorFromException(FirebaseAuthException e) {
        String errorMessage;
        switch (e.code) {
          case 'invalid-phone-number':
            errorMessage =
                "Le numéro de téléphone n'est pas valide. Veuillez inclure l'indicatif (ex: +221).";
            break;
          case 'quota-exceeded':
            errorMessage = "Quota de SMS dépassé. Réessayez plus tard.";
            break;
          case 'too-many-requests':
            errorMessage = "Trop de tentatives ont été effectuées depuis cet appareil. Veuillez réessayer plus tard.";
            break;
          default:
            // Le message que vous vouliez enlever a été remplacé par un message plus clair.
            errorMessage = "Impossible de vérifier ce numéro. Veuillez réessayer ou contacter le support.";
        }
        _handleError(errorMessage);
  }

  /// Gère la logique après une authentification réussie (auto ou manuelle).
  /// C'est ici que l'enregistrement automatique est effectué.
  Future<void> _onAuthSuccess(UserCredential userCredential) async {
    final user = userCredential.user;
    if (user == null) {
      _handleError("Impossible de récupérer les informations de l'utilisateur.");
      return;
    }

    try {
      String? userEmail = user.email;
      bool isAdmin = false;

      // Un utilisateur admin doit avoir un email pour être vérifié dans la collection.
      if (userEmail != null && userEmail.isNotEmpty) {
        final adminDoc = await FirebaseFirestore.instance
            .collection('Compte_Admin')
            .where('email', isEqualTo: userEmail)
            .limit(1)
            .get();

        if (adminDoc.docs.isNotEmpty) {
          isAdmin = true;
        } else if (_isEmailMode) {
          // Si l'utilisateur tente de se connecter par email mais n'est pas un admin,
          // on le déconnecte et on affiche une erreur.
          await _auth.signOut();
          _handleError("Accès refusé. Seuls les administrateurs peuvent se connecter par email.");
          return;
        }
      } else if (_isEmailMode) {
        // Sécurité : si on est en mode email mais que l'utilisateur n'a pas d'email (ne devrait pas arriver)
        await _auth.signOut();
        _handleError("La connexion par email requiert une adresse email valide.");
        return;
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => isAdmin ? const HomeScreenAdmin() : const HomeScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      _handleError("Erreur lors de la vérification des permissions. Veuillez réessayer.");
    }
  }

  /// Gère l'affichage des erreurs
  void _handleError(String message) {
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Logo de l'application.
            Image.asset('assetes/image/logo-transparent.png', height: 100, width: 300),
            const SizedBox(height: 80),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Champ unifié pour email ou téléphone
                  TextFormField(
                    controller: _contactController,
                    onChanged: (value) {
                      final bool isNowEmail = value.contains('@');
                      if (isNowEmail != _isEmailMode) {
                        _formKey.currentState?.reset();
                        setState(() {
                          _isEmailMode = isNowEmail;
                          _errorMessage = null; // Réinitialise l'erreur au changement de mode
                        });
                      }
                    },
                    keyboardType: _isEmailMode ? TextInputType.emailAddress : TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: _isEmailMode ? 'Email' : 'Numéro de téléphone',
                      hintText: _isEmailMode ? 'admin@example.com' : '77 123 45 67',
                      prefixIcon: _isEmailMode
                          ? const Icon(Icons.email_outlined)
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 15), // Espace à gauche
                                const Text('🇸🇳', style: TextStyle(fontSize: 24)),
                                const SizedBox(width: 8),
                                const Text('+221', style: TextStyle(fontSize: 16)),
                                Container(
                                  height: 24,
                                  width: 1,
                                  color: Colors.grey.shade400,
                                  margin: const EdgeInsets.only(left: 8, right: 4),
                                ),
                              ],
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ce champ ne peut pas être vide';
                      }
                      return null;
                    },
                  ),

                  // Le champ de mot de passe s'affiche en mode email
                  if (_isEmailMode) ...[
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Veuillez entrer votre mot de passe';
                        return null;
                      },
                    ),
                  ],

                  // Le champ OTP s'affiche si on est en mode téléphone et que le code a été envoyé (sur le web)
                  if (!_isEmailMode && _isOtpSent && kIsWeb) ...[
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Code de vérification (OTP)',
                        prefixIcon: Icon(Icons.sms),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Veuillez entrer le code reçu';
                        if (value.length != 6) return 'Le code doit contenir 6 chiffres';
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Affichage de l'erreur
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],

                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isOtpSent && !_isEmailMode && kIsWeb
                                ? 'Vérifier le code'
                                : 'Se connecter',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
