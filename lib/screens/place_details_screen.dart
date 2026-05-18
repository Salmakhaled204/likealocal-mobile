import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place.dart';
import '../models/user_role.dart';
import '../theme/app_theme.dart';
import 'add_place_screen.dart';
import 'chat_service.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final Place place;
  const PlaceDetailsScreen({super.key, required this.place});

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  final _reviewCtrl = TextEditingController();
  int _selectedRating = 5;
  bool _isFavorite = false;
  bool _isFavoriteLoading = true;
  bool _isSubmittingReview = false;
  String? _editingReviewId;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String get _placeId => widget.place.id;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  // ── Favorite ──────────────────────────────────────────────────────────────

  Future<void> _checkFavorite() async {
    final uid = _uid;
    if (uid == null) {
      setState(() => _isFavoriteLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(_placeId)
          .get();
      if (mounted) {
        setState(() {
          _isFavorite = doc.exists;
          _isFavoriteLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isFavoriteLoading = false);
    }
  }

  Future<void> _toggleFavorite(Place place) async {
    final uid = _uid;
    if (uid == null) {
      _snack('Log in to save favorites.');
      return;
    }
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(_placeId);
    final nextValue = !_isFavorite;
    try {
      if (nextValue) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final role = UserRole.fromData(userDoc.data());
        final current = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('favorites')
            .limit(6)
            .get();
        if (current.docs.length >= role.maxPins) {
          if (mounted) _showPremiumDialog();
          return;
        }
        if (mounted) setState(() => _isFavorite = true);
        await ref.set({
          ...place.toFirestore(),
          'placeId': _placeId,
          'savedAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'limits': {'pinsUsed': FieldValue.increment(1)},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        if (mounted) setState(() => _isFavorite = false);
        await ref.delete();
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'limits': {'pinsUsed': FieldValue.increment(-1)},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFavorite = !nextValue);
        _snack('Could not update favorite.');
      }
    }
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  Future<void> _submitReview() async {
    final uid = _uid;
    if (uid == null) {
      _snack('Log in to leave a review.');
      return;
    }
    final text = _reviewCtrl.text.trim();
    if (text.isEmpty) {
      _snack('Write a review first.');
      return;
    }
    setState(() => _isSubmittingReview = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final ref = FirebaseFirestore.instance
          .collection('places')
          .doc(_placeId)
          .collection('reviews')
          .doc(_editingReviewId ?? uid);
      await ref.set({
        'userId': uid,
        'userEmail': user.email ?? '',
        'userName': user.displayName ?? '',
        'text': text,
        'rating': _selectedRating,
        'updatedAt': FieldValue.serverTimestamp(),
        if (_editingReviewId == null) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _recalcRating();
      _reviewCtrl.clear();
      setState(() {
        _editingReviewId = null;
        _selectedRating = 5;
      });
    } catch (_) {
      _snack('Failed to submit review.');
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _confirmDeleteReview(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteReview(id);
  }

  Future<void> _deleteReview(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('places')
          .doc(_placeId)
          .collection('reviews')
          .doc(id)
          .delete();
      await _recalcRating();
    } catch (_) {
      _snack('Failed to delete review.');
    }
  }

  Future<void> _recalcRating() async {
    final snap = await FirebaseFirestore.instance
        .collection('places')
        .doc(_placeId)
        .collection('reviews')
        .get();
    final avg = snap.docs.isEmpty
        ? 0.0
        : snap.docs.fold<double>(
                0,
                (t, d) => t + ((d.data()['rating'] as num?) ?? 0),
              ) /
              snap.docs.length;
    await FirebaseFirestore.instance.collection('places').doc(_placeId).update({
      'averageRating': avg,
      'reviewCount': snap.docs.length,
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openDirections(Place place) async {
    final lat = place.location.latitude;
    final lng = place.location.longitude;
    if (lat == 0 && lng == 0) {
      _snack('Directions unavailable.');
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Could not open maps.');
    }
  }

  Future<void> _saveReminder(Place place) async {
    final uid = _uid;
    if (uid == null) {
      _snack('Log in to set reminders.');
      return;
    }
    final lat = place.location.latitude;
    final lng = place.location.longitude;
    if (lat == 0 && lng == 0) {
      _snack('No location data for reminders.');
      return;
    }
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final role = UserRole.fromData(userDoc.data());
    final reminders = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('locationReminders')
        .limit(role.maxReminders + 1)
        .get();
    final alreadySaved = reminders.docs.any((doc) => doc.id == place.id);
    if (!alreadySaved && reminders.docs.length >= role.maxReminders) {
      _snack(
        'You can set up to ${role.maxReminders} reminders on ${role.subscriptionLabel}.',
      );
      return;
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('locationReminders')
        .doc(place.id)
        .set({
          'placeId': place.id,
          'title': place.title,
          'location': place.location,
          'enabled': true,
          'radiusMeters': 300,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    if (!alreadySaved) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'limits': {'remindersUsed': FieldValue.increment(1)},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Reminder saved. Enable location for alerts.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final dist = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        lat,
        lng,
      );
      _snack(
        dist <= 300
            ? 'Reminder saved. You\'re already nearby!'
            : 'Reminder saved!',
      );
    } catch (_) {
      _snack('Reminder saved.');
    }
  }

  Future<void> _deletePlace() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete place?'),
        content: const Text('This removes the place for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('places')
          .doc(_placeId)
          .delete();
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Place deleted.');
    } catch (_) {
      _snack('Could not delete this place.');
    }
  }

  void _showPremiumDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upgrade to Premium'),
        content: const Text(
          'You reached your saved-place limit. Free users can save 5 places, Super Users can save 20, and Premium users can save 100.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startEditing(String id, String text, int rating) {
    setState(() {
      _editingReviewId = id;
      _selectedRating = rating;
    });
    _reviewCtrl.text = text;
  }

  void _cancelEditing() {
    setState(() {
      _editingReviewId = null;
      _selectedRating = 5;
    });
    _reviewCtrl.clear();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDate(dynamic v) {
    if (v is! Timestamp) return '';
    final d = v.toDate();
    return '${d.day}/${d.month}/${d.year}';
  }

  // ── Open video URL in browser ─────────────────────────────────────────────
  Future<void> _openVideo(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Could not open video.');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('places')
          .doc(_placeId)
          .snapshots(),
      builder: (context, snapshot) {
        final place = snapshot.hasData && snapshot.data!.exists
            ? Place.fromFirestore(snapshot.data!)
            : widget.place;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: CustomScrollView(
            slivers: [
              _buildAppBar(place),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(place),
                      const SizedBox(height: 20),
                      _buildActions(context, place),
                      const SizedBox(height: 26),
                      _Section(
                        title: 'About',
                        child: Text(
                          place.description,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textMid,
                            height: 1.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ── MISS-070: Video playback section ─────────────────
                      if (place.videoUrls.isNotEmpty) ...[
                        _buildVideos(place),
                        const SizedBox(height: 24),
                      ],
                      _buildLocalDetails(place),
                      const SizedBox(height: 24),
                      _buildReviews(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomCTA(place),
        );
      },
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(Place place) {
    final images = place.imageUrls.isNotEmpty
        ? place.imageUrls
        : ['https://placehold.co/800x400/F5F3F0/A5A5BB?text=LikeALocal'];

    return SliverAppBar(
      expandedHeight: 310,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.background,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _CircleBtn(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: _isFavoriteLoading
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                )
              : _CircleBtn(
                  icon: _isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  iconColor: _isFavorite
                      ? AppTheme.dustyPink
                      : AppTheme.textMid,
                  onTap: () => _toggleFavorite(place),
                ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: images.length,
              itemBuilder: (context, i) => CachedNetworkImage(
                imageUrl: images[i],
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: AppTheme.surfaceWarm),
                errorWidget: (context, url, error) => Container(
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
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black38],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            if (images.length > 1)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${images.length} photos',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            if (place.ownerIsSuperUser)
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Super User Pick',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(Place place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                place.category,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.mintLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Open now',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mint,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          place.title,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
            height: 1.2,
          ),
        ),
        if (place.address.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 15,
                color: AppTheme.dustyPink,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  place.address,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textLight,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(5, (i) {
                return Icon(
                  i < place.averageRating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: AppTheme.amber,
                  size: 20,
                );
              }),
              const SizedBox(width: 10),
              Text(
                place.averageRating.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${place.reviewCount} reviews)',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Quick actions ─────────────────────────────────────────────────────────

  Widget _buildActions(BuildContext context, Place place) {
    final uid = _uid;
    return FutureBuilder<UserRole>(
      future: uid == null
          ? Future.value(UserRole.regularFree())
          : fetchUserRole(uid),
      builder: (context, snapshot) {
        final role = snapshot.data ?? UserRole.regularFree();
        final canManage =
            uid != null && role.canManagePlace(place.ownerId, uid);
        final canMessageOwner =
            uid != null && place.ownerId.isNotEmpty && place.ownerId != uid;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ActionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message owner',
              color: AppTheme.softBlue,
              bg: const Color(0xFFE8F1F9),
              onTap: canMessageOwner
                  ? () => ChatService.startChat(
                      context,
                      place.ownerId,
                      otherUserName: place.ownerName,
                    )
                  : null,
            ),
            _ActionBtn(
              icon: Icons.notifications_active_outlined,
              label: 'Remind me',
              color: AppTheme.peach,
              bg: AppTheme.peachLight,
              onTap: () => _saveReminder(place),
            ),
            if (canManage) ...[
              _ActionBtn(
                icon: Icons.edit_outlined,
                label: role.isAdmin ? 'Admin edit' : 'Edit',
                color: AppTheme.primary,
                bg: AppTheme.primaryLight,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddPlaceScreen(placeToEdit: place),
                  ),
                ),
              ),
              _ActionBtn(
                icon: Icons.delete_outline_rounded,
                label: role.isAdmin ? 'Admin delete' : 'Delete',
                color: AppTheme.errorColor,
                bg: const Color(0xFFFDECEC),
                onTap: _deletePlace,
              ),
            ],
          ],
        );
      },
    );
  }

  // ── MISS-070: Videos section ──────────────────────────────────────────────

  Widget _buildVideos(Place place) {
    return _Section(
      title: 'Videos',
      child: Column(
        children: place.videoUrls.asMap().entries.map((entry) {
          final index = entry.key;
          final url = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.softShadow,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openVideo(url),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Play button icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.play_circle_filled_rounded,
                          color: AppTheme.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Video ${index + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to play',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: AppTheme.textLight,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Local details ─────────────────────────────────────────────────────────

  Widget _buildLocalDetails(Place place) {
    final rows =
        <
          ({
            IconData icon,
            Color iconColor,
            Color iconBg,
            String label,
            String value,
          })
        >[
          if (place.budget.isNotEmpty)
            (
              icon: Icons.payments_outlined,
              iconColor: AppTheme.mint,
              iconBg: AppTheme.mintLight,
              label: 'Budget',
              value: place.budget,
            ),
          if (place.atmosphere.isNotEmpty)
            (
              icon: Icons.groups_outlined,
              iconColor: AppTheme.softBlue,
              iconBg: const Color(0xFFE8F1F9),
              label: 'Vibe',
              value: place.atmosphere,
            ),
          if (place.localTip.isNotEmpty)
            (
              icon: Icons.lightbulb_outline,
              iconColor: AppTheme.amber,
              iconBg: const Color(0xFFFDF6E3),
              label: 'Local tip',
              value: place.localTip,
            ),
          if (place.recommendedDish.isNotEmpty)
            (
              icon: Icons.restaurant_menu_outlined,
              iconColor: AppTheme.peach,
              iconBg: AppTheme.peachLight,
              label: 'Must try',
              value: place.recommendedDish,
            ),
          if (place.ownerName.isNotEmpty)
            (
              icon: Icons.person_outline_rounded,
              iconColor: AppTheme.primary,
              iconBg: AppTheme.primaryLight,
              label: 'Contributor',
              value: place.ownerName,
            ),
        ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'Local details',
      child: Column(
        children: rows.map((r) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: r.iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(r.icon, size: 20, color: r.iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.label,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.value,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  Widget _buildReviews() {
    final canReview = _uid != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviews',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                canReview
                    ? _editingReviewId != null
                          ? 'Edit your review'
                          : 'Leave a review'
                    : 'Log in to leave a review',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: canReview
                        ? () => setState(() => _selectedRating = star)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        star <= _selectedRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: AppTheme.amber,
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reviewCtrl,
                enabled: canReview,
                maxLines: 3,
                maxLength: 300,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
                decoration: InputDecoration(
                  hintText: canReview
                      ? 'Share your experience…'
                      : 'Log in to share your experience.',
                  counterStyle: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textLight,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_editingReviewId != null) ...[
                    TextButton(
                      onPressed: _cancelEditing,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: !canReview || _isSubmittingReview
                          ? null
                          : _submitReview,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(80, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: _isSubmittingReview
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _editingReviewId != null ? 'Update' : 'Submit',
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('places')
              .doc(_placeId)
              .collection('reviews')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No reviews yet. Be the first! 🌟',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textLight,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isOwner = data['userId'] == _uid;
                final rating = (data['rating'] as num?)?.toInt() ?? 0;
                final name = ((data['userName'] as String?) ?? '').trim();
                final email = ((data['userEmail'] as String?) ?? '').trim();
                final label = name.isNotEmpty
                    ? name
                    : email.isNotEmpty
                    ? email
                    : 'Anonymous';
                final date = _fmtDate(data['updatedAt'] ?? data['createdAt']);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                label.isNotEmpty ? label[0].toUpperCase() : '?',
                                style: GoogleFonts.poppins(
                                  color: AppTheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    ...List.generate(
                                      5,
                                      (i) => Icon(
                                        i < rating
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        color: AppTheme.amber,
                                        size: 13,
                                      ),
                                    ),
                                    if (date.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        date,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppTheme.textLight,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isOwner)
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _startEditing(
                                    doc.id,
                                    data['text'] ?? '',
                                    rating,
                                  );
                                } else {
                                  _confirmDeleteReview(doc.id);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(
                                    'Edit',
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete',
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ),
                              ],
                              child: Icon(
                                Icons.more_vert_rounded,
                                size: 18,
                                color: AppTheme.textLight,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data['text'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textMid,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ── Bottom CTA ────────────────────────────────────────────────────────────

  Widget _buildBottomCTA(Place place) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _openDirections(place),
          icon: const Icon(Icons.directions_rounded, size: 20),
          label: const Text('Get directions'),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.icon,
    this.iconColor = AppTheme.textDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
