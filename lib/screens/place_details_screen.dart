import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../models/review.dart';
import '../providers/favorites_provider.dart';
import '../providers/home_provider.dart';
import '../providers/reviews_provider.dart';
import '../providers/search_provider.dart';

class PlaceDetailsScreen extends StatelessWidget {
  final Place place;

  const PlaceDetailsScreen({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('places')
          .doc(place.id)
          .snapshots(),
      builder: (context, snapshot) {
        final currentPlace = snapshot.hasData && snapshot.data!.exists
            ? Place.fromFirestore(snapshot.data!)
            : place;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: CustomScrollView(
            slivers: [
              _DetailsAppBar(place: currentPlace),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PlaceSummary(place: currentPlace),
                      const SizedBox(height: 24),
                      _ReviewComposer(placeId: currentPlace.id),
                      const SizedBox(height: 24),
                      _ReviewsList(placeId: currentPlace.id),
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
}

class _DetailsAppBar extends StatelessWidget {
  final Place place;

  const _DetailsAppBar({required this.place});

  @override
  Widget build(BuildContext context) {
    final imageUrl = place.imageUrls.isNotEmpty
        ? place.imageUrls.first
        : 'https://via.placeholder.com/900x500?text=No+Image';

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      actions: [
        StreamBuilder<bool>(
          stream: context.read<FavoritesProvider>().watchIsFavorite(place.id),
          builder: (context, snapshot) {
            final isFavorite = snapshot.data ?? false;
            return IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              tooltip: isFavorite ? 'Remove favorite' : 'Save favorite',
              onPressed: () async {
                await context
                    .read<FavoritesProvider>()
                    .toggleFavorite(place, isFavorite);
              },
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          place.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.75),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceSummary extends StatelessWidget {
  final Place place;

  const _PlaceSummary({required this.place});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _InfoPill(icon: Icons.category, label: place.category),
            const SizedBox(width: 8),
            _InfoPill(
              icon: Icons.star,
              label: place.averageRating.toStringAsFixed(1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          place.description,
          style: GoogleFonts.inter(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.place, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${place.location.latitude.toStringAsFixed(4)}, '
                '${place.location.longitude.toStringAsFixed(4)}',
                style: GoogleFonts.inter(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewComposer extends StatefulWidget {
  final String placeId;

  const _ReviewComposer({required this.placeId});

  @override
  State<_ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<_ReviewComposer> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Consumer<ReviewsProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLoggedIn ? 'Write a review' : 'Login required for reviews',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isLoggedIn) ...[
                const SizedBox(height: 8),
                Text(
                  'You can view this page now, but posting reviews needs a logged-in Firebase user.',
                  style: GoogleFonts.inter(color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 12),
              _StarPicker(
                rating: _rating,
                onChanged: isLoggedIn
                    ? (rating) => setState(() => _rating = rating)
                    : (_) {},
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                enabled: isLoggedIn,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (provider.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  provider.errorMessage!,
                  style: GoogleFonts.inter(color: Colors.red),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !isLoggedIn || provider.isSaving
                      ? null
                      : _submitReview,
                  child: provider.isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Post Review'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReview() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a comment first.')),
      );
      return;
    }

    await context.read<ReviewsProvider>().addReview(
          placeId: widget.placeId,
          rating: _rating,
          comment: comment,
        );

    if (!mounted) return;
    _commentController.clear();
    setState(() => _rating = 5);
    context.read<HomeProvider>().fetchPlaces();
    context.read<SearchProvider>().setSearchQuery(
          context.read<SearchProvider>().searchQuery,
        );
  }
}

class _ReviewsList extends StatelessWidget {
  final String placeId;

  const _ReviewsList({required this.placeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Review>>(
      stream: context.read<ReviewsProvider>().watchReviews(placeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No reviews yet',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reviews',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...reviews.map((review) {
              return _ReviewTile(placeId: placeId, review: review);
            }),
          ],
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final String placeId;
  final Review review;

  const _ReviewTile({required this.placeId, required this.review});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final canEdit = currentUserId == review.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.userEmail,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    size: 18,
                    color: Colors.amber,
                  );
                }),
              ),
              if (canEdit)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditReviewSheet(context);
                    } else if (value == 'delete') {
                      context.read<ReviewsProvider>().deleteReview(
                            placeId: placeId,
                            reviewId: review.id,
                          );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(review.comment, style: GoogleFonts.inter(height: 1.35)),
        ],
      ),
    );
  }

  void _showEditReviewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditReviewSheet(placeId: placeId, review: review),
    );
  }
}

class _EditReviewSheet extends StatefulWidget {
  final String placeId;
  final Review review;

  const _EditReviewSheet({required this.placeId, required this.review});

  @override
  State<_EditReviewSheet> createState() => _EditReviewSheetState();
}

class _EditReviewSheetState extends State<_EditReviewSheet> {
  late final TextEditingController _commentController;
  late int _rating;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.review.comment);
    _rating = widget.review.rating;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit review',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _StarPicker(
            rating: _rating,
            onChanged: (rating) => setState(() => _rating = rating),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await context.read<ReviewsProvider>().editReview(
                      placeId: widget.placeId,
                      reviewId: widget.review.id,
                      rating: _rating,
                      comment: _commentController.text,
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const _StarPicker({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final value = index + 1;
        return IconButton(
          icon: Icon(value <= rating ? Icons.star : Icons.star_border),
          color: Colors.amber,
          tooltip: '$value stars',
          onPressed: () => onChanged(value),
        );
      }),
    );
  }
}
