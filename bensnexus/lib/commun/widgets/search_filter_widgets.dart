// lib/widgets/search_filter_widgets.dart

import 'package:flutter/material.dart';

// Un widget réutilisable pour la barre de recherche
class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const SearchBarWidget({
    super.key,
    required this.controller,
    this.hintText = 'Recherche par titre ou destination',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey.shade200,
        prefixIcon: const Icon(Icons.search),
        // Ajout d'un suffixIcon pour effacer la recherche
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  controller.clear();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// Un widget réutilisable pour le panneau de filtres
class FilterPanel extends StatelessWidget {
  final String selectedStatus;
  final bool onlyWithNotif;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onNotifChanged;
  final VoidCallback onClearFilters;
  final List<String> statusOptions;

  const FilterPanel({
    super.key,
    required this.selectedStatus,
    required this.onlyWithNotif,
    required this.onStatusChanged,
    required this.onNotifChanged,
    required this.onClearFilters,
    required this.statusOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menu déroulant pour les statuts
          Expanded(
            child: DropdownButton<String>(
              value: selectedStatus,
              isExpanded: true,
              underline: Container(height: 1, color: Colors.grey.shade400),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  onStatusChanged(newValue);
                }
              },
              items: statusOptions.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 10),
          // Checkbox pour les notifications
          Row(
            children: [
              Checkbox(
                value: onlyWithNotif,
                onChanged: (bool? value) {
                  onNotifChanged(value ?? false);
                },
              ),
              const Text('Avec notif.'),
            ],
          ),
          const SizedBox(width: 5),
          // Bouton pour réinitialiser les filtres
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.red),
            tooltip: 'Réinitialiser les filtres',
            onPressed: onClearFilters,
          ),
        ],
      ),
    );
  }
}