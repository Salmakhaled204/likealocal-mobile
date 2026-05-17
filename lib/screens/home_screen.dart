import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/place.dart';
import '../providers/home_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/place_card.dart';
import 'place_details_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().fetchPlaces();
    });
  }

  void _openPlace(Place place) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Consumer<HomeProvider>(
          builder: (context, provider, _) {
            final places = provider.places;
            final recommendations = provider.recommendations;

            return RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: provider.fetchPlaces,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                      child: _Header(
                        onSearchTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SearchScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (provider.isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (provider.errorMessage != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MessageState(
                        icon: Icons.wifi_off_rounded,
                        message: provider.errorMessage!,
                      ),
                    )
                  else if (places.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MessageState(
                        icon: Icons.explore_off_rounded,
                        message: 'No places yet. Check back soon.',
                      ),
                    )
                  else ...[
                    if (recommendations.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionTitle(
                          title: provider.isPersonalized
                              ? 'For you'
                              : 'Local favorites',
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 235,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(left: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: recommendations.length,
                            itemBuilder: (context, index) {
                              final place = recommendations[index];
                              return _NearbyCard(
                                place: place,
                                onTap: () => _openPlace(place),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(
                      child: _SectionTitle(title: 'Explore nearby'),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList.builder(
                        itemCount: places.length,
                        itemBuilder: (context, index) {
                          final place = places[index];
                          return PlaceCard(
                            place: place,
                            onTap: () => _openPlace(place),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onSearchTap;

  const _Header({required this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LikeALocal',
          style: GoogleFonts.poppins(
            color: AppTheme.textDark,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Find places locals actually love.',
          style: GoogleFonts.poppins(color: AppTheme.textLight, fontSize: 14),
        ),
        const SizedBox(height: 18),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onSearchTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: AppTheme.textLight),
                const SizedBox(width: 10),
                Text(
                  'Search cafes, gems, food spots',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: AppTheme.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MessageState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textLight, size: 38),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppTheme.textLight,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyCard extends StatefulWidget {
  final Place place;
  final VoidCallback onTap;

  const _NearbyCard({required this.place, required this.onTap});

  @override
  State<_NearbyCard> createState() => _NearbyCardState();
}

class _NearbyCardState extends State<_NearbyCard> {
  Place get place => widget.place;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 165,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Stack(
                children: [
                  place.imageUrls.isNotEmpty
                      ? Image.network(
                          place.imageUrls.first,
                          height: 125,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, err, st) => _imgPlaceholder(),
                        )
                      : _imgPlaceholder(),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bookmark_border_rounded,
                          color: AppTheme.dustyPink,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    place.address.isNotEmpty ? place.address : place.category,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppTheme.amber,
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        place.averageRating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      if (place.budget.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '- ${place.budget}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.textLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    height: 125,
    color: AppTheme.surfaceWarm,
    child: Center(
      child: Icon(Icons.image_outlined, color: AppTheme.textLight, size: 32),
    ),
  );
}
