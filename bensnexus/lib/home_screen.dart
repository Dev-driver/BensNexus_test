import 'dart:io';
import 'dart:async';

import 'package:bensnexus/commun/authentification/screen/auth_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class _StatusInfo {
  const _StatusInfo({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Ajouts pour l'enregistrement vocal
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isUploadingNote = false;
  DateTime? _recordStartTime;

  // Ajouts pour la géolocalisation
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _notePosition;
  String? _tracteur, _driverName, _refLigneTransport;
  String? _idLigneTransport;

  final List<_StatusInfo> _statuses = const [
    _StatusInfo(label: 'En Chargement', icon: Icons.unarchive_outlined, color: Colors.red),
    _StatusInfo(label: 'En route', icon: Icons.local_shipping, color: Colors.orange),
    _StatusInfo(label: 'Arrivé sur site', icon: Icons.location_on, color: Colors.blue),
    _StatusInfo(label: 'Déchargement terminé', icon: Icons.archive_outlined, color: Colors.green),
  ];

  final List<_StatusInfo> _returnStatuses = const [
    _StatusInfo(label: 'En retour', icon: Icons.u_turn_left, color: Colors.purple),
    _StatusInfo(label: 'Arrivé en restitution', icon: Icons.local_parking, color: Colors.teal),
  ];

  Stream<QuerySnapshot>? _operationStream;
  String? _operationDocId;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user?.phoneNumber?.isNotEmpty == true) {
      _operationStream = _firestore
          .collection('ops_ligne_transport')
          .where('Driver_Phone', isEqualTo: user!.phoneNumber)
          .limit(1)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // Helper pour gérer l'upload sur mobile et web
  Future<void> _uploadFileToStorage(Reference ref, XFile file) async {
    if (kIsWeb) {
      await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: file.mimeType));
    } else {
      await ref.putFile(File(file.path));
    }
  }

  Future<void> _pickAndUploadImage() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_operationDocId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur : Opération en cours introuvable.")),
        );
      }
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final phoneNumber = user.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Erreur : Numéro de téléphone utilisateur introuvable.")));
      }
      return;
    }

    try {
      final ref = _storage.ref('profile/$phoneNumber');
      await _uploadFileToStorage(ref, image);
      final imageUrl = await ref.getDownloadURL();

      await _firestore.collection('ops_ligne_transport').doc(_operationDocId).set(
        {'image_driver': imageUrl},
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image de profil mise à jour.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload: $e')),
        );
      }
    }
  }

  Future<void> _updateDriverStatus(String newStatus) async {
    final user = _auth.currentUser;
    if (user == null || _operationDocId == null) return;
    await _firestore.collection('ops_ligne_transport').doc(_operationDocId).set(
      {'statut_driver': newStatus},
      SetOptions(merge: true),
    );
  }

  Future<void> _updateReturnStatus(String newStatus) async {
    if (_operationDocId == null) return;
    await _firestore.collection('ops_ligne_transport').doc(_operationDocId).set(
      {'statut_retour': newStatus},
      SetOptions(merge: true),
    );
  }

  Future<void> _pickAndUploadJustificatif(String firestoreFieldName, String newStatus) async {
    final user = _auth.currentUser;
    if (user == null || _operationDocId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur : Utilisateur ou opération non identifié.")),
        );
      }
      return;
    }

    // Demander à l'utilisateur s'il souhaite télécharger un justificatif
    final bool? wantsToUpload = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.file_upload_outlined),
          SizedBox(width: 10),
          Text('Justificatif')
        ]),
        content: const Text('Voulez-vous ajouter un ou plusieurs justificatifs ?'),
        actions: <Widget>[
          TextButton.icon(
            icon: const Icon(Icons.close),
            label: const Text('Non'),
            onPressed: () => Navigator.of(context).pop(false), // "Non"
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Oui'),
            onPressed: () => Navigator.of(context).pop(true), // "Oui"
          ),
        ],
      ),
    );

    if (wantsToUpload == null) return; // L'utilisateur a fermé la boîte de dialogue

    if (wantsToUpload == false) {
      // Si non, mettre à jour uniquement le statut
      await _updateDriverStatus(newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Statut mis à jour vers "$newStatus".')));
      }
      return;
    }

    // Si oui, permettre la sélection de plusieurs images
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty) {
      // L'utilisateur a choisi d'uploader mais a annulé la sélection
      await _updateDriverStatus(newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour vers "$newStatus". Aucun justificatif ajouté.')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Téléchargement de ${images.length} justificatif(s)...")),
      );
    }

    try {
      List<String> imageUrls = [];
      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ref = _storage.ref('justificatif/$_operationDocId/${firestoreFieldName}_${timestamp}_$i.jpg');
        await _uploadFileToStorage(ref, image);
        final imageUrl = await ref.getDownloadURL();
        imageUrls.add(imageUrl);
      }

      final operationRef = _firestore.collection('ops_ligne_transport').doc(_operationDocId);

      // Utiliser FieldValue.arrayUnion pour ajouter les URLs à un tableau dans Firestore
      await operationRef.set(
        {
          firestoreFieldName: FieldValue.arrayUnion(imageUrls),
          'statut_driver': newStatus,
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour vers "$newStatus" avec ${images.length} justificatif(s).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'envoi du justificatif: $e")),
        );
      }
    }
  }

  Future<void> _pickAndUploadRestitution(String firestoreFieldName, String newStatus) async {
    final user = _auth.currentUser;
    if (user == null || _operationDocId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur : Utilisateur ou opération non identifié.")),
        );
      }
      return;
    }

    // Demander à l'utilisateur s'il souhaite télécharger un justificatif
    final bool? wantsToUpload = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.file_upload_outlined),
          SizedBox(width: 10),
          Text('Justificatif')
        ]),
        content: const Text('Voulez-vous ajouter un ou plusieurs justificatifs ?'),
        actions: <Widget>[
          TextButton.icon(
            icon: const Icon(Icons.close),
            label: const Text('Non'),
            onPressed: () => Navigator.of(context).pop(false), // "Non"
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Oui'),
            onPressed: () => Navigator.of(context).pop(true), // "Oui"
          ),
        ],
      ),
    );

    if (wantsToUpload == null) return; // L'utilisateur a fermé la boîte de dialogue

    if (wantsToUpload == false) {
      // Si non, mettre à jour uniquement le statut
      await _updateReturnStatus(newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Statut mis à jour vers "$newStatus".')));
      }
      return;
    }

    // Si oui, permettre la sélection de plusieurs images
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty) {
      // L'utilisateur a choisi d'uploader mais a annulé la sélection
      await _updateReturnStatus(newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour vers "$newStatus". Aucun justificatif ajouté.')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Téléchargement de ${images.length} justificatif(s)...")),
      );
    }

    try {
      List<String> imageUrls = [];
      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ref = _storage.ref('justificatif/$_operationDocId/${firestoreFieldName}_${timestamp}_$i.jpg');
        await _uploadFileToStorage(ref, image);
        final imageUrl = await ref.getDownloadURL();
        imageUrls.add(imageUrl);
      }

      final operationRef = _firestore.collection('ops_ligne_transport').doc(_operationDocId);

      // Utiliser FieldValue.arrayUnion pour ajouter les URLs à un tableau dans Firestore
      await operationRef.set(
        {
          firestoreFieldName: FieldValue.arrayUnion(imageUrls),
          'statut_retour': newStatus,
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour vers "$newStatus" avec ${images.length} justificatif(s).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'envoi du justificatif: $e")),
        );
      }
    }
  }

  Future<void> _uploadDocumentImages() async {
    if (_idLigneTransport == null || _refLigneTransport == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible de trouver les informations de la ligne de transport.")),
        );
      }
      return;
    }

    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Téléchargement de ${images.length} document(s)...')),
      );
    }

    int successCount = 0;
    for (final image in images) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${timestamp}_${image.name}';
        final ref = _storage.ref('justificatif/$fileName');

        await _uploadFileToStorage(ref, image);
        final imageUrl = await ref.getDownloadURL();

        await _firestore.collection('docs_upload').add({
          'file_url': imageUrl,
          'ID_Ligne_Transport': _idLigneTransport,
          'Ref_Ligne_Transport': _refLigneTransport,
          'timestamp': FieldValue.serverTimestamp(),
        });
        successCount++;
      } catch (e) {
        debugPrint("Erreur lors de l'envoi d'un document: $e");
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$successCount sur ${images.length} document(s) envoyé(s) avec succès."),
        ),
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (await _audioRecorder.isRecording()) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enregistrement terminé.')),
        );
      }
      if (path != null) {
        _uploadAndSaveNote(path, _notePosition);
      }
      _notePosition = null; // Réinitialiser la position
    } else {
      try {
        if (await _audioRecorder.hasPermission()) {
          // Capturer la position au début de l'enregistrement pour plus de précision
          _notePosition = await Geolocator.getCurrentPosition();
          
          // path_provider n'est pas supporté sur le web, on laisse le package gérer le chemin.
          final path = kIsWeb 
              ? '' 
              : '${(await getApplicationDocumentsDirectory()).path}/note_vocale_${DateTime.now().millisecondsSinceEpoch}.m4a';

          await _audioRecorder.start(const RecordConfig(), path: path);

          setState(() {
            _isRecording = true;
            _recordStartTime = DateTime.now();
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enregistrement en cours...')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permission microphone refusée.')),
            );
          }
        }
      } catch (e) {
        debugPrint("Erreur lors du démarrage de l'enregistrement: $e");
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _uploadAndSaveNote(String path, Position? position) async {
    setState(() => _isUploadingNote = true);
    try {
      // Vérifier que les informations nécessaires sont disponibles
      if (_idLigneTransport == null || _operationDocId == null || _refLigneTransport == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Impossible d'enregistrer l'incident, informations d'opération manquantes.")),
          );
        }
        return;
      }

      final fileName = kIsWeb ? 'note_${DateTime.now().millisecondsSinceEpoch}.m4a' : path.split('/').last;

      // 1. Stocker l'audio dans le dossier 'audio/' de Storage
      final ref = _storage.ref('audio_incident/$fileName');
      
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        await ref.putData(response.bodyBytes, SettableMetadata(contentType: 'audio/m4a'));
      } else {
        final file = File(path);
        if (!await file.exists()) return;
        await ref.putFile(file);
      }

      final audioUrl = await ref.getDownloadURL();

      // 2. Enregistrer les informations dans la collection 'incidents_ops'
      await _firestore.collection('incidents_ops').add({
        'audio': audioUrl,
        'ID_Ligne_Transport': _idLigneTransport,
        'ID_Ops': _operationDocId,
        'Ref_Ligne_Transport': _refLigneTransport,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident audio envoyé avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'envoi de l'incident: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingNote = false);
    }
  }

  Future<void> _initGeolocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Vérifier si les services de localisation sont activés.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        await _showExitDialog('Service de localisation désactivé',
            'Veuillez activer la géolocalisation pour utiliser l\'application.');
      }
      return; // L'application se fermera via le dialogue.
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // L'utilisateur a explicitement refusé la permission.
        await _showExitDialog('Permission de localisation refusée',
            'Cette permission est obligatoire pour le fonctionnement de l\'application.');
        return; // L'application se fermera via le dialogue.
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        // L'utilisateur a refusé la permission de manière permanente.
        // On le guide vers les paramètres.
        await showDialog(
          context: context,
          barrierDismissible: false, // L'utilisateur doit faire un choix
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Permission de localisation requise'),
            content: const Text(
                'La permission de localisation a été refusée de manière permanente. Veuillez l\'activer dans les paramètres pour utiliser l\'application.'),
            actions: <Widget>[
              TextButton(
                child: const Text('Quitter'),
                onPressed: () {                  
                  Navigator.of(context).pop(); // Ferme juste la boite de dialogue
                  // Sur le web, on ne peut pas fermer l'onglet, donc on ne fait rien de plus.
                  if (!kIsWeb) {
                    if (Platform.isAndroid) {
                      SystemNavigator.pop();
                    } else if (Platform.isIOS) {
                      // ATTENTION: exit(0) est fortement déconseillé par Apple et
                      // peut mener au rejet de l'application sur l'App Store.
                      exit(0); // À utiliser avec prudence.
                    }
                  }
                },
              ),
              TextButton(
                child: const Text('Ouvrir les paramètres'),
                onPressed: () => openAppSettings(),
              ),
            ],
          ),
        );
      }
      return; // Bloque l'exécution jusqu'à ce que l'utilisateur agisse.
    }

    // Les permissions sont accordées, on peut continuer.
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100, // en mètres, pour ne pas envoyer de données trop souvent
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) => _sendGeolocation(position),
      onError: (e) {
        debugPrint('Erreur de géolocalisation: $e');
      },
    );
  }

  Future<void> _showExitDialog(String title, String content) async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // L'utilisateur doit interagir avec le dialogue.
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Quitter'),
              onPressed: () {
                Navigator.of(context).pop(); // Ferme le dialogue
                if (!kIsWeb) {
                  if (Platform.isAndroid) {
                    SystemNavigator.pop();
                  } else if (Platform.isIOS) {
                    // ATTENTION: exit(0) est fortement déconseillé par Apple et
                    // peut mener au rejet de l'application sur l'App Store.
                    exit(0);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendGeolocation(Position position) async {
    if (_tracteur == null || _idLigneTransport == null) return;

    try {
      await _firestore.collection('ops_ligne_gps').add({
        'Tracteur': _tracteur,
        'id-ligne-transport': _idLigneTransport,
        'position': GeoPoint(position.latitude, position.longitude),
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      // Affiche une erreur dans la console si l'envoi échoue,
      // sans interrompre l'utilisateur.
      debugPrint("Erreur lors de l'envoi de la géolocalisation: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: StreamBuilder<QuerySnapshot>(
        stream: _operationStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucune opération trouvée.', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Se déconnecter'),
                    onPressed: () async => await _auth.signOut(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 169, 5, 5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                  ),
                ],
              ),
            );
          }

          final doc = snapshot.data!.docs.first;
          _operationDocId = doc.id;
          final data = doc.data() as Map<String, dynamic>;

          // Mettre à jour les informations pour la géolocalisation à chaque reconstruction
          // pour s'assurer qu'elles sont toujours à jour.
          _tracteur = data['Tracteur'] as String?;
          _driverName = data['Driver'] as String?;
          _idLigneTransport = data['ID_Ligne_Transport'] as String?;
          _refLigneTransport = data['Ref_Ligne_Transport'] as String?;

          // Démarrer la géolocalisation si ce n'est pas déjà fait
          if (_positionStreamSubscription == null) {
            // On vérifie une nouvelle fois ici car les champs peuvent être nuls
            // et on ne veut démarrer le stream qu'une seule fois avec des données valides.
            if (_tracteur != null && _idLigneTransport != null) {
              _initGeolocation();
            }
          }

          return _buildUI(context, data);
        },
      ),
      floatingActionButton: _buildEmergencyButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildUI(BuildContext context, Map<String, dynamic> data) {
    final String driverName = _driverName ?? 'Chauffeur';
    final String? profileImageUrl = data['image_driver'] as String?;
    final String driverTractorCode = _tracteur ?? 'N/A';
    final String currentStatus = data['statut_driver'] ?? '';
    final String lieuChargement = data['Lieu_Chargement'] ?? '?';
    final String lieuDechargement = data['Lieu_Dechargement'] ?? '?';

    // Récupérer le type de trajet et vérifier si le déchargement est terminé
    final String typeTrajet = data['Type_Trajet'] as String? ?? 'Allée';
    final String refLigneTransport = _refLigneTransport ?? 'Référence non définie';
    final bool isDechargementTermine = currentStatus == 'Déchargement terminé';

    return Column(
      children: [
        _buildHeader(context, driverName, driverTractorCode, profileImageUrl),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildTaskCard(
                  refLigneTransport: refLigneTransport,
                  lieuChargement: lieuChargement,
                  lieuDechargement: lieuDechargement,
                  typeTrajet: typeTrajet,
                ),
                _buildProgressLine(currentStatus), // This will now fill from Left to Right
                const SizedBox(height: 12),
                _buildStatusButtons(currentStatus),
                if (typeTrajet == 'Allée_Retour' && isDechargementTermine)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    child: _buildReturnTripUI(data),
                  ),
                const SizedBox(height: 24),
                _buildSecondaryActions(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String driverName, String driverTractorCode, String? imageUrl) {
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 169, 5, 5),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Matricule: $driverTractorCode',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () async {
                      // On arrête le suivi de la localisation avant de se déconnecter
                      await _positionStreamSubscription?.cancel();
                      _positionStreamSubscription = null;
                      await _auth.signOut();
                      if (!mounted) return;
                      // Rediriger vers la page de connexion et supprimer l'historique de navigation
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const AuthScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 42,
                  backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                  child: (imageUrl == null || imageUrl.isEmpty)
                      ? const Icon(Icons.camera_alt, size: 36, color: Colors.grey)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required String refLigneTransport,
    required String lieuChargement,
    required String lieuDechargement,
    required String typeTrajet,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 169, 5, 5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                refLigneTransport,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            typeTrajet,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // From
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.arrow_circle_up_outlined, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Chargement", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            lieuChargement,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // To
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Déchargement", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            lieuDechargement,
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_circle_down_outlined, color: Colors.white, size: 22),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine(String currentStatus) {
    int index = _statuses.indexWhere((s) => s.label == currentStatus);
    double progress = (index + 1) / _statuses.length;
    progress = progress.clamp(0.0, 1.0);

    // Utilisation de LayoutBuilder et AnimatedContainer pour une barre de progression
    // animée et fluide qui se remplit de gauche à droite.
    return Container(
      height: 8,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(color: Colors.grey.shade300),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  width: constraints.maxWidth * progress,
                  color: const Color.fromARGB(255, 169, 5, 5),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusButtons(String currentStatus) {
    int currentIndex = _statuses.indexWhere((s) => s.label == currentStatus);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(_statuses.length, (index) {
        final statusInfo = _statuses[index];
        final isDone = index <= currentIndex;
        // Le bouton est activé s'il s'agit de la prochaine étape.
        final isEnabled = index == currentIndex + 1;
        VoidCallback? onPressedAction;

        if (isEnabled) {
          if (statusInfo.label == 'Chargé') {
            onPressedAction = () => _pickAndUploadJustificatif('Upload_Chargement', 'Chargé');
          } else if (statusInfo.label == 'Déchargement terminé') {
            onPressedAction = () => _pickAndUploadJustificatif('Upload_Dechargement', 'Déchargement terminé');
          } else {
            onPressedAction = () => _updateDriverStatus(statusInfo.label);
          }
        }

        // Affiche la couleur de base pour les étapes terminées et la suivante,
        // et une version estompée pour les étapes futures.
        final buttonColor = isDone || isEnabled
            ? statusInfo.color
            : statusInfo.color.withOpacity(0.4);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ElevatedButton(
              onPressed: onPressedAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                disabledBackgroundColor: buttonColor, // Important pour que le bouton désactivé garde sa couleur
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    statusInfo.icon,
                    size: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusInfo.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSecondaryActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _uploadDocumentImages,
            icon: const Icon(Icons.folder_copy_outlined),
            label: const Text('Documents'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 169, 5, 5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.info_outline),
            label: const Text('Détails'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              disabledForegroundColor: Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyButton() {
    return FloatingActionButton(
      onPressed: _isUploadingNote ? null : _toggleRecording,
      backgroundColor: Colors.red.shade700,
      shape: const CircleBorder(),
      child: _isUploadingNote
          ? const Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 30,
            ),
    );
  }

  Widget _buildReturnTripUI(Map<String, dynamic> data) {
    final String returnStatus = data['statut_retour'] as String? ?? '';

    return Column(
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Trajet Retour",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        _buildReturnProgressLine(returnStatus),
        const SizedBox(height: 12),
        _buildReturnStatusButtons(returnStatus),
      ],
    );
  }

  Widget _buildReturnProgressLine(String currentStatus) {
    int index = _returnStatuses.indexWhere((s) => s.label == currentStatus);
    double progress = (index + 1) / _returnStatuses.length;
    progress = progress.clamp(0.0, 1.0);

    return Container(
      height: 8,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(color: Colors.grey.shade300),
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    width: constraints.maxWidth * progress,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReturnStatusButtons(String currentStatus) {
    int currentIndex = _returnStatuses.indexWhere((s) => s.label == currentStatus);

    final retourStatus = _returnStatuses[0];
    final arriveStatus = _returnStatuses[1];

    bool isRetourEnabled = currentIndex < 0;
    bool isArriveEnabled = currentIndex == 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: isRetourEnabled ? () => _updateReturnStatus(retourStatus.label) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: retourStatus.color,
                disabledBackgroundColor: retourStatus.color.withOpacity(0.5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Column(
                children: [
                  Icon(retourStatus.icon, size: 30),
                  const SizedBox(height: 8),
                  const Text('En Retour'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: isArriveEnabled ? () => _pickAndUploadRestitution('Upload_Restitution', arriveStatus.label) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: arriveStatus.color,
                disabledBackgroundColor: arriveStatus.color.withOpacity(0.5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Column(
                children: [
                  Icon(arriveStatus.icon, size: 30),
                  const SizedBox(height: 8),
                  const Text('Arrivé'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}