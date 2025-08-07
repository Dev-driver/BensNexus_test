// lib/widgets/order_list_item.dart
import 'package:flutter/material.dart';

class OrderListItem extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const OrderListItem({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['client'] ?? 'Titre non disponible',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Destination : ${order['address'] ?? 'Non spécifiée'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildStatusSection(context, order['status'] ?? ''),
            ],
          ),
        ),
      ),
    );
  }

  // Widget interne pour construire la section de statut à droite
  Widget _buildStatusSection(BuildContext context, String status) {
    Color statusColor;
    String statusText;
    bool hasActionButton = false;

    switch (status) {
      case 'en cours':
        statusColor = Colors.green;
        statusText = 'en cours';
        hasActionButton = true;
        break;
      case 'en attente de confirmation':
        statusColor = Colors.orange;
        statusText = 'en attente de confirmation';
        break;
      default: // en attente
        statusColor = Colors.blue;
        statusText = 'en attente';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        if (hasActionButton) ...[
          const SizedBox(height: 8),
          Text(
            'Démarrer le suivi',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          )
        ]
      ],
    );
  }
}