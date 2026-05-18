import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/place.dart';
import '../services/favorite_service.dart';
import '../theme/app_theme.dart';

class PlaceCard extends StatefulWidget {
  final Place place;
  final VoidCallback onTap;

  const PlaceCard({super.key, required this.place, required this.onTap});

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard> {
  bool _isFavorite = false;
  bool _isFavoriteLoading = true;

  Place get place => widget.place;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  @override
  void didUpdateWidget(covariant PlaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.id != widget.place.id) _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    setState(() => _isFavoriteLoading = true);
    final saved = await FavoriteService.isFavorite(widget.place.id);
    if (mounted) {
      setState(() {
        _isFavorite = saved;
        _isFavoriteLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriteLoading) return;
    final next = !_isFavorite;
    setState(() => _isFavorite = next);
    final result = await FavoriteService.togglePlace(
      widget.place,
      currentlySaved: !next,
    );
    if (!mounted) return;
    if (result == FavoriteResult.limitReached) {
      setState(() => _isFavorite = false);
      _snack('Saved-place limit reached.');
    } else if (result == FavoriteResult.loginRequired) {
      setState(() => _isFavorite = false);
      _snack('Log in to save places.');
    } else if (result == FavoriteResult.failed) {
      setState(() => _isFavorite = !next);
      _snack('Could not update saved place.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Pick a soft accent per category for variety
  static Color _accentFor(String category) {
    final c = category.toLowerCase();
    if (c.contains('cafe') || c.contains('coffee')) return AppTheme.mint;
    if (c.contains('restaurant') || c.contains('food')) return AppTheme.peach;
    if (c.contains('nightlife') || c.contains('bar')) return AppTheme.dustyPink;
    if (c.contains('museum') || c.contains('culture')) return AppTheme.softBlue;
    if (c.contains('hidden') || c.contains('gem')) return AppTheme.primary;
    return AppTheme.primary;
  }

  static Color _accentLightFor(String category) {
    final c = category.toLowerCase();
    if (c.contains('cafe') || c.contains('coffee')) return AppTheme.mintLight;
    if (c.contains('restaurant') || c.contains('food')) {
      return AppTheme.peachLight;
    }
    if (c.contains('nightlife') || c.contains('bar')) {
      return const Color(0xFFF9EEF2);
    }
    if (c.contains('museum') || c.contains('culture')) {
      return const Color(0xFFE8F1F9);
    }
    return AppTheme.primaryLight;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(place.category);
    final accentLight = _accentLightFor(place.category);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──────────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: place.imageUrls.isNotEmpty
                        ? place.imageUrls.first
                        : 'https://placehold.co/400x220/F5F3F0/A5A5BB?text=LikeALocal',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: AppTheme.surfaceWarm,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryDim,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: AppTheme.surfaceWarm,
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: AppTheme.textLight,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),

                // Soft gradient at bottom of image
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.25),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // Super User badge
                if (place.ownerIsSuperUser)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.amber,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.amber.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Super User',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                Positioned(
                  bottom: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _toggleFavorite,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isFavoriteLoading
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _isFavorite
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              color: _isFavorite
                                  ? AppTheme.primary
                                  : AppTheme.textMid,
                              size: 20,
                            ),
                    ),
                  ),
                ),

                // Rating badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppTheme.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          place.averageRating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Info ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          place.title,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          place.category,
                          style: GoogleFonts.poppins(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    place.description,
                    style: GoogleFonts.poppins(
                      color: AppTheme.textLight,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (place.address.isNotEmpty ||
                      place.budget.isNotEmpty ||
                      place.atmosphere.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (place.address.isNotEmpty)
                          _MetaChip(
                            icon: Icons.place_outlined,
                            label: place.address,
                          ),
                        if (place.budget.isNotEmpty)
                          _MetaChip(
                            icon: Icons.payments_outlined,
                            label: place.budget,
                          ),
                        if (place.atmosphere.isNotEmpty)
                          _MetaChip(
                            icon: Icons.groups_outlined,
                            label: place.atmosphere,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWarm,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textLight),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textMid),
            ),
          ),
        ],
      ),
    );
  }
}
