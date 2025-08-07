// lib/widgets/empty_orders_view.dart
import 'package:flutter/material.dart';

class EmptyOrdersView extends StatelessWidget {
  const EmptyOrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Vous pouvez remplacer cette icône par une image si vous le souhaitez
            Icon(
              Icons.map_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              "Vous n'avez aucune course en cours d'exécution",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // TODO: Implémenter la logique pour assigner une course
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C), // Rouge foncé
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text("Nous assigner une course"),
            ),
          ],
        ),
      ),
    );
  }
}