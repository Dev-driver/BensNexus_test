import 'package:flutter/material.dart';

// Fonctions génériques pour le menu des options
void goToInbox(BuildContext context) {
  debugPrint('Boîte de réception cliquée');
  // Navigator.push(...);
}

void goToFilters(BuildContext context) {
  debugPrint('Filtres cliqués');
  // Navigator.push(...);
}

void goToProfile(BuildContext context) {
  debugPrint('Profil cliqué');
  // Navigator.push(...);
}

void goToSettings(BuildContext context) {
  debugPrint('Paramètres cliqués');
  // Navigator.push(...);
}

void logout(BuildContext context) {
  debugPrint('Déconnexion cliquée');
  Navigator.pushReplacementNamed(context, '/auth');
}