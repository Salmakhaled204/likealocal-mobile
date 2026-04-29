import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../widgets/place_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/shimmer_loading.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    // Pre-populate with current query if any
    final query = context.read<SearchProvider>().searchQuery;
    if (query.isNotEmpty) {
      _searchController.text = query;
    }
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
      builder: (context) => FilterBottomSheet(),
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
          // Search Bar
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
                        context.read<SearchProvider>().setSearchQuery(value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search places...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey[500]),
                                onPressed: () {
                                  _searchController.clear();
                                  context.read<SearchProvider>().setSearchQuery('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Consumer<SearchProvider>(
                  builder: (context, provider, child) {
                    final hasFilters = provider.selectedCategories.isNotEmpty;
                    return Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.tune,
                            color: hasFilters ? Theme.of(context).primaryColor : Colors.grey[600],
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

          // Results Area
          Expanded(
            child: Consumer<SearchProvider>(
              builder: (context, searchProvider, child) {
                if (searchProvider.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: ShimmerLoadingList(),
                  );
                }

                if (searchProvider.errorMessage != null) {
                  return Center(
                    child: Text(
                      searchProvider.errorMessage!,
                      style: GoogleFonts.inter(color: Colors.red),
                    ),
                  );
                }

                if (searchProvider.searchQuery.isEmpty && searchProvider.selectedCategories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_rounded, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "Start typing to search...",
                          style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                if (searchProvider.searchResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "No results found",
                          style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: searchProvider.searchResults.length,
                  itemBuilder: (context, index) {
                    final place = searchProvider.searchResults[index];
                    return PlaceCard(
                      place: place,
                      onTap: () {
                        // TODO: Navigate to place details
                      },
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
