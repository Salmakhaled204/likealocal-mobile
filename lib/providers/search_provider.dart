import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/place.dart';

class SearchProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Place> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Filters
  String _searchQuery = '';
  List<String> _selectedCategories = [];

  List<Place> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  List<String> get selectedCategories => _selectedCategories;

  void setSearchQuery(String query) {
    _searchQuery = query;
    _performSearch();
  }

  void toggleCategory(String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    _performSearch();
  }
  
  void clearFilters() {
    _searchQuery = '';
    _selectedCategories.clear();
    _searchResults.clear();
    notifyListeners();
  }

  Future<void> _performSearch() async {
    // If no filters are applied, clear results
    if (_searchQuery.isEmpty && _selectedCategories.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Query query = _firestore.collection('places');

      // Filter by category if any selected
      if (_selectedCategories.isNotEmpty) {
        query = query.where('category', whereIn: _selectedCategories);
      }

      // We still use serverAndCache for offline capability
      final querySnapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      
      List<Place> results = querySnapshot.docs.map((doc) => Place.fromFirestore(doc)).toList();

      // Client-side text filtering since Firestore doesn't support full-text search out of the box
      if (_searchQuery.isNotEmpty) {
        final queryLower = _searchQuery.toLowerCase();
        results = results.where((place) {
          return place.title.toLowerCase().contains(queryLower) || 
                 place.description.toLowerCase().contains(queryLower);
        }).toList();
      }

      // Sort results similar to home
      results.sort((a, b) {
        if (a.ownerIsSuperUser && !b.ownerIsSuperUser) return -1;
        if (!a.ownerIsSuperUser && b.ownerIsSuperUser) return 1;
        return b.averageRating.compareTo(a.averageRating);
      });

      _searchResults = results;
    } catch (e) {
      _errorMessage = 'Failed to search places.';
      if (kDebugMode) {
        print('Error searching places: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
