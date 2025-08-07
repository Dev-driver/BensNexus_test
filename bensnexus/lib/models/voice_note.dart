import 'package:cloud_firestore/cloud_firestore.dart';

/// Représente la structure d'un document dans la collection 'notes_vocales'.
/// L'utilisation d'un modèle de données rend le code plus sûr et plus facile à maintenir.
class VoiceNote {
  final String urlAudio;
  final String nomFichier;
  final int duree;
  final int tailleFichier;
  final Timestamp dateCreation;
  final String driver;
  final String tracteur;
  final String idLigneTransport;
  final GeoPoint position;

  VoiceNote({
    required this.urlAudio,
    required this.nomFichier,
    required this.duree,
    required this.tailleFichier,
    required this.dateCreation,
    required this.driver,
    required this.tracteur,
    required this.idLigneTransport,
    required this.position,
  });

  /// Convertit l'objet VoiceNote en une Map pour l'enregistrement dans Firestore.
  Map<String, dynamic> toMap() {
    return {
      'url_audio': urlAudio,
      'nom_fichier': nomFichier,
      'duree': duree,
      'taille_fichier': tailleFichier,
      'date_creation': dateCreation,
      'Driver': driver,
      'Tracteur': tracteur,
      'id-ligne-transport': idLigneTransport,
      'position': position,
    };
  }
}