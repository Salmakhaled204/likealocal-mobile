import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';

class HomeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _placesCacheKey = 'cached_home_places';

  List<Place> _places = [];
  List<Place> _personalizedRecommendations = [];
  bool _isLoading = false;
  bool _isLoadingRecommendations = false;
  String? _errorMessage;

  List<Place> get places => _places;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  bool get isPersonalized => _personalizedRecommendations.isNotEmpty;

  List<Place> get recommendations =>
      isPersonalized ? _personalizedRecommendations : basicRecommendations;

  Future<void> fetchPlaces() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('places').get();

      _places = snapshot.docs.map(Place.fromFirestore).toList()
        ..sort((a, b) {
          if (a.ownerIsSuperUser != b.ownerIsSuperUser) {
            return a.ownerIsSuperUser ? -1 : 1;
          }
          return b.averageRating.compareTo(a.averageRating);
        });
      await _cachePlaces(_places);
    } on FirebaseException catch (e) {
      _places = await _loadCachedPlaces();
      _errorMessage = _firestoreErrorMessage(
        e,
        'Failed to load places. Please check Firebase setup.',
      );
      if (kDebugMode) print('HomeProvider.fetchPlaces: ${e.code} ${e.message}');
    } catch (e) {
      _places = await _loadCachedPlaces();
      _errorMessage = 'Failed to load places. Please try again.';
      if (kDebugMode) print('HomeProvider.fetchPlaces: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _cachePlaces(List<Place> places) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _placesCacheKey,
      jsonEncode(places.map(_placeToJson).toList()),
    );
  }

  Future<List<Place>> _loadCachedPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_placesCacheKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return items.map(_placeFromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _placeToJson(Place place) => {
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
  };

  Place _placeFromJson(Map<String, dynamic> data) => Place(
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
    ownerName: data['createdByName'] ?? data['ownerName'] ?? 'Local contributor',
    ownerIsSuperUser: data['ownerIsSuperUser'] ?? false,
    averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0,
    reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
  );

  Future<void> fetchPersonalizedRecommendationsForUser(String uid) async {
    _isLoadingRecommendations = true;
    notifyListeners();

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final data = userDoc.data();
      var prefs = List<String>.from(data?['preferences'] ?? []);
      final budget = (data?['budgetPreference'] ?? '').toString();
      final atmosphere = (data?['atmospherePreference'] ?? '').toString();
      final area = (data?['areaPreference'] ?? '').toString().toLowerCase();

      if (prefs.length > 10) {
        prefs = prefs.take(10).toList();
      }

      if (prefs.isEmpty &&
          budget.isEmpty &&
          atmosphere.isEmpty &&
          area.isEmpty) {
        _personalizedRecommendations = [];
        return;
      }

      final query = prefs.isEmpty
          ? _firestore.collection('places').limit(100)
          : _firestore
                .collection('places')
                .where('category', whereIn: prefs)
                .limit(100);

      final snapshot = await query.get();
      var matches = snapshot.docs.map(Place.fromFirestore).toList();

      if (budget.isNotEmpty) {
        matches = matches
            .where(
              (p) =>
                  p.budget.isEmpty ||
                  p.budget.toLowerCase() == budget.toLowerCase(),
            )
            .toList();
      }
      if (atmosphere.isNotEmpty) {
        matches = matches
            .where(
              (p) =>
                  p.atmosphere.isEmpty ||
                  p.atmosphere.toLowerCase() == atmosphere.toLowerCase(),
            )
            .toList();
      }
      if (area.isNotEmpty) {
        matches = matches
            .where(
              (p) =>
                  p.address.toLowerCase().contains(area) ||
                  p.title.toLowerCase().contains(area) ||
                  p.description.toLowerCase().contains(area),
            )
            .toList();
      }

      _personalizedRecommendations = matches
        ..sort((a, b) {
          if (a.ownerIsSuperUser != b.ownerIsSuperUser) {
            return a.ownerIsSuperUser ? -1 : 1;
          }
          return b.averageRating.compareTo(a.averageRating);
        });
      _personalizedRecommendations = _personalizedRecommendations
          .take(10)
          .toList();
    } catch (e) {
      _personalizedRecommendations = [];
      if (kDebugMode) {
        print('HomeProvider.fetchPersonalizedRecommendationsForUser: $e');
      }
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  List<Place> get basicRecommendations {
    if (_places.isEmpty) return [];
    final sorted = List<Place>.from(_places)
      ..sort((a, b) => b.averageRating.compareTo(a.averageRating));
    return sorted.take(5).toList();
  }

  String _firestoreErrorMessage(FirebaseException e, String fallback) {
    switch (e.code) {
      case 'permission-denied':
        return 'Firestore rules are blocking places. Allow read access to places.';
      case 'unavailable':
        return 'Firebase is unavailable right now. Check your connection.';
      case 'failed-precondition':
        return 'Firestore needs setup for this query. Try again after the app update.';
      case 'not-found':
        return 'Firestore database is not created yet in Firebase Console.';
      default:
        return e.message ?? fallback;
    }
  }
}
