import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../providers/search_provider.dart';
import '../widgets/place_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/shimmer_loading.dart';
import 'place_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Pre-populate if the provider already holds a query from a previous visit.
    final existingQuery = context.read<SearchProvider>().searchQuery;
    if (existingQuery.isNotEmpty) {
      _searchController.text = existingQuery;
    }

    // Fix: drive suffix-icon visibility from the controller itself.
    // Without this listener the ✕ button only appears/disappears after a
    // hot-reload, because the TextField is stateless about its own content.
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(),
    );
  }

  /// Clears both the TextField and all provider state (query + results).
  /// The addListener above already calls setState, but we call it explicitly
  /// here so the intent is unambiguous to future readers.
  void _clearSearch() {
    _searchController.clear();
    context.read<SearchProvider>().setSearchQuery('');
    setState(() {});
  }

  /// Typed navigator push to PlaceDetailsScreen.
  /// `place` is [Place] — never dynamic.
  void _navigateToDetails(BuildContext context, Place place) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Search',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        // Debounce is handled inside SearchProvider.setSearchQuery.
                        context.read<SearchProvider>().setSearchQuery(value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search places…',
                        hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        // Driven by _searchController.text (kept in sync by
                        // the addListener in initState) so it reacts instantly.
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey[500],
                                ),
                                onPressed: _clearSearch,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Filter button — only this small widget listens to SearchProvider
                // so the TextField above never rebuilds on unrelated notifies.
                Consumer<SearchProvider>(
                  builder: (context, provider, _) {
                    final hasFilters =
                        provider.selectedCategories.isNotEmpty ||
                        provider.userPreferences.isNotEmpty;
                    return Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.tune,
                            color: hasFilters
                                ? Theme.of(context).primaryColor
                                : Colors.grey[600],
                          ),
                          onPressed: _showFilterSheet,
                        ),
                        if (hasFilters)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Results area ──────────────────────────────────────────────────
          Expanded(
            child: Consumer<SearchProvider>(
              builder: (context, searchProvider, _) {
                // Loading
                if (searchProvider.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: ShimmerLoadingList(),
                  );
                }

                // Error
                if (searchProvider.errorMessage != null) {
                  return Center(
                    child: Text(
                      searchProvider.errorMessage!,
                      style: GoogleFonts.inter(color: Colors.red),
                    ),
                  );
                }

                // Empty prompt — nothing entered and no active filters
                if (searchProvider.searchQuery.isEmpty &&
                    searchProvider.selectedCategories.isEmpty &&
                    searchProvider.userPreferences.isEmpty &&
                    searchProvider.budgetPreference.isEmpty &&
                    searchProvider.atmospherePreference.isEmpty &&
                    searchProvider.areaPreference.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start typing to search…',
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // No results
                if (searchProvider.searchResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Results list
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: searchProvider.searchResults.length,
                  itemBuilder: (context, index) {
                    final Place place = searchProvider.searchResults[index];
                    return PlaceCard(
                      place: place,
                      onTap: () => _navigateToDetails(context, place),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
