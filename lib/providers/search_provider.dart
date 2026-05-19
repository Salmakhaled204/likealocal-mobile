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

  List<String> _userPreferences = [];
  String _budgetPreference = '';
  String _atmospherePreference = '';
  String _areaPreference = '';

  // ── Debounce & race-condition guard ──────────────────────────────────────
  Timer? _debounceTimer;
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
  void setUserPreferences(List<String> preferences) {
    _userPreferences = List<String>.from(preferences);
    _scheduleSearch();
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
  void setSearchQuery(String query) {
    _searchQuery = query;
    _scheduleSearch();
  }

  void toggleCategory(String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    _scheduleSearch();
  }

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

    if (_searchQuery.trim().isEmpty &&
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

    _debounceTimer = Timer(const Duration(milliseconds: 500), _performSearch);
  }

  // ── Smart search helper ──────────────────────────────────────────────────
  bool _matchesSmartSearch(Place place, String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;

    final words = q
        .split(RegExp(r'\s+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();

    final searchableText = [
      place.title,
      place.description,
      place.category,
      place.address,
      place.budget,
      place.atmosphere,
      place.localTip,
      place.recommendedDish,
    ].join(' ').toLowerCase();

    return searchableText.contains(q) ||
        words.any((word) => searchableText.contains(word));
  }

  // ── Core Firestore query ─────────────────────────────────────────────────
  Future<void> _performSearch() async {
    final int myToken = ++_queryToken;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection('places').limit(100);

      final Set<String> categoryFilter = {
        ..._selectedCategories,
        ..._userPreferences,
      };

      if (categoryFilter.isNotEmpty) {
        final filterList = categoryFilter.toList();
        final limitedFilter = filterList.length > 10
            ? filterList.take(10).toList()
            : filterList;
        query = query.where('category', whereIn: limitedFilter);
      }

      final snapshot = await query.get();
      if (myToken != _queryToken) return;

      List<Place> results = snapshot.docs.map(Place.fromFirestore).toList();

      if (_searchQuery.trim().isNotEmpty) {
        results = results
            .where((place) => _matchesSmartSearch(place, _searchQuery))
            .toList();
      }

      if (_budgetPreference.isNotEmpty) {
        results = results
            .where((place) =>
                place.budget.isEmpty ||
                place.budget.toLowerCase() == _budgetPreference.toLowerCase())
            .toList();
      }

      if (_atmospherePreference.isNotEmpty) {
        results = results
            .where((place) =>
                place.atmosphere.isEmpty ||
                place.atmosphere.toLowerCase() ==
                    _atmospherePreference.toLowerCase())
            .toList();
      }

      if (_areaPreference.isNotEmpty) {
        final lowerArea = _areaPreference.toLowerCase();
        results = results
            .where((place) =>
                place.address.toLowerCase().contains(lowerArea) ||
                place.title.toLowerCase().contains(lowerArea) ||
                place.description.toLowerCase().contains(lowerArea))
            .toList();
      }

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

  // ── Cache helpers ────────────────────────────────────────────────────────
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
        'bestTime': place.bestTime,
        'openingHours': place.openingHours,
        'viewCount': place.viewCount,
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
        bestTime: data['bestTime'] ?? '',
        openingHours: data['openingHours'] ?? '',
        viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
        ownerId: data['ownerId'] ?? '',
        ownerName:
            data['createdByName'] ?? data['ownerName'] ?? 'Local contributor',
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
