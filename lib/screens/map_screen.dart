import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  LatLng? myLocation;
  bool isLoadingLocation = false;

  List<Map<String, dynamic>> places = [];
  bool isLoadingPlaces = true;

  Map<String, dynamic>? selectedPlace;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _detectLocation();
  }

  // ── Load all places from Firestore ────────────────────────
  Future<void> _loadPlaces() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('places')
          .get();

      List<Map<String, dynamic>> loaded = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        // Only add places that have a valid GeoPoint location
        if (data['location'] != null && data['location'] is GeoPoint) {
          loaded.add(data);
        }
      }

      setState(() => places = loaded);
    } catch (e) {
      debugPrint('Error loading places: $e');
    } finally {
      setState(() => isLoadingPlaces = false);
    }
  }

  // ── GPS: detect current location ─────────────────────────
  Future<void> _detectLocation() async {
    setState(() => isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackbar('Please enable GPS to use Near Me');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackbar('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackbar('Location permission permanently denied');
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        myLocation = LatLng(pos.latitude, pos.longitude);
      });
    } catch (e) {
      _showSnackbar('Could not get location');
    } finally {
      setState(() => isLoadingLocation = false);
    }
  }

  // ── Fly map to my location ────────────────────────────────
  void _goToMyLocation() {
    if (myLocation == null) {
      _detectLocation();
      return;
    }
    _mapController.move(myLocation!, 15.0);
  }

  // ── Near Me button ────────────────────────────────────────
  void _showNearMe() {
    if (myLocation == null) {
      _showSnackbar('Getting your location...');
      _detectLocation();
      return;
    }

    // Sort places by distance to user
    places.sort((a, b) {
      final geoA = a['location'] as GeoPoint;
      final geoB = b['location'] as GeoPoint;
      double distA = Geolocator.distanceBetween(
        myLocation!.latitude,
        myLocation!.longitude,
        geoA.latitude,
        geoA.longitude,
      );
      double distB = Geolocator.distanceBetween(
        myLocation!.latitude,
        myLocation!.longitude,
        geoB.latitude,
        geoB.longitude,
      );
      return distA.compareTo(distB);
    });

    setState(() {});
    _mapController.move(myLocation!, 14.0);
    _showNearMeSheet();
  }

  // ── Bottom sheet: list of nearby places ──────────────────
  void _showNearMeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Places Near You',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: places.isEmpty
                  ? const Center(child: Text('No places found'))
                  : ListView.builder(
                      itemCount: places.length > 10 ? 10 : places.length,
                      itemBuilder: (context, i) {
                        final place = places[i];
                        final geo = place['location'] as GeoPoint;

                        double distMetres = myLocation == null
                            ? 0
                            : Geolocator.distanceBetween(
                                myLocation!.latitude,
                                myLocation!.longitude,
                                geo.latitude,
                                geo.longitude,
                              );

                        String distText = distMetres < 1000
                            ? '${distMetres.toStringAsFixed(0)} m away'
                            : '${(distMetres / 1000).toStringAsFixed(1)} km away';

                        return ListTile(
                          leading: const Icon(
                            Icons.place,
                            color: Colors.orange,
                          ),
                          title: Text(place['title'] ?? 'Unnamed'),
                          subtitle: Text(distText),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context);
                            _mapController.move(
                              LatLng(geo.latitude, geo.longitude),
                              16.0,
                            );
                            setState(() => selectedPlace = place);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build place markers ───────────────────────────────────
  List<Marker> _buildPlaceMarkers() {
    return places.map((place) {
      final geo = place['location'] as GeoPoint;
      return Marker(
        point: LatLng(geo.latitude, geo.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => setState(() => selectedPlace = place),
          child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
        ),
      );
    }).toList();
  }

  // ── Build my location marker ──────────────────────────────
  List<Marker> _buildMyLocationMarker() {
    if (myLocation == null) return [];
    return [
      Marker(
        point: myLocation!,
        width: 50,
        height: 50,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Default center: Cairo
    final defaultCenter = LatLng(30.0444, 31.2357);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Map',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.near_me),
            tooltip: 'Near Me',
            onPressed: _showNearMe,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ───────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: myLocation ?? defaultCenter,
              initialZoom: 12.0,
              onTap: (tapPosition, point) =>
                  setState(() => selectedPlace = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.likealocal_mobile',
              ),
              MarkerLayer(markers: _buildPlaceMarkers()),
              MarkerLayer(markers: _buildMyLocationMarker()),
            ],
          ),

          // ── Loading spinner ───────────────────────────
          if (isLoadingPlaces) const Center(child: CircularProgressIndicator()),

          // ── Selected place card ───────────────────────
          if (selectedPlace != null)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: _buildPlaceCard(selectedPlace!),
            ),
        ],
      ),

      // ── FAB: my location ─────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        tooltip: 'My Location',
        child: isLoadingLocation
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }

  // ── Place info popup card ─────────────────────────────────
  Widget _buildPlaceCard(Map<String, dynamic> place) {
    final geo = place['location'] as GeoPoint;

    String distText = '';
    if (myLocation != null) {
      double dist = Geolocator.distanceBetween(
        myLocation!.latitude,
        myLocation!.longitude,
        geo.latitude,
        geo.longitude,
      );
      distText = dist < 1000
          ? '${dist.toStringAsFixed(0)} m away'
          : '${(dist / 1000).toStringAsFixed(1)} km away';
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    place['title'] ?? 'Unnamed',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => selectedPlace = null),
                  child: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            if ((place['category'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                place['category'],
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if ((place['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                place['description'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ],
            if (distText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.directions_walk,
                    size: 14,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    distText,
                    style: const TextStyle(color: Colors.blue, fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
