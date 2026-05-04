import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/place.dart';

class HomeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    } on FirebaseException catch (e) {
      _errorMessage = _firestoreErrorMessage(
        e,
        'Failed to load places. Please check Firebase setup.',
      );
      if (kDebugMode) print('HomeProvider.fetchPlaces: ${e.code} ${e.message}');
    } catch (e) {
      _errorMessage = 'Failed to load places. Please try again.';
      if (kDebugMode) print('HomeProvider.fetchPlaces: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPersonalizedRecommendationsForUser(String uid) async {
    _isLoadingRecommendations = true;
    notifyListeners();

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final data = userDoc.data();
      var prefs = List<String>.from(data?['preferences'] ?? []);

      if (prefs.length > 10) {
        prefs = prefs.take(10).toList();
      }

      if (prefs.isEmpty) {
        _personalizedRecommendations = [];
        return;
      }

      final snapshot = await _firestore
          .collection('places')
          .where('category', whereIn: prefs)
          .limit(10)
          .get();

      _personalizedRecommendations = snapshot.docs.map(Place.fromFirestore).toList()
        ..sort((a, b) => b.averageRating.compareTo(a.averageRating));
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
