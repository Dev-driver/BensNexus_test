// lib/screens/order_detail_screen.dart
import 'package:flutter/material.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détail de la commande $orderId'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Informations pour la commande ID: $orderId',
              style: const TextStyle(fontSize: 20),
            ),
            // TODO: Afficher ici les détails complets de la commande
          ],
        ),
      ),
    );
  }
}