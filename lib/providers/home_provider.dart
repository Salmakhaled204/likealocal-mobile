import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';

/// Caching keys used in SharedPreferences.
const _kCachedPlaces = 'cached_places_v1';
const _kCachedRecommendations = 'cached_recommendations_v1';

class HomeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _placesCacheKey = 'cached_home_places';

  List<Place> _places = [];
  List<Place> _personalizedRecommendations = [];
  bool _isLoading = false;
  bool _isLoadingRecommendations = false;
  String? _errorMessage;

  /// True when the current data was loaded from cache (no internet).
  bool _isOffline = false;

  List<Place> get places => _places;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  bool get isPersonalized => _personalizedRecommendations.isNotEmpty;
  bool get isOffline => _isOffline;

  List<Place> get recommendations =>
      isPersonalized ? _personalizedRecommendations : basicRecommendations;

  // ── Serialisation helpers ─────────────────────────────────────────────────

  /// Converts a Place into a JSON-serialisable map.
  /// We only persist the fields that Place.fromFirestore also reads.
  static Map<String, dynamic> _placeToJson(Place p) {
    return {
      'id': p.id,
      'title': p.title,
      'description': p.description,
      'category': p.category,
      'imageUrls': p.imageUrls,
      'videoUrls': p.videoUrls,
      'location': {
        'latitude': p.location.latitude,
        'longitude': p.location.longitude,
      },
      'address': p.address,
      'budget': p.budget,
      'atmosphere': p.atmosphere,
      'localTip': p.localTip,
      'recommendedDish': p.recommendedDish,
      'ownerId': p.ownerId,
      'createdByName': p.ownerName,
      'ownerIsSuperUser': p.ownerIsSuperUser,
      'averageRating': p.averageRating,
      'reviewCount': p.reviewCount,
    };
  }

  /// Reconstructs a Place from the cached JSON map (no DocumentSnapshot needed).
  static Place _placeFromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    return Place(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'Other',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      videoUrls: List<String>.from(json['videoUrls'] ?? []),
      location: GeoPoint(
        (loc['latitude'] as num?)?.toDouble() ?? 0.0,
        (loc['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      address: json['address'] ?? '',
      budget: json['budget'] ?? '',
      atmosphere: json['atmosphere'] ?? '',
      localTip: json['localTip'] ?? '',
      recommendedDish: json['recommendedDish'] ?? '',
      ownerId: json['ownerId'] ?? '',
      ownerName: json['createdByName'] ?? json['ownerName'] ?? 'Local contributor',
      ownerIsSuperUser: json['ownerIsSuperUser'] ?? false,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }

  static List<Place> _sortPlaces(List<Place> list) {
    return list
      ..sort((a, b) {
        if (a.ownerIsSuperUser != b.ownerIsSuperUser) {
          return a.ownerIsSuperUser ? -1 : 1;
        }
        return b.averageRating.compareTo(a.averageRating);
      });
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────

  Future<void> _savePlacesToCache(List<Place> places) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = places.map(_placeToJson).toList();
      await prefs.setString(_kCachedPlaces, jsonEncode(jsonList));
    } catch (e) {
      if (kDebugMode) print('HomeProvider._savePlacesToCache: $e');
    }
  }

  Future<List<Place>> _loadPlacesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCachedPlaces);
      if (raw == null || raw.isEmpty) return [];
      final jsonList = jsonDecode(raw) as List<dynamic>;
      return jsonList
          .map((e) => _placeFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('HomeProvider._loadPlacesFromCache: $e');
      return [];
    }
  }

  Future<void> _saveRecommendationsToCache(List<Place> places) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = places.map(_placeToJson).toList();
      await prefs.setString(_kCachedRecommendations, jsonEncode(jsonList));
    } catch (e) {
      if (kDebugMode) print('HomeProvider._saveRecommendationsToCache: $e');
    }
  }

  Future<List<Place>> _loadRecommendationsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCachedRecommendations);
      if (raw == null || raw.isEmpty) return [];
      final jsonList = jsonDecode(raw) as List<dynamic>;
      return jsonList
          .map((e) => _placeFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('HomeProvider._loadRecommendationsFromCache: $e');
      return [];
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Fetch places from Firestore.  On network failure, falls back to cache.
  Future<void> fetchPlaces() async {
    _isLoading = true;
    _errorMessage = null;
    _isOffline = false;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('places').get();
      _places = _sortPlaces(snapshot.docs.map(Place.fromFirestore).toList());
      await _savePlacesToCache(_places); // persist for offline use
    } on FirebaseException catch (e) {
      // Network / Firestore error — try cache
      _errorMessage = _firestoreErrorMessage(
        e,
        'Failed to load places. Please check Firebase setup.',
      );
      if (kDebugMode) print('HomeProvider.fetchPlaces: ${e.code} ${e.message}');
      await _fallbackToCache();
    } catch (e) {
      _places = await _loadPlacesFromCache();
      _errorMessage = 'Failed to load places. Please try again.';
      if (kDebugMode) print('HomeProvider.fetchPlaces: $e');
      await _fallbackToCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fallbackToCache() async {
    final cached = await _loadPlacesFromCache();
    if (cached.isNotEmpty) {
      _places = cached;
      _isOffline = true;
      // Suppress the error message if we have cached data to show
      _errorMessage = null;
    }
  }

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

      if (prefs.length > 10) prefs = prefs.take(10).toList();

      if (prefs.isEmpty && budget.isEmpty && atmosphere.isEmpty && area.isEmpty) {
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
            .where((p) =>
                p.budget.isEmpty ||
                p.budget.toLowerCase() == budget.toLowerCase())
            .toList();
      }
      if (atmosphere.isNotEmpty) {
        matches = matches
            .where((p) =>
                p.atmosphere.isEmpty ||
                p.atmosphere.toLowerCase() == atmosphere.toLowerCase())
            .toList();
      }
      if (area.isNotEmpty) {
        matches = matches
            .where((p) =>
                p.address.toLowerCase().contains(area) ||
                p.title.toLowerCase().contains(area) ||
                p.description.toLowerCase().contains(area))
            .toList();
      }

      _personalizedRecommendations =
          _sortPlaces(matches).take(10).toList();

      await _saveRecommendationsToCache(_personalizedRecommendations);
    } catch (e) {
      // Try loading cached recommendations on error
      final cached = await _loadRecommendationsFromCache();
      _personalizedRecommendations = cached;
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
