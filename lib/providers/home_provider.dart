import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/place.dart';

class HomeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Place> _places = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Place> get places => _places;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetch places with sorting: super users first, then by rating
  Future<void> fetchPlaces() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Using serverAndCache allows Firestore to return cached data if offline
      final querySnapshot = await _firestore
          .collection('places')
          .orderBy('ownerIsSuperUser', descending: true)
          .orderBy('averageRating', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      _places = querySnapshot.docs.map((doc) => Place.fromFirestore(doc)).toList();
    } catch (e) {
      // If fetching fails entirely (e.g., no cache and offline), handle error
      _errorMessage = 'Failed to load places. Please check your connection.';
      if (kDebugMode) {
        print('Error fetching places: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Basic mock recommendations (would normally be based on user preferences)
  List<Place> get basicRecommendations {
    // For demo purposes, returning the top rated places as basic recommendations
    if (_places.isEmpty) return [];
    
    final sortedByRating = List<Place>.from(_places)
      ..sort((a, b) => b.averageRating.compareTo(a.averageRating));
      
    return sortedByRating.take(5).toList();
  }
}
