import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

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
    _StatusInfo(label: 'Chargé', icon: Icons.check, color: Colors.red),
    _StatusInfo(label: 'En route', icon: Icons.local_shipping, color: Colors.orange),
    _StatusInfo(label: 'Arrivé sur site', icon: Icons.location_on, color: Colors.blue),
    _StatusInfo(label: 'Déchargement terminé', icon: Icons.archive, color: Colors.green),
  ];

  Stream<QuerySnapshot>? _operationStream;
  String? _operationDocId;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user?.phoneNumber?.isNotEmpty == true) {
      _operationStream = _firestore
          .collection('DB_DEV_OPERATIONS')
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
      await ref.putFile(File(image.path));
      final imageUrl = await ref.getDownloadURL();

      await _firestore.collection('DB_DEV_OPERATIONS').doc(_operationDocId).set(
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
    await _firestore.collection('DB_DEV_OPERATIONS').doc(_operationDocId).set(
      {'statut_driver': newStatus},
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

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return; // L'utilisateur a annulé la sélection

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Téléchargement du justificatif...")),
      );
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref('justificatif/$_operationDocId/${firestoreFieldName}_$timestamp.jpg');
      await ref.putFile(File(image.path));
      final imageUrl = await ref.getDownloadURL();

      final operationRef = _firestore.collection('DB_DEV_OPERATIONS').doc(_operationDocId);

      await operationRef.set(
        {
          firestoreFieldName: imageUrl,
          'statut_driver': newStatus,
        },
        SetOptions(merge: true),
      );

      // Si le déchargement est terminé, on archive l'opération et on la supprime.
      if (newStatus == 'Déchargement terminé') {
        final docSnapshot = await operationRef.get();
        if (docSnapshot.exists) {
          final dataToMove = docSnapshot.data()!;
          dataToMove['date_livraison'] = FieldValue.serverTimestamp(); // Ajoute une date de fin

          // Copie dans la collection d'archives
          await _firestore.collection('ops_ligne_transport_livree').doc(_operationDocId).set(dataToMove);
          
          // Supprime de la collection active
          await operationRef.delete();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opération terminée et archivée.')),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Statut mis à jour vers "$newStatus".')));
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

        await ref.putFile(File(image.path));
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
          final dir = await getApplicationDocumentsDirectory();
          final path = '${dir.path}/note_vocale_${DateTime.now().millisecondsSinceEpoch}.m4a';

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

      final file = File(path);
      if (!await file.exists()) return;

      final fileName = file.path.split('/').last;

      // 1. Stocker l'audio dans le dossier 'audio/' de Storage
      final ref = _storage.ref('audio_incident/$fileName');
      await ref.putFile(file);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Les services de localisation sont désactivés.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission de localisation refusée.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission de localisation refusée de manière permanente. Veuillez l\'activer dans les paramètres.')),
        );
        openAppSettings();
      }
      return;
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
            return const Center(child: Text('Aucune opération trouvée.'));
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
    final String idLigne = data['ID_Ligne_Transport'] ?? 'non défini';
    final String lieuChargement = data['Lieu_Chargement'] ?? '?';
    final String lieuDechargement = data['Lieu_Dechargement'] ?? '?';
    final String description = data['description'] ?? 'Pas de description.';

    return Column(
      children: [
        _buildHeader(context, driverName, driverTractorCode, profileImageUrl),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildTaskCard(
                  idLigne: idLigne,
                  lieuChargement: lieuChargement,
                  lieuDechargement: lieuDechargement,
                  description: description,
                ),
                _buildProgressLine(currentStatus), // This will now fill from Left to Right
                const SizedBox(height: 12),
                _buildStatusButtons(currentStatus),
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
        color: Color.fromARGB(255, 7, 46, 175),
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

                      await _auth.signOut(); // AuthGate s'occupera de la redirection
                      if (mounted) {
                        // On redirige vers l'écran d'authentification et on supprime l'historique de navigation.
                        Navigator.of(context).pushNamedAndRemoveUntil('/auth', (Route<dynamic> route) => false);
                      }
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
                  onBackgroundImageError: (imageUrl != null && imageUrl.isNotEmpty) ? (_, __) {} : null,
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
    required String idLigne,
    required String lieuChargement,
    required String lieuDechargement,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 7, 46, 175),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                idLigne,
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
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lieuChargement,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                lieuDechargement,
                style: const TextStyle(color: Colors.white, fontSize: 14),
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
                  color: const Color.fromARGB(255, 7, 46, 175),
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
                padding: const EdgeInsets.all(8),
              ),
              child: Icon(
                statusInfo.icon,
                size: 28,
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
          child: OutlinedButton.icon(
            onPressed: _uploadDocumentImages,
            icon: const Icon(Icons.folder_copy_outlined, color: Colors.red),
            label: const Text('Documents', style: TextStyle(color: Color.fromARGB(255, 7, 46, 175))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.local_shipping, color: Colors.grey),
            label: const Text('Driver', style: TextStyle(color: Colors.grey)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
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
}