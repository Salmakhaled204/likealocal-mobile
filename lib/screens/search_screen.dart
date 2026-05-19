// ══════════════════════════════════════════════════════════
//  search_screen.dart  —  teal design
// ══════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
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
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _focused = false;

  static const _tags = ['Hidden Gems', 'Best Coffee', 'Rooftop', 'Cheap Eats', 'Family', 'Romantic', 'Nightlife', 'Museum'];

  @override
  void initState() {
    super.initState();
    final existing = context.read<SearchProvider>().searchQuery;
    if (existing.isNotEmpty) _ctrl.text = existing;
    _ctrl.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  Future<void> _showFilters() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final role = uid == null ? UserRole.regularFree() : await fetchUserRole(uid);
    if (!role.advancedFilters) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Advanced filters are locked'),
          content: const Text(
            'Unlock the full LikeALocal experience with Premium, or earn Super User status through quality contributions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/premium');
              },
              child: const Text('Go Premium'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => FilterBottomSheet());
  }

  void _clear() { _ctrl.clear(); context.read<SearchProvider>().setSearchQuery(''); }
  void _search(String q) { _ctrl.text = q; context.read<SearchProvider>().setSearchQuery(q); _focus.unfocus(); }
  void _goToDetails(Place place) => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Teal header with search ──────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Explore', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('Find places locals love', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white60)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _focused ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 4))] : [],
                    ),
                    child: TextField(
                      controller: _ctrl, focusNode: _focus,
                      onChanged: (v) => context.read<SearchProvider>().setSearchQuery(v),
                      style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark),
                      decoration: InputDecoration(
                        hintText: 'Search destinations...',
                        hintStyle: GoogleFonts.poppins(color: AppTheme.textLight, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: _focused ? AppTheme.primary : AppTheme.textLight, size: 22),
                        suffixIcon: _ctrl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textLight), onPressed: _clear) : null,
                        border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        fillColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Consumer<SearchProvider>(
                  builder: (_, sp, _) {
                    final has = sp.selectedCategories.isNotEmpty || sp.userPreferences.isNotEmpty;
                    return GestureDetector(
                      onTap: _showFilters,
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: has ? Colors.white : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Stack(alignment: Alignment.center, children: [
                          Icon(Icons.tune_rounded, color: has ? AppTheme.primary : Colors.white, size: 22),
                          if (has) Positioned(top: 8, right: 8,
                            child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.peach, shape: BoxShape.circle))),
                        ]),
                      ),
                    );
                  },
                ),
              ]),
            ]),
          ),

          // ── Results or idle ────────────────────────────────────────────
          Expanded(
            child: Consumer<SearchProvider>(
              builder: (_, sp, _) {
                if (sp.isLoading) return const Padding(padding: EdgeInsets.all(20), child: ShimmerLoadingList());
                if (sp.errorMessage != null) return _Prompt(icon: Icons.error_outline_rounded, iconColor: AppTheme.errorColor, title: 'Something went wrong', subtitle: sp.errorMessage!);

                final idle = sp.searchQuery.isEmpty && sp.selectedCategories.isEmpty && sp.userPreferences.isEmpty;

                if (idle) return _IdleView(onTagTap: _search);

                if (sp.searchResults.isEmpty) return _Prompt(icon: Icons.search_off_rounded, iconColor: AppTheme.textLight, title: 'No results', subtitle: 'Try a different keyword');

                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Row(children: [
                      Text('${sp.searchResults.length} places found', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textLight)),
                    ]),
                  ),
                  Expanded(child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: sp.searchResults.length,
                    itemBuilder: (_, i) => PlaceCard(place: sp.searchResults[i], onTap: () => _goToDetails(sp.searchResults[i])),
                  )),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  final void Function(String) onTagTap;
  static const _tags = ['Hidden Gems', 'Best Coffee', 'Rooftop', 'Cheap Eats', 'Family', 'Romantic', 'Nightlife', 'Museum'];
  const _IdleView({required this.onTagTap});

  static Color _colorFor(int i) {
    const colors = [AppTheme.primary, AppTheme.accent, AppTheme.peach, AppTheme.amber, AppTheme.softBlue, AppTheme.primary, AppTheme.peach, AppTheme.accent];
    return colors[i % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Trending Searches', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: List.generate(_tags.length, (i) {
          final color = _colorFor(i);
          return GestureDetector(
            onTap: () => onTagTap(_tags[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withValues(alpha: 0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.trending_up_rounded, size: 14, color: color),
                const SizedBox(width: 6),
                Text(_tags[i], style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
              ]),
            ),
          );
        })),
        const SizedBox(height: 28),
        Text('Browse by Category', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.2,
          children: [
            _CatCard(label: 'Restaurants', icon: Icons.restaurant_rounded, color: AppTheme.amber, onTap: () => onTagTap('Restaurants')),
            _CatCard(label: 'Cafes', icon: Icons.local_cafe_rounded, color: AppTheme.primary, onTap: () => onTagTap('Cafes')),
            _CatCard(label: 'Hidden Gems', icon: Icons.explore_rounded, color: AppTheme.accent, onTap: () => onTagTap('Hidden Gems')),
            _CatCard(label: 'Culture', icon: Icons.museum_rounded, color: AppTheme.softBlue, onTap: () => onTagTap('Culture')),
            _CatCard(label: 'Nightlife', icon: Icons.nightlife_rounded, color: AppTheme.peach, onTap: () => onTagTap('Nightlife')),
            _CatCard(label: 'Shopping', icon: Icons.shopping_bag_rounded, color: AppTheme.primary, onTap: () => onTagTap('Shopping')),
          ],
        ),
      ]),
    );
  }
}

class _CatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CatCard({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMid), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  const _Prompt({required this.icon, required this.iconColor, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 78, height: 78, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, size: 38, color: iconColor)),
      const SizedBox(height: 18),
      Text(title, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
      const SizedBox(height: 6),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textLight))),
    ]));
  }
}
