import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';
import '../widgets/place_card.dart';
import 'place_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  static const _cacheKey = 'cached_favorite_places';

  Future<List<Place>> _loadFavoritePlaces(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final places = <Place>[];

    for (final favorite in docs) {
      final data = favorite.data() as Map<String, dynamic>;
      final placeId = (data['placeId'] ?? favorite.id) as String;

      if (data.containsKey('title')) {
        places.add(
          Place(
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
            ownerId: data['ownerId'] ?? '',
            ownerName: data['createdByName'] ?? data['ownerName'] ?? '',
            ownerIsSuperUser: data['ownerIsSuperUser'] ?? false,
            averageRating: (data['averageRating'] ?? 0.0).toDouble(),
            reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
          ),
        );
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

  Future<void> _cacheFavoritePlaces(List<Place> places) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = places
        .map(
          (place) => {
            'id': place.id,
            'title': place.title,
            'description': place.description,
            'category': place.category,
            'imageUrls': place.imageUrls,
            'videoUrls': place.videoUrls,
            'latitude': place.location.latitude,
            'longitude': place.location.longitude,
            'address': place.address,
            'budget': place.budget,
            'atmosphere': place.atmosphere,
            'localTip': place.localTip,
            'recommendedDish': place.recommendedDish,
            'ownerId': place.ownerId,
            'ownerName': place.ownerName,
            'ownerIsSuperUser': place.ownerIsSuperUser,
            'averageRating': place.averageRating,
            'reviewCount': place.reviewCount,
          },
        )
        .toList();
    await prefs.setString(_cacheKey, jsonEncode(payload));
  }

  Future<List<Place>> _loadCachedFavoritePlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) {
      final data = item as Map<String, dynamic>;
      return Place(
        id: data['id'] ?? '',
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        category: data['category'] ?? 'Other',
        imageUrls: List<String>.from(data['imageUrls'] ?? []),
        videoUrls: List<String>.from(data['videoUrls'] ?? []),
        location: GeoPoint(
          (data['latitude'] as num?)?.toDouble() ?? 0,
          (data['longitude'] as num?)?.toDouble() ?? 0,
        ),
        address: data['address'] ?? '',
        budget: data['budget'] ?? '',
        atmosphere: data['atmosphere'] ?? '',
        localTip: data['localTip'] ?? '',
        recommendedDish: data['recommendedDish'] ?? '',
        ownerId: data['ownerId'] ?? '',
        ownerName: data['ownerName'] ?? '',
        ownerIsSuperUser: data['ownerIsSuperUser'] ?? false,
        averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0,
        reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  void _navigateToDetails(BuildContext context, Place place) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Favorites',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: user == null
          ? const Center(child: Text('Log in to view favorites.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('favorites')
                  .orderBy('savedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return FutureBuilder<List<Place>>(
                    future: _loadCachedFavoritePlaces(),
                    builder: (context, cacheSnapshot) {
                      final cached = cacheSnapshot.data ?? [];
                      if (cached.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Could not load favorites.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: Colors.red),
                            ),
                          ),
                        );
                      }
                      return _FavoritesList(
                        places: cached,
                        onTap: (place) => _navigateToDetails(context, place),
                        offline: true,
                      );
                    },
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 72,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No favorites yet',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return FutureBuilder<List<Place>>(
                  future: _loadFavoritePlaces(docs),
                  builder: (context, placesSnapshot) {
                    if (placesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final places = placesSnapshot.data ?? [];
                    if (places.isNotEmpty) {
                      _cacheFavoritePlaces(places);
                    }
                    if (places.isEmpty) {
                      return const Center(
                        child: Text('Favorite places were not found.'),
                      );
                    }

                    return _FavoritesList(
                      places: places,
                      onTap: (place) => _navigateToDetails(context, place),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _FavoritesList extends StatelessWidget {
  final List<Place> places;
  final ValueChanged<Place> onTap;
  final bool offline;

  const _FavoritesList({
    required this.places,
    required this.onTap,
    this.offline = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: places.length + (offline ? 1 : 0),
      itemBuilder: (context, index) {
        if (offline && index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Text(
              'Showing cached favorites because Firebase is unavailable.',
              style: GoogleFonts.inter(color: Colors.orange[800], fontSize: 13),
            ),
          );
        }
        final place = places[offline ? index - 1 : index];
        return PlaceCard(place: place, onTap: () => onTap(place));
      },
    );
  }
}
