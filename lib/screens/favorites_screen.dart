import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';
import '../theme/app_theme.dart';
import '../widgets/place_card.dart';
import 'place_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  static const _cacheKey = 'cached_favorite_places';

  Future<List<Place>> _loadFavoritePlaces(
      List<QueryDocumentSnapshot> docs) async {
    final places = <Place>[];
    for (final fav in docs) {
      final data = fav.data() as Map<String, dynamic>;
      final placeId = (data['placeId'] ?? fav.id) as String;
      if (data.containsKey('title')) {
        places.add(Place(
          id: placeId,
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          category: data['category'] ?? 'Other',
          imageUrls: List<String>.from(data['imageUrls'] ?? []),
          videoUrls: List<String>.from(data['videoUrls'] ?? []),
          location: data['location'] ?? const GeoPoint(0, 0),
          address: data['address'] ?? '',
          budget: data['budget'] ?? '',
          atmosphere: data['atmosphere'] ?? '',
          localTip: data['localTip'] ?? '',
          recommendedDish: data['recommendedDish'] ?? '',
          bestTime: data['bestTime'] ?? '',
          openingHours: data['openingHours'] ?? '',
          viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
          ownerId: data['ownerId'] ?? '',
          ownerName: data['createdByName'] ?? data['ownerName'] ?? '',
          ownerIsSuperUser: data['ownerIsSuperUser'] ?? false,
          averageRating: (data['averageRating'] ?? 0.0).toDouble(),
          reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
        ));
        continue;
      }
      final placeDoc = await FirebaseFirestore.instance
          .collection('places')
          .doc(placeId)
          .get();
      if (placeDoc.exists) places.add(Place.fromFirestore(placeDoc));
    }
    return places;
  }

  Future<void> _cache(List<Place> places) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _cacheKey,
        jsonEncode(places
            .map((p) => {
                  'id': p.id,
                  'title': p.title,
                  'description': p.description,
                  'category': p.category,
                  'imageUrls': p.imageUrls,
                  'videoUrls': p.videoUrls,
                  'latitude': p.location.latitude,
                  'longitude': p.location.longitude,
                  'address': p.address,
                  'budget': p.budget,
                  'atmosphere': p.atmosphere,
                  'localTip': p.localTip,
                  'recommendedDish': p.recommendedDish,
                  'bestTime': p.bestTime,
                  'openingHours': p.openingHours,
                  'viewCount': p.viewCount,
                  'ownerId': p.ownerId,
                  'ownerName': p.ownerName,
                  'ownerIsSuperUser': p.ownerIsSuperUser,
                  'averageRating': p.averageRating,
                  'reviewCount': p.reviewCount,
                })
            .toList()));
  }

  Future<List<Place>> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) {
      final d = item as Map<String, dynamic>;
      return Place(
        id: d['id'] ?? '',
        title: d['title'] ?? '',
        description: d['description'] ?? '',
        category: d['category'] ?? 'Other',
        imageUrls: List<String>.from(d['imageUrls'] ?? []),
        videoUrls: List<String>.from(d['videoUrls'] ?? []),
        location: GeoPoint(
          (d['latitude'] as num?)?.toDouble() ?? 0,
          (d['longitude'] as num?)?.toDouble() ?? 0,
        ),
        address: d['address'] ?? '',
        budget: d['budget'] ?? '',
        atmosphere: d['atmosphere'] ?? '',
        localTip: d['localTip'] ?? '',
        recommendedDish: d['recommendedDish'] ?? '',
        bestTime: d['bestTime'] ?? '',
        openingHours: d['openingHours'] ?? '',
        viewCount: (d['viewCount'] as num?)?.toInt() ?? 0,
        ownerId: d['ownerId'] ?? '',
        ownerName: d['ownerName'] ?? '',
        ownerIsSuperUser: d['ownerIsSuperUser'] ?? false,
        averageRating: (d['averageRating'] as num?)?.toDouble() ?? 0,
        reviewCount: (d['reviewCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  void _goToDetails(BuildContext context, Place place) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 56, 22, 28),
            decoration: const BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Saved Places', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text('Your personal collection', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white60)),
                ]),
                const Spacer(),
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
                  child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),

          Expanded(
            child: user == null
                ? _buildNotLoggedIn()
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('favorites')
                        .orderBy('savedAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                      }
                      if (snapshot.hasError) {
                        return FutureBuilder<List<Place>>(
                          future: _loadCached(),
                          builder: (context, cacheSnap) {
                            final cached = cacheSnap.data ?? [];
                            if (cached.isEmpty) return _buildError();
                            return _buildList(context, cached, offline: true);
                          },
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) return _buildEmpty();
                      return FutureBuilder<List<Place>>(
                        future: _loadFavoritePlaces(docs),
                        builder: (context, placesSnap) {
                          if (placesSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                          }
                          final places = placesSnap.data ?? [];
                          if (places.isNotEmpty) _cache(places);
                          if (places.isEmpty) return _buildEmpty();
                          return _buildList(context, places);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Place> places, {bool offline = false}) {
    final avgRating = places.isEmpty ? 0.0 : places.map((p) => p.averageRating).reduce((a, b) => a + b) / places.length;
    final superCount = places.where((p) => p.ownerIsSuperUser).length;

    return Column(
      children: [
        if (offline)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppTheme.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3))),
            child: Row(children: [Icon(Icons.wifi_off_rounded, color: AppTheme.amber, size: 16), const SizedBox(width: 8), Text('Offline — showing cached favorites', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.amber))]),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(children: [
            _StatChip(label: '${places.length}', sublabel: 'Places', icon: Icons.place_outlined, color: AppTheme.primary),
            const SizedBox(width: 12),
            _StatChip(label: avgRating.toStringAsFixed(1), sublabel: 'Avg Rating', icon: Icons.star_rounded, color: AppTheme.amber),
            const SizedBox(width: 12),
            _StatChip(label: '$superCount', sublabel: 'Super User', icon: Icons.workspace_premium_rounded, color: AppTheme.accent),
          ]),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount: places.length,
            itemBuilder: (context, i) => PlaceCard(place: places[i], onTap: () => _goToDetails(context, places[i])),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle), child: const Icon(Icons.favorite_border_rounded, size: 42, color: AppTheme.primary)),
        const SizedBox(height: 20),
        Text('No saved places yet', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        Text('Tap the heart on any place to save it', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textLight), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle), child: const Icon(Icons.lock_outline_rounded, size: 40, color: AppTheme.primary)),
        const SizedBox(height: 16),
        Text('Log in to view favorites', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
      ]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: AppTheme.errorColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.errorColor)),
        const SizedBox(height: 12),
        Text('Could not load favorites', style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textMid)),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, sublabel;
  final IconData icon;
  final Color color;
  const _StatChip({required this.label, required this.sublabel, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            Text(sublabel, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textLight)),
          ])),
        ]),
      ),
    );
  }
}
