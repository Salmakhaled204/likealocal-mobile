import 'dart:ui';
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

class _PlaceCardState extends State<PlaceCard> with SingleTickerProviderStateMixin {
  bool _isFavorite = false;
  bool _isFavoriteLoading = true;
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  Place get place => widget.place;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _loadFavorite();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(covariant PlaceCard old) {
    super.didUpdateWidget(old);
    if (old.place.id != widget.place.id) _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    setState(() => _isFavoriteLoading = true);
    final saved = await FavoriteService.isFavorite(widget.place.id);
    if (mounted) setState(() { _isFavorite = saved; _isFavoriteLoading = false; });
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriteLoading) return;
    _ctrl.forward().then((_) => _ctrl.reverse());
    final next = !_isFavorite;
    setState(() => _isFavorite = next);
    final result = await FavoriteService.togglePlace(widget.place, currentlySaved: !next);
    if (!mounted) return;
    if (result == FavoriteResult.limitReached) { setState(() => _isFavorite = false); _snack('Saved-place limit reached.'); }
    else if (result == FavoriteResult.loginRequired) { setState(() => _isFavorite = false); _snack('Log in to save places.'); }
    else if (result == FavoriteResult.failed) { setState(() => _isFavorite = !next); _snack('Could not update.'); }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            // Left image — tall rectangular, 110px wide
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: SizedBox(
                width: 110, height: 110,
                child: Stack(fit: StackFit.expand, children: [
                  place.imageUrls.isNotEmpty
                      ? CachedNetworkImage(imageUrl: place.imageUrls.first, fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: AppTheme.surfaceWarm),
                          errorWidget: (_, _, _) => Container(decoration: const BoxDecoration(gradient: AppTheme.headerGradient)))
                      : Container(decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
                          child: Center(child: Icon(Icons.image_outlined, color: Colors.white.withValues(alpha: 0.4), size: 30))),
                  if (place.ownerIsSuperUser)
                    Positioned(top: 8, left: 8, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(20)),
                      child: Text('Top', style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                    )),
                ]),
              ),
            ),
            // Right info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(20)),
                      child: Text(place.category, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    ScaleTransition(
                      scale: _scale,
                      child: GestureDetector(
                        onTap: _toggleFavorite,
                        child: _isFavoriteLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                            : Icon(_isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _isFavorite ? AppTheme.peach : AppTheme.textLight, size: 20),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(place.title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  if (place.address.isNotEmpty)
                    Row(children: [
                      Icon(Icons.location_on_rounded, size: 12, color: AppTheme.textLight),
                      const SizedBox(width: 3),
                      Expanded(child: Text(place.address, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textLight), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    ...List.generate(5, (i) => Icon(
                      i < place.averageRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppTheme.amber, size: 13,
                    )),
                    const SizedBox(width: 4),
                    Text(place.averageRating.toStringAsFixed(1), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    Text('/5', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textLight)),
                    const Spacer(),
                    if (place.budget.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                        child: Text(place.budget, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}