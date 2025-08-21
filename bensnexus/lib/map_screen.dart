import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  final String idLigneTransport;

  const MapScreen({super.key, required this.idLigneTransport});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final List<LatLng> _routeCoordinates = [];
  bool _isLoading = true;
  String? _errorMessage;
  // Position par défaut (Paris), sera mise à jour avec le premier point GPS.
  LatLng _initialCameraPosition = const LatLng(48.8566, 2.3522);
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _fetchGpsData();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Si les données sont déjà chargées lorsque la carte est créée, on ajuste la caméra.
    if (!_isLoading && _routeCoordinates.isNotEmpty) {
      _moveCameraToFitRoute();
    }
  }

  void _moveCameraToFitRoute() {
    if (_routeCoordinates.isEmpty || _mapController == null) return;

    if (_routeCoordinates.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_routeCoordinates.first, 15),
      );
      return;
    }

    double minLat = _routeCoordinates.first.latitude;
    double maxLat = _routeCoordinates.first.latitude;
    double minLng = _routeCoordinates.first.longitude;
    double maxLng = _routeCoordinates.first.longitude;

    for (final point in _routeCoordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60.0), // 60.0 de padding
    );
  }

  Future<void> _fetchGpsData() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('ops_ligne_gps')
          .where('id-ligne-transport', isEqualTo: widget.idLigneTransport)
          .orderBy('timestamp', descending: false)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final position = data['position'] as GeoPoint?;
          if (position != null) {
            _routeCoordinates.add(LatLng(position.latitude, position.longitude));
          }
        }

        if (_routeCoordinates.isNotEmpty) {
          _initialCameraPosition = _routeCoordinates.first;

          // Ajouter un marqueur pour chaque point du trajet
          for (var i = 0; i < _routeCoordinates.length; i++) {
            final point = _routeCoordinates[i];
            String title;
            BitmapDescriptor icon;

            if (i == 0) {
              title = 'Début du trajet';
              icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
            } else if (i == _routeCoordinates.length - 1) {
              title = 'Dernière position';
              icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
            } else {
              // Utiliser des marqueurs plus petits pour les points intermédiaires
              // Pour les différencier, on peut les rendre semi-transparents ou utiliser une autre couleur
              title = 'Point ${i + 1}';
              icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
            }

            _markers.add(Marker(
              markerId: MarkerId('point_$i'),
              position: point,
              infoWindow: InfoWindow(title: title, snippet: 'Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}'),
              icon: icon,
            ));
          }

          final polyline = Polyline(
            polylineId: const PolylineId('route'),
            points: _routeCoordinates,
            color: const Color.fromARGB(255, 169, 5, 5), // Couleur thème de l'app
            width: 5,
          );
          _polylines.add(polyline);
        }
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération des données GPS: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Erreur de chargement du trajet.\nCause possible : Index Firestore manquant. Veuillez vérifier la console de débogage pour un lien de création d'index.";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // Une fois les données chargées, on ajuste la caméra si la carte est prête.
        if (_mapController != null && _routeCoordinates.isNotEmpty) {
          _moveCameraToFitRoute();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualisation du Trajet'),
        backgroundColor: const Color.fromARGB(255, 169, 5, 5),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _initialCameraPosition,
              zoom: 7,
            ),
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (!_isLoading && _errorMessage == null && _routeCoordinates.isEmpty)
            const Center(
              child: Text('Aucune donnée de trajet disponible.', style: TextStyle(fontSize: 16)),
            ),
          if (_errorMessage != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_errorMessage!,
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }
}