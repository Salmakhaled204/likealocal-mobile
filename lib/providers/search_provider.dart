import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';

/// Manages search state, debounced Firestore queries, category filtering,
/// and user-preference-aware results for the Search & Discovery domain.
class SearchProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _searchCacheKey = 'cached_search_places';

  // ── State ────────────────────────────────────────────────────────────────
  List<Place> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  final List<String> _selectedCategories = [];

  /// Loaded once after login from the user's Firestore profile.
  /// Automatically merged into every Firestore `whereIn` query.
  List<String> _userPreferences = [];
  String _budgetPreference = '';
  String _atmospherePreference = '';
  String _areaPreference = '';

  // ── Debounce & race-condition guard ──────────────────────────────────────

  /// Cancelled and recreated on every [_scheduleSearch] call, ensuring
  /// at most one Firestore request fires per 500 ms burst of keystrokes.
  Timer? _debounceTimer;

  /// Incremented on every [_performSearch] invocation.
  /// Responses are discarded when their token no longer matches, preventing
  /// stale results from slower earlier queries overwriting newer ones.
  int _queryToken = 0;

  // ── Public getters ───────────────────────────────────────────────────────
  List<Place> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  List<String> get selectedCategories => List.unmodifiable(_selectedCategories);
  List<String> get userPreferences => List.unmodifiable(_userPreferences);
  String get budgetPreference => _budgetPreference;
  String get atmospherePreference => _atmospherePreference;
  String get areaPreference => _areaPreference;

  // ── User preference integration ──────────────────────────────────────────

  /// Call once after the logged-in user's profile is loaded.
  /// Immediately re-schedules a search so the preference filter takes effect.
  void setUserPreferences(List<String> preferences) {
    _userPreferences = List<String>.from(preferences);
    _scheduleSearch();
    // notifyListeners is called inside _scheduleSearch / _performSearch.
  }

  void setDiscoveryPreferences({
    required List<String> categories,
    required String budget,
    required String atmosphere,
    required String area,
  }) {
    _userPreferences = List<String>.from(categories);
    _budgetPreference = budget;
    _atmospherePreference = atmosphere;
    _areaPreference = area;
    _scheduleSearch();
  }

  // ── Public filter mutators ───────────────────────────────────────────────

  /// Updates the live text query and schedules a debounced Firestore search.
  void setSearchQuery(String query) {
    _searchQuery = query;
    _scheduleSearch();
  }

  /// Toggles a category chip on/off and immediately reschedules the search.
  void toggleCategory(String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    _scheduleSearch();
  }

  /// Resets all filters, cancels any pending debounce timer, and clears
  /// results. Called by both the clear (✕) button and "Clear All" in the
  /// filter sheet.
  void clearFilters() {
    _debounceTimer?.cancel();
    _searchQuery = '';
    _selectedCategories.clear();
    _budgetPreference = '';
    _atmospherePreference = '';
    _areaPreference = '';
    _searchResults = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearManualFilters() {
    _selectedCategories.clear();
    _scheduleSearch();
  }

  // ── Debounce scheduling ──────────────────────────────────────────────────

  void _scheduleSearch() {
    _debounceTimer?.cancel();

    // Short-circuit: nothing to query → clear results immediately.
    if (_searchQuery.isEmpty &&
        _selectedCategories.isEmpty &&
        _userPreferences.isEmpty &&
        _budgetPreference.isEmpty &&
        _atmospherePreference.isEmpty &&
        _areaPreference.isEmpty) {
      _searchResults = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Fire the real query only after 500 ms of inactivity.
    _debounceTimer = Timer(const Duration(milliseconds: 500), _performSearch);
  }

  // ── Core Firestore query ─────────────────────────────────────────────────

  Future<void> _performSearch() async {
    final int myToken = ++_queryToken; // race-condition stamp

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('places')
          .limit(100);

      // Merge manually selected categories with user preferences (OR filter).
      final Set<String> categoryFilter = {
        ..._selectedCategories,
        ..._userPreferences,
      };

      if (categoryFilter.isNotEmpty) {
        final filterList = categoryFilter.toList();
        // Enforce Firestore limit of 10 items for whereIn
        final limitedFilter = filterList.length > 10
            ? filterList.take(10).toList()
            : filterList;
        query = query.where('category', whereIn: limitedFilter);
      }

      final snapshot = await query.get();

      // Discard stale responses from slower earlier requests.
      if (myToken != _queryToken) return;

      List<Place> results = snapshot.docs.map(Place.fromFirestore).toList();

      // Client-side full-text filter (Firestore has no native full-text search).
      if (_searchQuery.isNotEmpty) {
        final lower = _searchQuery.toLowerCase();
        results = results
            .where(
              (p) =>
                  p.title.toLowerCase().contains(lower) ||
                  p.description.toLowerCase().contains(lower) ||
                  p.category.toLowerCase().contains(lower) ||
                  p.address.toLowerCase().contains(lower),
            )
            .toList();
      }

      if (_budgetPreference.isNotEmpty) {
        results = results
            .where(
              (p) =>
                  p.budget.isEmpty ||
                  p.budget.toLowerCase() == _budgetPreference.toLowerCase(),
            )
            .toList();
      }

      if (_atmospherePreference.isNotEmpty) {
        results = results
            .where(
              (p) =>
                  p.atmosphere.isEmpty ||
                  p.atmosphere.toLowerCase() ==
                      _atmospherePreference.toLowerCase(),
            )
            .toList();
      }

      if (_areaPreference.isNotEmpty) {
        final lowerArea = _areaPreference.toLowerCase();
        results = results
            .where(
              (p) =>
                  p.address.toLowerCase().contains(lowerArea) ||
                  p.title.toLowerCase().contains(lowerArea) ||
                  p.description.toLowerCase().contains(lowerArea),
            )
            .toList();
      }

      // Sort: super-user content first, then by rating descending.
      results.sort((a, b) {
        if (a.ownerIsSuperUser && !b.ownerIsSuperUser) return -1;
        if (!a.ownerIsSuperUser && b.ownerIsSuperUser) return 1;
        return b.averageRating.compareTo(a.averageRating);
      });

      _searchResults = results;
      await _cachePlaces(results);
    } catch (e) {
      if (myToken != _queryToken) return;
      _searchResults = await _loadCachedPlaces();
      _errorMessage = 'Search failed. Please try again.';
      if (kDebugMode) print('SearchProvider._performSearch: $e');
    } finally {
      if (myToken == _queryToken) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _cachePlaces(List<Place> places) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _searchCacheKey,
      jsonEncode(places.map(_placeToJson).toList()),
    );
  }

  Future<List<Place>> _loadCachedPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_searchCacheKey);
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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
