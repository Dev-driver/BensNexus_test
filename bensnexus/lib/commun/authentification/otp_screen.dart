import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
  });

  final String verificationId;
  final String phoneNumber;
  final int? resendToken;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _otpController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  // Pour le minuteur de renvoi
  Timer? _timer;
  int _start = 30;
  bool _isResendButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _isResendButtonEnabled = false;
    _start = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() => timer.cancel());
        _isResendButtonEnabled = true;
      } else {
        setState(() => _start--);
      }
    });
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      await _auth.signInWithCredential(credential);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/driver');
      }
    } on FirebaseAuthException {
      setState(() {
        _errorMessage = "Code OTP invalide ou expiré. Veuillez réessayer.";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Une erreur inattendue s'est produite.";
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_isResendButtonEnabled) return;

    setState(() => _isLoading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _errorMessage = "Erreur lors du renvoi du code : ${e.message}";
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nouveau code envoyé.")),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
      forceResendingToken: widget.resendToken,
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification du code')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Vérification", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Entrez le code envoyé à ${widget.phoneNumber}", textAlign: TextAlign.center),
              const SizedBox(height: 30),
              Pinput(
                length: 6,
                controller: _otpController,
                autofocus: true,
                onCompleted: (pin) => _verifyOtp(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Vérifier'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Vous n'avez pas reçu de code ?"),
                  TextButton(
                    onPressed: _isResendButtonEnabled ? _resendOtp : null,
                    child: Text(
                      _isResendButtonEnabled ? "Renvoyer" : "Renvoyer dans $_start s",
                    ),
                  ),
                ],
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