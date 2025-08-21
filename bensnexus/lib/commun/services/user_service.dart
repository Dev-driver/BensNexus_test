import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _adminCollection = 'Compte_Admin';

  /// Détermine le rôle de l'utilisateur ('admin' ou 'driver') en se basant
  /// sur son email ou son numéro de téléphone dans la collection des administrateurs.
  ///
  /// Retourne 'admin', 'driver', ou 'logout' si l'utilisateur n'a pas d'identifiant.
  Future<String> getUserRole(User user) async {
    try {
      final email = user.email;
      // 1. Vérifier si l'utilisateur est un admin par email (plus fiable).
      if (email != null && email.isNotEmpty) {
        final adminQuery = await _firestore
            .collection(_adminCollection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (adminQuery.docs.isNotEmpty) {
          return 'admin';
        }
      }

      final phoneNumber = user.phoneNumber;
      // 2. Si non trouvé par email, vérifier par numéro de téléphone.
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        final adminQuery = await _firestore
            .collection(_adminCollection)
            .where('numero', isEqualTo: phoneNumber)
            .limit(1)
            .get();
        if (adminQuery.docs.isNotEmpty) {
          return 'admin';
        }
      }

      // 3. Si ce n'est pas un admin, on le considère comme un driver.
      return 'driver';
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la vérification du statut admin : $e");
      }
      // En cas d'erreur, on refuse l'accès par sécurité.
      return 'logout';
    }
  }
}
