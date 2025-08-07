import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? _verificationId;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+${_phoneController.text.trim()}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          _showSnackBar("Connecté avec succès !");
          // La navigation est gérée automatiquement par AuthGate.
        },
        verificationFailed: (FirebaseAuthException e) {
          _handleError("Erreur d'envoi du code : ${e.message}");
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
          });
          _showSnackBar("Code envoyé avec succès.");
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      _handleError("Une erreur inattendue est survenue : $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Removed unused _resendOtp and _isResending

  Future<void> _verifyOtp() async {
    if (_verificationId == null) {
      _handleError("ID de vérification manquant.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await _auth.signInWithCredential(credential);
      _showSnackBar("Connecté avec succès !");
      // La navigation est gérée automatiquement par AuthGate.
    } on FirebaseAuthException catch (e) {
      _handleError("Erreur de vérification : ${e.message}");
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _handleError(String message) {
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentification par téléphone')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const CircularProgressIndicator()
              : _otpSent ? _buildOtpView() : _buildPhoneView(),
        ),
      ),
    );
  }

  Widget _buildPhoneView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Entrez votre numéro", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text("Nous vous enverrons un code de vérification", style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 30),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Numéro de téléphone',
            hintText: '33123456789 (avec indicatif pays)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _sendOtp, child: const Text('Envoyer le code')),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ]
      ],
    );
  }

  Widget _buildOtpView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Vérification", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text("Entrez le code envoyé à +${_phoneController.text}", textAlign: TextAlign.center),
        const SizedBox(height: 30),
        Pinput(
          length: 6,
          controller: _otpController,
          autofocus: true,
          onCompleted: (pin) => _verifyOtp(),
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _verifyOtp, child: const Text('Vérifier')),
        TextButton(
          onPressed: () { setState(() { _otpSent = false; }); },
          child: const Text('Changer de numéro'),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ]
      ],
    );
  }
}