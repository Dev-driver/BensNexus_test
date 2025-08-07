import 'package:flutter/material.dart';

class OrderDetailsScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Détails Commande #$orderId')),
      body: Center(
        child: Text('Détails de la commande ID: $orderId'),
      ),
    );
  }
}
