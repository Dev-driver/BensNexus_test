import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class OtpPhoneScreen extends StatefulWidget {
  const OtpPhoneScreen({super.key, required this.phoneNumber, required this.verificationId});

  final String phoneNumber;
  final String verificationId;

  @override
  State<OtpPhoneScreen> createState() => _OtpPhoneScreenState();
}

class _OtpPhoneScreenState extends State<OtpPhoneScreen> {
  final TextEditingController _otpController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Crée une credential avec le code SMS
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      // Connecte l'utilisateur avec la credential
      await FirebaseAuth.instance.signInWithCredential(credential);

      // L'utilisateur est authentifié ! Redirige vers la page d'accueil
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on FirebaseAuthException catch (e) {
      // Gère les erreurs d'authentification Firebase
      _errorMessage = "Erreur de vérification : ${e.message}";
    } catch (e) {
      // Gère les autres erreurs
      _errorMessage = "Une erreur inattendue s'est produite.";
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification OTP')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Vérification",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Entrez le code envoyé à ${widget.phoneNumber}",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Pinput(
                length: 6,
                controller: _otpController,
                autofocus: true,
                onCompleted: (pin) => _verifyOtp(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _verifyOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      )
                    : const Text('Vérifier'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}