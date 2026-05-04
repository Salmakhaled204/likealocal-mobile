import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/place.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final Place place;
  const PlaceDetailsScreen({super.key, required this.place});

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  final _reviewController = TextEditingController();
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
    _reviewController.dispose();
    super.dispose();
  }

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
      _showSnack('Log in to save favorites.');
      return;
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(_placeId);

    final nextValue = !_isFavorite;
    setState(() => _isFavorite = nextValue);

    try {
      if (nextValue) {
        await ref.set({
          ...place.toFirestore(),
          'placeId': _placeId,
          'savedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.delete();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFavorite = !nextValue);
        _showSnack('Could not update favorite.');
      }
    }
  }

  Future<void> _submitReview() async {
    final uid = _uid;
    if (uid == null) {
      _showSnack('Log in to leave a review.');
      return;
    }

    final text = _reviewController.text.trim();
    if (text.isEmpty) {
      _showSnack('Write a review first.');
      return;
    }

    setState(() => _isSubmittingReview = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final reviewsRef = FirebaseFirestore.instance
          .collection('places')
          .doc(_placeId)
          .collection('reviews');
      final reviewRef = reviewsRef.doc(_editingReviewId ?? uid);

      await reviewRef.set({
        'userId': uid,
        'userEmail': user.email ?? '',
        'userName': user.displayName ?? '',
        'text': text,
        'rating': _selectedRating,
        'updatedAt': FieldValue.serverTimestamp(),
        if (_editingReviewId == null) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _recalculateRating();
      _reviewController.clear();
      setState(() {
        _editingReviewId = null;
        _selectedRating = 5;
      });
    } catch (_) {
      _showSnack('Failed to submit review.');
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _confirmDeleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) await _deleteReview(reviewId);
  }

  Future<void> _deleteReview(String reviewId) async {
    try {
      await FirebaseFirestore.instance
          .collection('places')
          .doc(_placeId)
          .collection('reviews')
          .doc(reviewId)
          .delete();
      await _recalculateRating();
    } catch (_) {
      _showSnack('Failed to delete review.');
    }
  }

  Future<void> _recalculateRating() async {
    final snap = await FirebaseFirestore.instance
        .collection('places')
        .doc(_placeId)
        .collection('reviews')
        .get();

    final average = snap.docs.isEmpty
        ? 0.0
        : snap.docs.fold<double>(
              0,
              (sum, doc) => sum + ((doc.data()['rating'] as num?) ?? 0),
            ) /
            snap.docs.length;

    await FirebaseFirestore.instance
        .collection('places')
        .doc(_placeId)
        .update({'averageRating': average});
  }

  void _startEditing(String reviewId, String text, int rating) {
    setState(() {
      _editingReviewId = reviewId;
      _selectedRating = rating;
    });
    _reviewController.text = text;
  }

  void _cancelEditing() {
    setState(() {
      _editingReviewId = null;
      _selectedRating = 5;
    });
    _reviewController.clear();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

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
          backgroundColor: Colors.grey[50],
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(place),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, place),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildDescription(place),
                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 20),
                      _buildReviewsSection(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(Place place) {
    final images = place.imageUrls.isNotEmpty
        ? place.imageUrls
        : ['https://placehold.co/800x400/cccccc/999999?text=No+Image'];

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (!_isFavoriteLoading)
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: () => _toggleFavorite(place),
          ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: images.length,
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: images[i],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey[300]),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
            if (images.length > 1)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${images.length} photos',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            if (place.ownerIsSuperUser)
              Positioned(
                bottom: 20,
                left: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Super User Pick',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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

  Widget _buildHeader(BuildContext context, Place place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                place.title,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                place.category,
                style: GoogleFonts.inter(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
            const SizedBox(width: 6),
            Text(
              place.averageRating.toStringAsFixed(1),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '/ 5.0',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription(Place place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About this place',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          place.description,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: Colors.grey[700],
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    final canReview = _uid != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviews',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                canReview
                    ? _editingReviewId != null
                        ? 'Edit your review'
                        : 'Leave a review'
                    : 'Login required for reviews',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: canReview
                        ? () => setState(() => _selectedRating = star)
                        : null,
                    child: Icon(
                      star <= _selectedRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reviewController,
                enabled: canReview,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(
                  hintText: canReview
                      ? 'Share your experience...'
                      : 'Log in to share your experience.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_editingReviewId != null)
                    TextButton(
                      onPressed: _cancelEditing,
                      child: const Text('Cancel'),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed:
                        !canReview || _isSubmittingReview ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                        : Text(_editingReviewId != null ? 'Update' : 'Submit'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('places')
              .doc(_placeId)
              .collection('reviews')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text(
                'Could not load reviews.',
                style: GoogleFonts.inter(color: Colors.red),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No reviews yet. Be the first!',
                    style: GoogleFonts.inter(color: Colors.grey[500]),
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isOwner = data['userId'] == _uid;
                final rating = (data['rating'] as num?)?.toInt() ?? 0;
                final displayName = ((data['userName'] as String?) ?? '').trim();
                final email = ((data['userEmail'] as String?) ?? '').trim();
                final label = displayName.isNotEmpty
                    ? displayName
                    : email.isNotEmpty
                        ? email
                        : 'Anonymous';
                final date = _formatTimestamp(data['updatedAt'] ?? data['createdAt']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              label.isNotEmpty ? label[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
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
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                    ),
                                    if (date.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        date,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey[500],
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
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _startEditing(
                                    doc.id,
                                    data['text'] ?? '',
                                    rating,
                                  );
                                } else if (val == 'delete') {
                                  _confirmDeleteReview(doc.id);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                              child: const Icon(
                                Icons.more_vert,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['text'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[700],
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
}
