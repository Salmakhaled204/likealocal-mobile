import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/place.dart';

/// Manages the main place feed and personalised recommendations
/// for the Home & Discovery domain.
class HomeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── State ────────────────────────────────────────────────────────────────
  List<Place> _places = [];
  List<Place> _personalizedRecommendations = [];
  bool _isLoading = false;
  bool _isLoadingRecommendations = false;
  String? _errorMessage;

  // ── Public getters ───────────────────────────────────────────────────────
  List<Place> get places => _places;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoadingRecommendations => _isLoadingRecommendations;

  /// `true` when Firestore returned at least one personalised recommendation
  /// (i.e. the user has preferences and places matched them).
  /// Use this instead of a list-identity comparison in the UI.
  bool get isPersonalized => _personalizedRecommendations.isNotEmpty;

  /// Returns the personalised list when available, otherwise falls back to
  /// the top-rated items already in the feed.
  List<Place> get recommendations =>
      isPersonalized ? _personalizedRecommendations : basicRecommendations;

  // ── Main feed ────────────────────────────────────────────────────────────

  /// Fetches the main place feed ordered by super-user status then rating.
  ///
  /// Requires a Firestore composite index on collection `places`:
  ///   Field 1: ownerIsSuperUser – Descending
  ///   Field 2: averageRating    – Descending
  /// (See walkthrough for Firebase Console steps.)
  Future<void> fetchPlaces() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('places')
          .orderBy('ownerIsSuperUser', descending: true)
          .orderBy('averageRating', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      _places = snapshot.docs.map(Place.fromFirestore).toList();
    } catch (e) {
      _errorMessage = 'Failed to load places. Please check your connection.';
      if (kDebugMode) print('HomeProvider.fetchPlaces: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Personalised recommendations ─────────────────────────────────────────

  /// Reads the logged-in user's `preferences` string array from
  /// `users/{uid}` in Firestore, then queries places whose `category`
  /// matches any preference.
  ///
  /// Keeping this logic inside the provider (not the screen) means:
  ///   • The screen stays thin and has no direct Firestore dependency.
  ///   • This method is independently unit-testable.
  ///   • No leaky `firestore` public getter needed.
  ///
  /// Call from `HomeScreen.initState` after [fetchPlaces]:
  ///   await homeProvider.fetchPersonalizedRecommendationsForUser(uid);
  Future<void> fetchPersonalizedRecommendationsForUser(String uid) async {
    _isLoadingRecommendations = true;
    notifyListeners();

    try {
      // 1. Load user preferences from Firestore.
      final userDoc =
          await _firestore.collection('users').doc(uid).get();

      final data = userDoc.data(); // already Map<String,dynamic>? — no cast needed
      var prefs = List<String>.from(data?['preferences'] ?? []);
      
      // Enforce Firestore's 10-item limit for `whereIn` queries
      if (prefs.length > 10) {
        prefs = prefs.take(10).toList();
      }

      if (prefs.isEmpty) {
        // No preferences set → fall back to basicRecommendations silently.
        _personalizedRecommendations = [];
        return;
      }

      // 2. Query places matching any preference category.
      //    Requires a composite index: category ASC + averageRating DESC.
      final snapshot = await _firestore
          .collection('places')
          .where('category', whereIn: prefs)
          .orderBy('averageRating', descending: true)
          .limit(10)
          .get(const GetOptions(source: Source.serverAndCache));

      _personalizedRecommendations =
          snapshot.docs.map(Place.fromFirestore).toList();
    } catch (e) {
      // Non-fatal: the UI falls back to basicRecommendations automatically.
      _personalizedRecommendations = [];
      if (kDebugMode) {
        print('HomeProvider.fetchPersonalizedRecommendationsForUser: $e');
      }
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  // ── Fallback recommendations ─────────────────────────────────────────────

  /// Top-5 highest-rated places from the already-loaded feed.
  /// Used when [isPersonalized] is `false`.
  List<Place> get basicRecommendations {
    if (_places.isEmpty) return [];
    final sorted = List<Place>.from(_places)
      ..sort((a, b) => b.averageRating.compareTo(a.averageRating));
    return sorted.take(5).toList();
  }
}
