import 'package:bensnexus/commun/authentification/otp_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countryCodeController =
      TextEditingController(text: "33");

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _sendOtp() async {
    final String phoneNumber = _phoneController.text.trim();
    final String countryCode = _countryCodeController.text.trim();
    final String fullPhoneNumber = '+$countryCode$phoneNumber';

    if (phoneNumber.isEmpty) {
      setState(() {
        _errorMessage = "Veuillez entrer un numéro de téléphone.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _auth.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        String errorMessage;
        switch (e.code) {
          case 'invalid-phone-number':
            errorMessage = "Le numéro de téléphone fourni n'est pas valide.";
            break;
          case 'quota-exceeded':
            errorMessage = "Le quota de SMS a été dépassé. Veuillez réessayer plus tard.";
            break;
          case 'too-many-requests':
            errorMessage = "Trop de tentatives. Veuillez réessayer plus tard.";
            break;
          default:
            errorMessage = "Une erreur est survenue : ${e.message}";
        }
        _handleError(errorMessage);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _isLoading = false);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                verificationId: verificationId,
                phoneNumber: fullPhoneNumber,
                resendToken: resendToken,
              ),
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  void _handleError(String message) {
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("S'inscrire")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Créez votre compte",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Nous vous enverrons un code de vérification",
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 30),
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _countryCodeController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        prefixText: '+',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de téléphone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Envoyer le code'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}