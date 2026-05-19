import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../models/place.dart';
import '../models/user_role.dart';
import '../services/favorite_service.dart';
import '../theme/app_theme.dart';
import 'add_place_screen.dart';
import 'chat_service.dart';
import 'public_profile_screen.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final Place place;
  const PlaceDetailsScreen({super.key, required this.place});
  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _reviewCtrl = TextEditingController();
  int _selectedRating = 5;
  bool _isFavorite = false;
  bool _isFavoriteLoading = true;
  bool _isSubmittingReview = false;
  String? _editingReviewId;
  late final TabController _tabCtrl;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String get _placeId => widget.place.id;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _checkFavorite();
    _incrementViewCount();
  }

  @override
  void dispose() { _reviewCtrl.dispose(); _tabCtrl.dispose(); super.dispose(); }

  Future<void> _incrementViewCount() async {
    try {
      await FirebaseFirestore.instance.collection('places').doc(_placeId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  Future<void> _checkFavorite() async {
    final uid = _uid;
    if (uid == null) { setState(() => _isFavoriteLoading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).collection('favorites').doc(_placeId).get();
      if (mounted) setState(() { _isFavorite = doc.exists; _isFavoriteLoading = false; });
    } catch (_) { if (mounted) setState(() => _isFavoriteLoading = false); }
  }

  Future<void> _toggleFavorite(Place place) async {
    final next = !_isFavorite;
    if (mounted) setState(() => _isFavorite = next);
    final result = await FavoriteService.togglePlace(place, currentlySaved: !next);
    if (!mounted) return;
    if (result == FavoriteResult.limitReached) { setState(() => _isFavorite = false); _showPremiumDialog(); }
    else if (result == FavoriteResult.loginRequired) { setState(() => _isFavorite = false); _snack('Log in to save.'); }
    else if (result == FavoriteResult.failed) { setState(() => _isFavorite = !next); _snack('Could not update.'); }
  }

  Future<void> _toggleHelpfulReview(String reviewId, String reviewOwnerId) async {
    final uid = _uid;
    if (uid == null) { _snack('Log in first.'); return; }
    if (uid == reviewOwnerId) { _snack('You cannot vote on your own review.'); return; }
    final reviewRef = FirebaseFirestore.instance.collection('places').doc(_placeId).collection('reviews').doc(reviewId);
    final voteRef = reviewRef.collection('helpfulVotes').doc(uid);
    final userRef = FirebaseFirestore.instance.collection('users').doc(reviewOwnerId);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final voteDoc = await tx.get(voteRef);
        if (voteDoc.exists) {
          tx.delete(voteRef);
          tx.update(reviewRef, {'helpfulCount': FieldValue.increment(-1)});
          tx.set(userRef, {'stats': {'helpfulVotes': FieldValue.increment(-1)}, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        } else {
          tx.set(voteRef, {'userId': uid, 'createdAt': FieldValue.serverTimestamp()});
          tx.set(reviewRef, {'helpfulCount': FieldValue.increment(1)}, SetOptions(merge: true));
          tx.set(userRef, {'stats': {'helpfulVotes': FieldValue.increment(1)}, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      });
    } catch (_) { _snack('Could not update vote.'); }
  }

  Future<void> _submitReview() async {
    final uid = _uid;
    if (uid == null) { _snack('Log in to leave a review.'); return; }
    final text = _reviewCtrl.text.trim();
    if (text.isEmpty) { _snack('Write a review first.'); return; }
    setState(() => _isSubmittingReview = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userDoc = await userRef.get();
      final role = UserRole.fromData(userDoc.data());
      if (_editingReviewId == null &&
          role.limits.reviewsToday >= role.maxReviewsPerDay) {
        _snack(
          'Daily review limit reached (${role.maxReviewsPerDay}). Premium unlocks more review activity.',
        );
        return;
      }
      final ref = FirebaseFirestore.instance.collection('places').doc(_placeId).collection('reviews').doc(_editingReviewId ?? uid);
      await ref.set({
        'userId': uid, 'userEmail': user.email ?? '', 'userName': user.displayName ?? '',
        'placeId': _placeId, 'text': text, 'rating': _selectedRating,
        if (_editingReviewId == null) 'helpfulCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
        if (_editingReviewId == null) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (_editingReviewId == null) {
        await userRef.set({
          'limits': {'reviewsToday': FieldValue.increment(1)},
          'stats': {'totalReviews': FieldValue.increment(1)},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await _recalcRating();
      _reviewCtrl.clear();
      setState(() { _editingReviewId = null; _selectedRating = 5; });
    } catch (_) { _snack('Failed to submit review.'); }
    finally { if (mounted) setState(() => _isSubmittingReview = false); }
  }

  Future<void> _confirmDeleteReview(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: AppTheme.errorColor))),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('places').doc(_placeId).collection('reviews').doc(id).delete();
      await _recalcRating();
    }
  }

  Future<void> _reportPlace(Place place) async {
    final uid = _uid;
    if (uid == null) { _snack('Log in to report.'); return; }
    if (uid == place.ownerId) { _snack('You cannot report your own place.'); return; }
    final report = await _showReportDialog(title: 'Report this place');
    if (report == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('places')
          .doc(_placeId)
          .collection('reports')
          .add({
        'type': 'place',
        'status': 'open',
        'placeId': _placeId,
        'placeTitle': place.title,
        'targetOwnerId': place.ownerId,
        'reporterId': uid,
        'reporterEmail': FirebaseAuth.instance.currentUser?.email ?? '',
        'reason': report.reason,
        'details': report.details,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _snack('Report sent to admin moderation.');
    } catch (_) {
      _snack('Could not send report.');
    }
  }

  Future<void> _reportReview({
    required String reviewId,
    required Map<String, dynamic> data,
  }) async {
    final uid = _uid;
    if (uid == null) { _snack('Log in to report.'); return; }
    final reviewOwnerId = (data['userId'] ?? '').toString();
    if (uid == reviewOwnerId) { _snack('You cannot report your own review.'); return; }
    final report = await _showReportDialog(title: 'Report this review');
    if (report == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('places')
          .doc(_placeId)
          .collection('reviews')
          .doc(reviewId)
          .collection('reports')
          .add({
        'type': 'review',
        'status': 'open',
        'placeId': _placeId,
        'reviewId': reviewId,
        'placeTitle': widget.place.title,
        'targetOwnerId': reviewOwnerId,
        'reportedText': (data['text'] ?? '').toString(),
        'reporterId': uid,
        'reporterEmail': FirebaseAuth.instance.currentUser?.email ?? '',
        'reason': report.reason,
        'details': report.details,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _snack('Review report sent to admin moderation.');
    } catch (_) {
      _snack('Could not send report.');
    }
  }

  Future<_ReportInput?> _showReportDialog({required String title}) async {
    final detailsCtrl = TextEditingController();
    var reason = 'Inappropriate content';
    final result = await showDialog<_ReportInput>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  'Inappropriate content',
                  'Fake or misleading',
                  'Spam',
                  'Harassment',
                  'Wrong information',
                  'Other',
                ].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: (value) => setDialogState(() => reason = value ?? reason),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'Tell the admin what is wrong',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                _ReportInput(reason: reason, details: detailsCtrl.text.trim()),
              ),
              child: const Text('Send report'),
            ),
          ],
        ),
      ),
    );
    detailsCtrl.dispose();
    return result;
  }

  Future<void> _recalcRating() async {
    final snap = await FirebaseFirestore.instance.collection('places').doc(_placeId).collection('reviews').get();
    final avg = snap.docs.isEmpty ? 0.0 : snap.docs.fold<double>(0, (t, d) => t + ((d.data()['rating'] as num?) ?? 0)) / snap.docs.length;
    await FirebaseFirestore.instance.collection('places').doc(_placeId).update({'averageRating': avg, 'reviewCount': snap.docs.length});
  }

  Future<void> _openDirections(Place place) async {
    final lat = place.location.latitude, lng = place.location.longitude;
    if (lat == 0 && lng == 0) { _snack('Directions unavailable.'); return; }
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _snack('Could not open maps.');
  }

  Future<void> _saveReminder(Place place) async {
    final uid = _uid;
    if (uid == null) { _snack('Log in first.'); return; }
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final role = UserRole.fromData(userDoc.data());
    final reminders = await FirebaseFirestore.instance.collection('users').doc(uid).collection('locationReminders').limit(role.maxReminders + 1).get();
    final alreadySaved = reminders.docs.any((d) => d.id == place.id);
    if (!alreadySaved && reminders.docs.length >= role.maxReminders) { _snack('Reminder limit reached.'); return; }
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('locationReminders').doc(place.id).set({
      'placeId': place.id, 'title': place.title, 'location': place.location, 'enabled': true, 'radiusMeters': 300, 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!alreadySaved) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({'limits': {'remindersUsed': FieldValue.increment(1)}, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    _snack('Reminder saved!');
  }

  Future<void> _deletePlace(Place place) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete place?'),
        content: const Text('This removes the place for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: AppTheme.errorColor))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = FirebaseFirestore.instance;
      final placeRef = db.collection('places').doc(_placeId);
      final batch = db.batch();
      final reviews = await placeRef.collection('reviews').get();
      for (final r in reviews.docs) {
        final votes = await r.reference.collection('helpfulVotes').get();
        for (final v in votes.docs) {
          batch.delete(v.reference);
        }
        batch.delete(r.reference);
      }
      batch.delete(placeRef);
      await batch.commit();
      for (final url in [...place.imageUrls, ...place.videoUrls]) {
        try { await FirebaseStorage.instance.refFromURL(url).delete(); } catch (_) {}
      }
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Place deleted.');
    } catch (_) { _snack('Could not delete.'); }
  }

  void _showQrCode(Place place) {
    final qrData =
        'likealocal://place/${place.id}?name=${Uri.encodeComponent(place.title)}&lat=${place.location.latitude}&lng=${place.location.longitude}';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.qr_code_2_rounded, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Share Place',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            place.title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Scan to view this place',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textLight),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPremiumDialog() {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Upgrade to Premium'),
      content: const Text('You reached your saved-place limit.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ));
  }

  void _startEditing(String id, String text, int rating) {
    setState(() { _editingReviewId = id; _selectedRating = rating; });
    _reviewCtrl.text = text;
  }

  void _cancelEditing() {
    setState(() { _editingReviewId = null; _selectedRating = 5; });
    _reviewCtrl.clear();
  }

  void _openPublicProfile(String userId, String fallbackName) {
    if (userId.isEmpty) {
      _snack('Profile unavailable.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: userId,
          fallbackName: fallbackName,
        ),
      ),
    );
  }

  void _snack(String msg) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); }
  String _fmtDate(dynamic v) { if (v is! Timestamp) return ''; final d = v.toDate(); return '${d.day}/${d.month}/${d.year}'; }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayDark,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('places').doc(_placeId).snapshots(),
        builder: (_, snapshot) {
          final place = snapshot.hasData && snapshot.data!.exists ? Place.fromFirestore(snapshot.data!) : widget.place;
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: CustomScrollView(
              slivers: [
                _buildAppBar(place),
                SliverToBoxAdapter(
                  child: Column(children: [
                    _buildTabBar(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildStatChips(place),
                        _buildVisitInfo(place),
                        const SizedBox(height: 22),
                        _buildDescription(place),
                        const SizedBox(height: 20),
                        _buildLocalTip(place),
                        _buildDishes(place),
                        if (place.videoUrls.isNotEmpty) ...[const SizedBox(height: 20), _buildVideos(place)],
                        const SizedBox(height: 20),
                        _buildOwnerCard(place),
                        const SizedBox(height: 20),
                        _buildReviews(),
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
            bottomNavigationBar: _buildBottomCTA(place),
          );
        },
      ),
    );
  }

  // ── App bar with full hero ─────────────────────────────────────────────────

  Widget _buildAppBar(Place place) {
    final images = place.imageUrls.isNotEmpty ? place.imageUrls : [''];
    return SliverAppBar(
      expandedHeight: 310,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.primaryDark,
      systemOverlayStyle: AppTheme.overlayDark,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () => _showQrCode(place),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () => _openDirections(place),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.compass_calibration_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () => _reportPlace(place),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.flag_outlined, color: Colors.white, size: 20),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
          child: GestureDetector(
            onTap: () => _toggleFavorite(place),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: _isFavoriteLoading
                  ? const Padding(padding: EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFavorite ? AppTheme.peach : Colors.white, size: 20),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(fit: StackFit.expand, children: [
          PageView.builder(
            itemCount: images.length,
            itemBuilder: (_, i) => images[i].isEmpty
                ? Container(decoration: const BoxDecoration(gradient: AppTheme.headerGradient))
                : CachedNetworkImage(imageUrl: images[i], fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: AppTheme.surfaceWarm),
                    errorWidget: (_, _, _) => Container(decoration: const BoxDecoration(gradient: AppTheme.headerGradient))),
          ),
          // Gradient overlay
          const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.heroGradient)),
          // Title + location at bottom
          Positioned(left: 18, right: 18, bottom: 60, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place.title, style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15)),
            if (place.address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Expanded(child: Text(place.address, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ],
            const SizedBox(height: 8),
            // Rating row
            Row(children: [
              ...List.generate(5, (i) => Icon(
                i < place.averageRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                color: AppTheme.amber, size: 17,
              )),
              const SizedBox(width: 6),
              Text('${place.averageRating.toStringAsFixed(1)}/5', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Icon(Icons.visibility_outlined, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text('${place.viewCount} views', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
            ]),
          ])),
          // Thumbnail strip bottom-right (like reference)
          if (place.imageUrls.length > 1)
            Positioned(right: 14, bottom: 56, child: Row(children: [
              ...place.imageUrls.take(3).map((url) => Container(
                width: 46, height: 36, margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                  image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                ),
              )),
              if (place.imageUrls.length > 3)
                Container(
                  width: 46, height: 36, margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.black54, border: Border.all(color: Colors.white, width: 1.5)),
                  child: Center(child: Text('+${place.imageUrls.length - 3}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                ),
            ])),
        ]),
      ),
    );
  }

  // ── Tab bar (Overview / Details / Reviews / Explore Nearby) ───────────────

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surface,
      child: TabBar(
        controller: _tabCtrl,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 2.5,
        labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400),
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textLight,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Details'),
          Tab(text: 'Reviews'),
          Tab(text: 'Explore Nearby'),
        ],
        onTap: (i) {
          // Scroll to section if desired — for now tabs just visually select
        },
      ),
    );
  }

  // ── Stat chips row (Distance / Travel Time / Weather style) ───────────────

  Widget _buildStatChips(Place place) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.softShadow),
      child: Row(children: [
        _StatChip(icon: Icons.location_on_outlined, iconColor: AppTheme.peach, label: 'Category', value: place.category),
        _StatDivider(),
        _StatChip(icon: Icons.star_rounded, iconColor: AppTheme.amber, label: 'Rating', value: '${place.averageRating.toStringAsFixed(1)}/5'),
        _StatDivider(),
        _StatChip(icon: Icons.wb_sunny_outlined, iconColor: AppTheme.primary, label: 'Budget', value: place.budget.isNotEmpty ? place.budget : 'Free'),
      ]),
    );
  }

  // ── Description ────────────────────────────────────────────────────────────

  Widget _buildVisitInfo(Place place) {
    final items = <Widget>[
      if (place.viewCount > 0)
        _VisitInfoRow(icon: Icons.visibility_outlined, label: 'Total views', value: '${place.viewCount} people viewed this place'),
      if (place.bestTime.isNotEmpty)
        _VisitInfoRow(icon: Icons.access_time_outlined, label: 'Best time to visit', value: place.bestTime),
      if (place.openingHours.isNotEmpty)
        _VisitInfoRow(icon: Icons.schedule_outlined, label: 'Opening hours', value: place.openingHours),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(children: items),
    );
  }

  Widget _buildDescription(Place place) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Description', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
      const SizedBox(height: 10),
      Text(place.description, style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMid, height: 1.7)),
    ]);
  }

  // ── Local tip ──────────────────────────────────────────────────────────────

  Widget _buildLocalTip(Place place) {
    if (place.localTip.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.primaryDim)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 3, height: 40, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Local tip', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            const SizedBox(height: 4),
            Text('"${place.localTip}"', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textMid, fontStyle: FontStyle.italic, height: 1.5)),
          ])),
        ]),
      ),
    );
  }

  // ── Recommended dishes ─────────────────────────────────────────────────────

  Widget _buildDishes(Place place) {
    if (place.recommendedDish.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recommended', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: place.recommendedDish.split(',').map((d) =>
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primaryDim)),
            child: Text(d.trim(), style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
          )
        ).toList()),
      ]),
    );
  }

  // ── Videos ─────────────────────────────────────────────────────────────────

  Widget _buildVideos(Place place) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Videos', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
      const SizedBox(height: 10),
      ...place.videoUrls.map((url) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _VideoPlayerCard(url: url))),
    ]);
  }

  // ── Owner card ─────────────────────────────────────────────────────────────

  Widget _buildOwnerCard(Place place) {
    if (place.ownerName.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.softShadow),
      child: Row(children: [
        GestureDetector(
          onTap: () => _openPublicProfile(place.ownerId, place.ownerName),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
            child: Center(child: Text(place.ownerName.isNotEmpty ? place.ownerName[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openPublicProfile(place.ownerId, place.ownerName),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(place.ownerName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark), overflow: TextOverflow.ellipsis)),
              if (place.ownerIsSuperUser) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primaryDim)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.workspace_premium_rounded, size: 11, color: AppTheme.primary),
                    const SizedBox(width: 3),
                    Text('Super User', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),
            Text('View profile', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ]),
        )),
        if (place.ownerId.isNotEmpty && place.ownerId != _uid)
          GestureDetector(
            onTap: () => ChatService.startChat(
              context,
              place.ownerId,
              otherUserName: place.ownerName,
              placeId: place.id,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primaryDim)),
              child: Text('Message', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }

  // ── Reviews ────────────────────────────────────────────────────────────────

  Widget _buildReviews() {
    final canReview = _uid != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Reviews', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.softShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(canReview ? (_editingReviewId != null ? 'Edit your review' : 'Leave a review') : 'Log in to leave a review',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textDark)),
          const SizedBox(height: 12),
          Row(children: List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: canReview ? () => setState(() => _selectedRating = star) : null,
              child: Padding(padding: const EdgeInsets.only(right: 4), child: Icon(
                star <= _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: AppTheme.amber, size: 30,
              )),
            );
          })),
          const SizedBox(height: 12),
          TextField(
            controller: _reviewCtrl, enabled: canReview, maxLines: 3, maxLength: 300,
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark),
            decoration: InputDecoration(hintText: canReview ? 'Share your experience…' : 'Log in to share.',
                counterStyle: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textLight)),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (_editingReviewId != null) ...[TextButton(onPressed: _cancelEditing, child: const Text('Cancel')), const SizedBox(width: 8)],
            SizedBox(height: 40, child: ElevatedButton(
              onPressed: !canReview || _isSubmittingReview ? null : _submitReview,
              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40), padding: const EdgeInsets.symmetric(horizontal: 20)),
              child: _isSubmittingReview
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_editingReviewId != null ? 'Update' : 'Submit'),
            )),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('places').doc(_placeId).collection('reviews').orderBy('createdAt', descending: true).snapshots(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.primary)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Padding(padding: const EdgeInsets.all(20),
                child: Text('No reviews yet. Be the first! 🌟', style: GoogleFonts.poppins(color: AppTheme.textLight, fontSize: 13))));
          }
          return Column(children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final reviewOwnerId = (data['userId'] as String?) ?? '';
            final isOwner = reviewOwnerId == _uid;
            final rating = (data['rating'] as num?)?.toInt() ?? 0;
            final helpfulCount = (data['helpfulCount'] as num?)?.toInt() ?? 0;
            final name = ((data['userName'] as String?) ?? '').trim();
            final email = ((data['userEmail'] as String?) ?? '').trim();
            final label = name.isNotEmpty ? name : email.isNotEmpty ? email : 'Anonymous';
            final date = _fmtDate(data['updatedAt'] ?? data['createdAt']);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.softShadow),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => _openPublicProfile(reviewOwnerId, label),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
                      child: Center(child: Text(label.isNotEmpty ? label[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.bold))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openPublicProfile(reviewOwnerId, label),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textDark), overflow: TextOverflow.ellipsis),
                      Row(children: [
                        ...List.generate(5, (i) => Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppTheme.amber, size: 13)),
                        if (date.isNotEmpty) ...[const SizedBox(width: 8), Text(date, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textLight))],
                      ]),
                    ]),
                  )),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        _startEditing(doc.id, data['text'] ?? '', rating);
                      } else if (v == 'delete') {
                        _confirmDeleteReview(doc.id);
                      } else if (v == 'report') {
                        _reportReview(reviewId: doc.id, data: data);
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (isOwner)
                        PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.poppins(color: AppTheme.textDark))),
                      if (isOwner)
                        PopupMenuItem(value: 'delete', child: Text('Delete', style: GoogleFonts.poppins(color: AppTheme.errorColor))),
                      if (!isOwner)
                        PopupMenuItem(value: 'report', child: Text('Report', style: GoogleFonts.poppins(color: AppTheme.errorColor))),
                    ],
                    child: Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.textLight),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(data['text'] ?? '', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMid, height: 1.6)),
                const SizedBox(height: 10),
                _HelpfulButton(placeId: _placeId, reviewId: doc.id, reviewOwnerId: reviewOwnerId, currentUserId: _uid, count: helpfulCount, onTap: () => _toggleHelpfulReview(doc.id, reviewOwnerId)),
              ]),
            );
          }).toList());
        },
      ),
    ]);
  }

  // ── Bottom CTA (matches the reference: price left, teal "Booking Now" right) ──

  Widget _buildBottomCTA(Place place) {
    final uid = _uid;
    return FutureBuilder<UserRole>(
      future: uid == null ? Future.value(UserRole.regularFree()) : fetchUserRole(uid),
      builder: (_, snap) {
        final role = snap.data ?? UserRole.regularFree();
        final canManage = uid != null && role.canManagePlace(place.ownerId, uid);
        return Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
          ),
          child: Row(children: [
            // Left: place info / manage buttons
            if (canManage) ...[
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddPlaceScreen(placeToEdit: place))),
                child: Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.primaryDim)),
                  child: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 22)),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _deletePlace(place),
                child: Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: AppTheme.errorColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3))),
                  child: Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 22)),
              ),
              const SizedBox(width: 10),
            ] else ...[
              // Reminder + chat icon buttons
              GestureDetector(
                onTap: () => _saveReminder(place),
                child: Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: AppTheme.surfaceWarm, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                  child: const Icon(Icons.alarm_rounded, color: AppTheme.primary, size: 22)),
              ),
              const SizedBox(width: 10),
            ],
            // Directions / main CTA — teal pill matching reference
            Expanded(child: SizedBox(height: 52, child: ElevatedButton.icon(
              onPressed: () => _openDirections(place),
              icon: const Icon(Icons.directions_rounded, size: 20),
              label: const Text('Get Directions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ))),
          ]),
        );
      },
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _VisitInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _VisitInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppTheme.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(value, style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  const _StatChip({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 4),
        Flexible(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark), overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textLight)),
    ]));
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, height: 32, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 8));
  }
}

