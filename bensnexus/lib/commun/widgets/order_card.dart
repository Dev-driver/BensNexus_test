// lib/widgets/order_card.dart
import 'package:flutter/material.dart';

class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isHistory;
  final VoidCallback? onStart;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.isHistory = false,
    this.onStart,
    this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'en cours':
        return Colors.green;
      case 'en attente':
        return Colors.orange;
      case 'en attente de confirmation':
        return Colors.amber.shade700;
      case 'livrée':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBadge = (order['notif'] ?? 0) > 0;
    final status = order['status'] ?? '';
    final showStartBtn = status == 'en attente' && onStart != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1 : Titre et badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    order['title'] ?? 'Commande',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (hasBadge)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${order['notif']}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Ligne 2 : Destination et statut/bouton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end, // Aligne les éléments en bas
              children: [
                // Destination
                Expanded(
                  child: Text(
                    'Destination : ${order['address']}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),

                // Affiche soit le statut, soit le bouton
                if (showStartBtn)
                  ElevatedButton(
                    onPressed: onStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      // Bords peu arrondis et taille plus petite
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Démarrer le suivi', style: TextStyle(fontSize: 13)),
                  )
                else
                  Text(
                    status,
                    style: TextStyle(color: _getStatusColor(status), fontSize: 13),
                  ),
              ],
            ),
            const Divider(height: 20),
          ],
        ),
      ),
    );
  }
}