import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../providers/search_provider.dart';
import '../theme/app_theme.dart';
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
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = context.read<SearchProvider>().searchQuery;
    if (existing.isNotEmpty) _searchCtrl.text = existing;
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(),
    );
  }

  void _clear() {
    _searchCtrl.clear();
    context.read<SearchProvider>().setSearchQuery('');
    setState(() {});
  }

  void _goToDetails(Place place) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explore',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find places, vibes, and hidden gems',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),

            // ── Search bar + filter ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) =>
                            context.read<SearchProvider>().setSearchQuery(v),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search places, vibes…',
                          hintStyle: GoogleFonts.poppins(
                            color: AppTheme.textLight,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: AppTheme.textLight,
                                    size: 18,
                                  ),
                                  onPressed: _clear,
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Consumer<SearchProvider>(
                    builder: (context, provider, _) {
                      final hasFilters =
                          provider.selectedCategories.isNotEmpty ||
                          provider.userPreferences.isNotEmpty;
                      return GestureDetector(
                        onTap: _showFilters,
                        child: Stack(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: hasFilters
                                    ? AppTheme.primaryLight
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: hasFilters
                                      ? AppTheme.primary
                                      : AppTheme.border,
                                ),
                                boxShadow: AppTheme.softShadow,
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                color: hasFilters
                                    ? AppTheme.primary
                                    : AppTheme.textLight,
                                size: 22,
                              ),
                            ),
                            if (hasFilters)
                              Positioned(
                                right: 9,
                                top: 9,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.dustyPink,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Results ────────────────────────────────────────────────
            Expanded(
              child: Consumer<SearchProvider>(
                builder: (context, sp, _) {
                  if (sp.isLoading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22),
                      child: ShimmerLoadingList(),
                    );
                  }

                  if (sp.errorMessage != null) {
                    return _Prompt(
                      icon: Icons.error_outline_rounded,
                      iconColor: AppTheme.peach,
                      iconBg: AppTheme.peachLight,
                      title: 'Something went wrong',
                      subtitle: sp.errorMessage!,
                    );
                  }

                  final noSearch = sp.searchQuery.isEmpty &&
                      sp.selectedCategories.isEmpty &&
                      sp.userPreferences.isEmpty &&
                      sp.budgetPreference.isEmpty &&
                      sp.atmospherePreference.isEmpty &&
                      sp.areaPreference.isEmpty;

                  if (noSearch) {
                    return _Prompt(
                      icon: Icons.search_rounded,
                      iconColor: AppTheme.primary,
                      iconBg: AppTheme.primaryLight,
                      title: 'Search & discover',
                      subtitle: 'Type a place name, category, or vibe…',
                    );
                  }

                  if (sp.searchResults.isEmpty) {
                    return _Prompt(
                      icon: Icons.inbox_outlined,
                      iconColor: AppTheme.textLight,
                      iconBg: AppTheme.surfaceWarm,
                      title: 'No results found',
                      subtitle: 'Try a different keyword or remove filters',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 100),
                    itemCount: sp.searchResults.length,
                    itemBuilder: (context, i) {
                      final place = sp.searchResults[i];
                      return PlaceCard(
                        place: place,
                        onTap: () => _goToDetails(place),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _Prompt({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: iconColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
