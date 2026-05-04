import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/place.dart';
import '../widgets/place_card.dart';
import 'place_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<List<Place>> _loadFavoritePlaces(List<QueryDocumentSnapshot> docs) async {
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
            location: data['location'] ?? const GeoPoint(0, 0),
            ownerId: data['ownerId'] ?? '',
            ownerIsSuperUser: data['ownerIsSuperUser'] ?? false,
            averageRating: (data['averageRating'] ?? 0.0).toDouble(),
          ),
        );
        continue;
      }

      final placeDoc =
          await FirebaseFirestore.instance.collection('places').doc(placeId).get();
      if (placeDoc.exists) places.add(Place.fromFirestore(placeDoc));
    }

    return places;
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
                    if (places.isEmpty) {
                      return const Center(
                        child: Text('Favorite places were not found.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: places.length,
                      itemBuilder: (context, index) {
                        final place = places[index];
                        return PlaceCard(
                          place: place,
                          onTap: () => _navigateToDetails(context, place),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
