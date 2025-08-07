import 'package:bensnexus/commun/authentification/otp_screen.dart'; // Assurez-vous que ce chemin est correct
import 'package:bensnexus/commun/generale/elementBensGroup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Clés et Contrôleurs
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController =
      TextEditingController(); // Nouveau contrôleur unifié

  // Logique de Firebase et état de l'UI
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  /// Détermine si l'entrée est un email ou un téléphone et lance l'authentification.
  void _submitAuth() async {
    // Valide les champs du formulaire
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String contactInput = _contactController.text.trim();

    // Vérifie si l'entrée contient '@' pour la considérer comme un email
    if (contactInput.contains('@')) {
      _handleEmailAuth(contactInput);
    }
    // Sinon, on suppose que c'est un numéro de téléphone
    else {
      // On s'assure que le numéro commence par '+' pour Firebase
      final String fullPhoneNumber =
          contactInput.startsWith('+') ? contactInput : '+$contactInput';
      _sendOtp(fullPhoneNumber);
    }
  }

  /// Gère la logique pour l'authentification par email lors de la connexion
  Future<void> _handleEmailAuth(String email) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Recherche dans la collection client
      final query = await FirebaseFirestore.instance
          .collection('client')
          .where('contact', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        // Email trouvé, ouvrir l'écran OTP
        setState(() => _isLoading = false);
        if (context.mounted) {
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                verificationId: 'email',
                phoneNumber: email,
                resendToken: null,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Aucun compte trouvé avec cet email.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Erreur lors de la vérification : $e";
      });
    }
  }

  /// Envoie le code OTP via Firebase (logique du Bloc A)
  Future<void> _sendOtp(String phoneNumber) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        setState(() => _isLoading = false);
        // La vérification est automatique, on connecte et on enregistre si besoin
        final userCredential = await _auth.signInWithCredential(credential);
        await _onAuthSuccess(userCredential);
      },
      verificationFailed: (FirebaseAuthException e) {
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
      },
      codeSent: (String verificationId, int? resendToken) async {
        setState(() => _isLoading = false);
        if (context.mounted) {
          // Navigue vers l'écran OTP et attend le code en retour
          final otpCode = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                verificationId: verificationId,
                phoneNumber: phoneNumber,
                resendToken: resendToken,
                // NOTE: Les paramètres 'driverName' et 'onVerified' ne sont plus nécessaires ici
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
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  /// Gère la logique après une authentification réussie (auto ou manuelle).
  /// C'est ici que l'enregistrement automatique est effectué.
  Future<void> _onAuthSuccess(UserCredential userCredential) async {
    final user = userCredential.user;
    if (user == null) return;
 
    final driverCollection =
        FirebaseFirestore.instance.collection('Comptes_Driver');
    final docRef = driverCollection.doc(user.uid);
    final docSnapshot = await docRef.get();
    final bool accountExists = docSnapshot.exists;
 
    // Si l'utilisateur est sur l'onglet "Inscription"
    if (!_isLogin) {
      if (accountExists) {
        // Le compte existe déjà, on informe l'utilisateur qu'on le connecte simplement.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ce numéro est déjà enregistré. Connexion..."),
              backgroundColor: Colors.blue,
            ),
          );
          // On attend un peu pour que le message soit visible
          await Future.delayed(const Duration(milliseconds: 800));
        }
      } else {
        // Le compte n'existe pas, on le crée.
        final driverName = _nameController.text.trim();
        if (driverName.isNotEmpty) {
          await docRef.set({
            'nom': driverName,
            'telephone': user.phoneNumber,
            'uid': user.uid,
            'date_creation': FieldValue.serverTimestamp(),
          });
        }
      }
    }
    // Dans tous les cas (connexion ou inscription réussie), on navigue vers l'accueil.
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/driver', (Route<dynamic> route) => false);
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
        title: Text(_isLogin ? 'Connexion' : 'Inscription'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Assurez-vous que le logo est bien dans votre dossier assets/ et déclaré dans pubspec.yaml
            Image.asset(logo, height: 100, width: 300),
            const SizedBox(height: 40),
            ToggleButtons(
              isSelected: [_isLogin, !_isLogin],
              onPressed: (int index) {
                setState(() {
                  _isLogin = index == 0;
                  _errorMessage =
                      null; // Réinitialise les erreurs au changement
                });
              },
              borderRadius: BorderRadius.circular(30),
              constraints: const BoxConstraints(minHeight: 50, minWidth: 150),
              children: const [
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Connexion')),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Inscription')),
              ],
            ),
            const SizedBox(height: 30),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (!_isLogin)
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre nom';
                        }
                        return null;
                      },
                    ),
                  if (!_isLogin) const SizedBox(height: 15),

                  // Champ unifié pour email ou téléphone
                  TextFormField(
                    controller: _contactController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email ou Numéro de téléphone',
                      hintText: 'exemple@email.com ou +221771234567',
                      prefixIcon: Icon(Icons.contact_mail_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ce champ ne peut pas être vide';
                      }
                      return null;
                    },
                  ),
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
                            _isLogin ? 'Se connecter' : 'Créer un compte',
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
