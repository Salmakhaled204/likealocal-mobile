import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/place.dart';

/// Manages search state, debounced Firestore queries, category filtering,
/// and user-preference-aware results for the Search & Discovery domain.
class SearchProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── State ────────────────────────────────────────────────────────────────
  List<Place> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  final List<String> _selectedCategories = [];

  /// Loaded once after login from the user's Firestore profile.
  /// Automatically merged into every Firestore `whereIn` query.
  List<String> _userPreferences = [];

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

  // ── User preference integration ──────────────────────────────────────────

  /// Call once after the logged-in user's profile is loaded.
  /// Immediately re-schedules a search so the preference filter takes effect.
  void setUserPreferences(List<String> preferences) {
    _userPreferences = List<String>.from(preferences);
    _scheduleSearch();
    // notifyListeners is called inside _scheduleSearch / _performSearch.
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
        _userPreferences.isEmpty) {
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
      Query<Map<String, dynamic>> query =
          _firestore.collection('places').limit(100);

      // Merge manually selected categories with user preferences (OR filter).
      final Set<String> categoryFilter = {
        ..._selectedCategories,
        ..._userPreferences,
      };

      if (categoryFilter.isNotEmpty) {
        final filterList = categoryFilter.toList();
        // Enforce Firestore limit of 10 items for whereIn
        final limitedFilter = filterList.length > 10 ? filterList.take(10).toList() : filterList;
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
            .where((p) =>
                p.title.toLowerCase().contains(lower) ||
                p.description.toLowerCase().contains(lower))
            .toList();
      }

      // Sort: super-user content first, then by rating descending.
      results.sort((a, b) {
        if (a.ownerIsSuperUser && !b.ownerIsSuperUser) return -1;
        if (!a.ownerIsSuperUser && b.ownerIsSuperUser) return 1;
        return b.averageRating.compareTo(a.averageRating);
      });

      _searchResults = results;
    } catch (e) {
      if (myToken != _queryToken) return;
      _errorMessage = 'Search failed. Please try again.';
      if (kDebugMode) print('SearchProvider._performSearch: $e');
    } finally {
      if (myToken == _queryToken) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
