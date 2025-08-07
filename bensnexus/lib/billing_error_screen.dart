import 'package:flutter/material.dart';

class BillingErrorScreen extends StatelessWidget {
  const BillingErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erreur de facturation'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'La facturation n\'est pas activée pour ce compte.',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // TODO: Rediriger vers les paramètres du compte
                },
                child: const Text('Gérer les paramètres du compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}