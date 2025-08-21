import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bensnexus/map_screen.dart';
import 'package:bensnexus/commun/authentification/screen/auth_screen.dart';
import 'package:flutter/material.dart';

class HomeScreenAdmin extends StatefulWidget {
  const HomeScreenAdmin({super.key});

  @override
  State<HomeScreenAdmin> createState() => _HomeScreenAdminState();
}

class _HomeScreenAdminState extends State<HomeScreenAdmin> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot>? _ongoingOperationsStream;
  Stream<QuerySnapshot>? _archivableOperationsStream;

  @override
  void initState() {
    super.initState();
    _ongoingOperationsStream = _firestore
        .collection('ops_ligne_transport')
        .where('Statut_Trajet', isEqualTo: 'En cours')
        .snapshots();

    _archivableOperationsStream = _firestore
        .collection('ops_ligne_transport')
        .where('statut_driver', isEqualTo: 'Déchargement terminé')
        .snapshots();
  }

  Future<void> _archiveOperation(String operationDocId) async {
    final DocumentReference originalDocRef =
        _firestore.collection('ops_ligne_transport').doc(operationDocId);
    try {
      // Utiliser une transaction pour garantir la cohérence des données.
      await _firestore.runTransaction((transaction) async {
        // 1. Lire le document de la collection originale.
        final DocumentSnapshot docSnapshot = await transaction.get(originalDocRef);

        if (!docSnapshot.exists) {
          throw Exception("Le document à archiver n'existe plus.");
        }

        final operationData = docSnapshot.data() as Map<String, dynamic>;

        // 2. Créer un nouveau document dans la collection 'historique'.
        final Map<String, dynamic> historicData = {
          ...operationData,
          'statut_driver': 'Archivée', // Mettre à jour le statut pour refléter l'archivage
          'date_archivage': FieldValue.serverTimestamp(),
        };

        final DocumentReference historicDocRef = _firestore.collection('historique').doc(operationDocId);
        transaction.set(historicDocRef, historicData);

        // 3. Supprimer le document de la collection originale.
        transaction.delete(originalDocRef);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opération archivée et déplacée dans l\'historique.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'archivage : $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text('Tableau de Bord Admin'),
        backgroundColor: const Color.fromARGB(255, 169, 5, 5),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              if (!mounted) return;
              // Rediriger vers la page de connexion et supprimer l'historique de navigation
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          _buildSectionTitle(context, 'Opérations à Archiver'),
          _buildOperationsList(_archivableOperationsStream, showArchiveButton: true),
          const SizedBox(height: 16),
          const Divider(thickness: 1),
          const SizedBox(height: 16),
          _buildSectionTitle(context, 'Opérations en cours'),
          _buildOperationsList(_ongoingOperationsStream, showArchiveButton: false),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildOperationsList(Stream<QuerySnapshot>? stream, {required bool showArchiveButton}) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(showArchiveButton ? 'Aucune opération à archiver.' : 'Aucune opération en cours.'),
          ));
        }

        final operations = snapshot.data!.docs;

        return Column(
          children: operations.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _buildOperationCard(context, doc.id, data, showArchiveButton: showArchiveButton);
          }).toList(),
        );
      },
    );
  }

  Widget _buildOperationCard(BuildContext context, String docId, Map<String, dynamic> data, {required bool showArchiveButton}) {
    final String driverName = data['Driver'] ?? 'Chauffeur';
    final String? profileImageUrl = data['image_driver'] as String?;
    final String driverTractorCode = data['Tracteur'] ?? 'N/A';
    final String? idLigne = data['ID_Ligne_Transport'] as String?;
    final String lieuChargement = data['Lieu_Chargement'] ?? '?';
    final String lieuDechargement = data['Lieu_Dechargement'] ?? '?';
    final String description = data['description'] ?? 'Pas de description.';
    final String typeTrajet = data['Type_Trajet'] as String? ?? 'Allée';

    // Logique pour l'archivage conditionnel
    final String statutRetour = data['statut_retour'] as String? ?? '';
    final String statutDriver = data['statut_driver'] as String? ?? '';

    bool canArchive;
    if (typeTrajet == 'Allée_Retour') {
      // Pour un 'Allée_Retour', on archive seulement quand le retour est terminé
      canArchive = (statutRetour == 'Arrivé en restitution');
    } else {
      // Pour les 'Allée' ou 'Retour' simples, on archive dès que le déchargement est terminé
      canArchive = (statutDriver == 'Déchargement terminé');
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: const Color.fromARGB(255, 169, 5, 5),
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.white,
                  backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty) ? NetworkImage(profileImageUrl) : null,
                  child: (profileImageUrl == null || profileImageUrl.isEmpty)
                      ? const Icon(Icons.person, size: 30, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Matricule: $driverTractorCode',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  idLigne ?? 'ID non défini',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildLocationInfo('Chargement', lieuChargement)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                    ),
                    Expanded(child: _buildLocationInfo('Déchargement', lieuDechargement)),
                  ],
                ),
                // Affiche le statut du retour si c'est un transport de type Allée_Retour
                if (typeTrajet == 'Allée_Retour') ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildReturnStatusInfo(statutRetour),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: idLigne != null
                          ? () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => MapScreen(idLigneTransport: idLigne),
                              ));
                            }
                          : null,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Voir Trajet'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color.fromARGB(255, 169, 5, 5)),
                        foregroundColor: const Color.fromARGB(255, 169, 5, 5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (showArchiveButton) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: canArchive ? () => _archiveOperation(docId) : null,
                        icon: const Icon(Icons.inventory_2),
                        label: const Text('Archiver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.purple.withOpacity(0.4),
                          disabledForegroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo(String label, String location) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          location,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Construit un widget pour afficher le statut du trajet retour.
  Widget _buildReturnStatusInfo(String status) {
    IconData icon;
    Color color;
    String text = status.isNotEmpty ? status : "En attente du retour";

    switch (status) {
      case 'En retour':
        icon = Icons.undo;
        color = Colors.orange.shade700;
        break;
      case 'Arrivé en restitution':
        icon = Icons.local_parking;
        color = Colors.teal;
        break;
      default:
        icon = Icons.hourglass_empty;
        color = Colors.grey.shade600;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          "Statut Retour:",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800),
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}