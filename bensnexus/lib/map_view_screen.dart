import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapViewScreen extends StatefulWidget {
  final String transportLineId;

  const MapViewScreen({super.key, required this.transportLineId});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  String? _errorMessage;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(14.716677, -17.467686), // Dakar, Senegal
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _fetchAndDrawRoute();
  }

  Future<void> _fetchAndDrawRoute() async {
    try {
      final querySnapshot = await _firestore
          .collection('ops_ligne_gps')
          .where('id-ligne-transport', isEqualTo: widget.transportLineId)
          .orderBy('timestamp', descending: false)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                "Aucune donnée de trajet trouvée pour cette opération.";
          });
        }
        return;
      }

      final List<LatLng> routePoints = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final GeoPoint? position = data['position'] as GeoPoint?;
        if (position != null) {
          routePoints.add(LatLng(position.latitude, position.longitude));
        }
      }

      if (routePoints.isNotEmpty) {
        _createPolylines(routePoints);
        _createMarkers(routePoints.first, routePoints.last);
        // If map is already created, move camera. Otherwise, it will be moved in onMapCreated.
        if (_mapController != null) {
          _moveCameraToFitRoute(routePoints);
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erreur lors de la récupération du trajet : $e";
        });
      }
    }
  }

  void _createPolylines(List<LatLng> points) {
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      color: Colors.blue,
      width: 5,
      points: points,
    );
    _polylines.add(polyline);
  }

  void _createMarkers(LatLng start, LatLng end) {
    _markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: start,
        infoWindow: const InfoWindow(title: 'Départ'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );
    _markers.add(
      Marker(
        markerId: const MarkerId('end'),
        position: end,
        infoWindow: const InfoWindow(title: 'Dernière Position'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
  }

  void _moveCameraToFitRoute(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    if (points.length == 1) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: points.reduce((a, b) => LatLng(a.latitude < b.latitude ? a.latitude : b.latitude, a.longitude < b.longitude ? a.longitude : b.longitude)),
      northeast: points.reduce((a, b) => LatLng(a.latitude > b.latitude ? a.latitude : b.latitude, a.longitude > b.longitude ? a.longitude : b.longitude)),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0), // 50.0 padding
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trajet: ${widget.transportLineId}'),
        backgroundColor: const Color.fromARGB(255, 169, 5, 5),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              // If points were loaded before map was ready, move camera now.
              if (!_isLoading && _polylines.isNotEmpty) {
                _moveCameraToFitRoute(_polylines.first.points);
              }
            },
            polylines: _polylines,
            markers: _markers,
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}