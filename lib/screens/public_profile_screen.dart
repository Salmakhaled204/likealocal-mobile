import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/place.dart';
import '../models/user_role.dart';
import '../theme/app_theme.dart';
import 'place_details_screen.dart';

class PublicProfileScreen extends StatelessWidget {
  final String userId;
  final String fallbackName;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName = 'User',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data();
          if (data == null) {
            return Center(child: Text('$fallbackName has no profile yet.'));
          }

          final isPublic = data['publicProfile'] != false;
          final role = UserRole.fromData(data);
          final name = (data['displayName'] ?? data['name'] ?? fallbackName)
              .toString()
              .trim();
          final bio = (data['bio'] ?? '').toString().trim();
          final photoUrl = (data['photoUrl'] ?? '').toString().trim();

          if (!isPublic) {
            return _PrivateProfile(name: name.isEmpty ? fallbackName : name);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              _ProfileHeader(
                name: name.isEmpty ? fallbackName : name,
                bio: bio,
                photoUrl: photoUrl,
                role: role,
              ),
              const SizedBox(height: 16),
              _StatsRow(role: role),
              const SizedBox(height: 22),
              Text(
                'Shared places',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              _SharedPlaces(userId: userId),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String bio;
  final String photoUrl;
  final UserRole role;

  const _ProfileHeader({
    required this.name,
    required this.bio,
    required this.photoUrl,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final color = role.isAdmin
        ? Colors.red[700]!
        : role.isSuperUser
        ? Colors.amber[700]!
        : role.isContributor
        ? AppTheme.primary
        : AppTheme.softBlue;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: color.withValues(alpha: 0.14),
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Badge(label: role.roleLabel, color: color),
                    if (role.isPremium)
                      _Badge(label: 'Premium', color: Colors.purple),
                  ],
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    bio,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textMid,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final UserRole role;

  const _StatsRow({required this.role});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          label: 'Places',
          value: '${role.stats.approvedContributions}',
          icon: Icons.add_location_alt_outlined,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'Reviews',
          value: '${role.stats.totalReviews}',
          icon: Icons.rate_review_outlined,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'Helpful',
          value: '${role.stats.helpfulVotes}',
          icon: Icons.thumb_up_alt_outlined,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedPlaces extends StatelessWidget {
  final String userId;

  const _SharedPlaces({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('places')
          .where('ownerId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'No shared places yet.',
              style: GoogleFonts.poppins(color: AppTheme.textLight),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final place = Place.fromFirestore(doc);
            return _PlaceRow(place: place);
          }).toList(),
        );
      },
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final Place place;

  const _PlaceRow({required this.place});

  @override
  Widget build(BuildContext context) {
    final imageUrl = place.imageUrls.isNotEmpty ? place.imageUrls.first : '';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 58,
                      height: 58,
                      color: AppTheme.primaryLight,
                      child: const Icon(Icons.place_outlined),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    place.category,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
          ],
        ),
      ),
    );
  }
}

class _PrivateProfile extends StatelessWidget {
  final String name;

  const _PrivateProfile({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 44, color: AppTheme.textLight),
            const SizedBox(height: 14),
            Text(
              '$name keeps their profile private.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