class _ReportInput {
  final String reason;
  final String details;

  const _ReportInput({required this.reason, required this.details});
}

class _HelpfulButton extends StatelessWidget {
  final String placeId, reviewId, reviewOwnerId;
  final String? currentUserId;
  final int count;
  final VoidCallback onTap;
  const _HelpfulButton({required this.placeId, required this.reviewId, required this.reviewOwnerId, required this.currentUserId, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null || currentUserId == reviewOwnerId) return _HelpfulPill(isActive: false, count: count, onTap: null);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('places').doc(placeId).collection('reviews').doc(reviewId).collection('helpfulVotes').doc(currentUserId).snapshots(),
      builder: (_, snap) => _HelpfulPill(isActive: snap.data?.exists ?? false, count: count, onTap: onTap),
    );
  }
}

class _HelpfulPill extends StatelessWidget {
  final bool isActive;
  final int count;
  final VoidCallback? onTap;
  const _HelpfulPill({required this.isActive, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryLight : AppTheme.surfaceWarm,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: isActive ? AppTheme.primaryDim : AppTheme.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isActive ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, size: 14, color: isActive ? AppTheme.primary : AppTheme.textLight),
            const SizedBox(width: 5),
            Text('$count helpful', style: GoogleFonts.poppins(fontSize: 11, color: isActive ? AppTheme.primary : AppTheme.textMid, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _VideoPlayerCard extends StatefulWidget {
  final String url;
  const _VideoPlayerCard({required this.url});
  @override
  State<_VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<_VideoPlayerCard> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) { if (mounted) setState(() => _ready = true); });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: _ready ? _controller.value.aspectRatio : 16 / 9,
        child: Stack(alignment: Alignment.center, children: [
          Container(color: AppTheme.surfaceWarm),
          if (_ready) GestureDetector(
            onTap: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
            child: VideoPlayer(_controller),
          ) else const CircularProgressIndicator(color: AppTheme.primary),
          if (_ready && !_controller.value.isPlaying)
            DecoratedBox(
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), shape: BoxShape.circle),
              child: const Padding(padding: EdgeInsets.all(14), child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34)),
            ),
        ]),
      ),
    );
  }
}
