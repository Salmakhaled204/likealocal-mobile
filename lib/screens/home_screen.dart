import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/home_provider.dart';
import '../models/place.dart';
import '../models/user_role.dart';
import '../services/favorite_service.dart';
import '../theme/app_theme.dart';
import '../widgets/place_card.dart';
import '../widgets/shimmer_loading.dart';
import 'place_details_screen.dart';
import 'search_screen.dart';
import 'map_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'add_place_screen.dart';
import 'ai_chat_screen.dart';
import 'chat_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      _HomeTab(),
      SearchScreen(),
      FavoritesScreen(),
      ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final hp = context.read<HomeProvider>();
      hp.fetchPlaces();
      if (uid != null) hp.fetchPersonalizedRecommendationsForUser(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: FutureBuilder<UserRole>(
        future: uid == null
            ? Future.value(UserRole.regularFree())
            : fetchUserRole(uid),
        builder: (context, snapshot) {
          final role = snapshot.data ?? UserRole.regularFree();
          return FloatingActionButton(
            onPressed: () => _handleAddPlaceTap(context, role),
            backgroundColor: role.canAddPlaces
                ? AppTheme.primary
                : AppTheme.textLight,
            foregroundColor: Colors.white,
            elevation: 6,
            child: Icon(
              role.canAddPlaces
                  ? Icons.add_rounded
                  : Icons.lock_outline_rounded,
              size: 28,
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }

  void _handleAddPlaceTap(BuildContext context, UserRole role) {
    if (role.canAddPlaces) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddPlaceScreen()),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contributor access needed'),
        content: const Text(
          'Only Contributors, Super Users, and Admins can add places. Regular users can explore, review, save, chat, and set reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 3);
            },
            child: const Text('View profile'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation bar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _BottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        notchMargin: 10,
        shape: const CircularNotchedRectangle(),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.search_outlined,
                activeIcon: Icons.search_rounded,
                label: 'Explore',
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              const SizedBox(width: 60), // FAB notch
              _NavItem(
                icon: Icons.bookmark_outline_rounded,
                activeIcon: Icons.bookmark_rounded,
                label: 'Saved',
                index: 2,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: active ? AppTheme.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                active ? activeIcon : icon,
                color: active ? AppTheme.primary : AppTheme.textLight,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppTheme.primary : AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home tab
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  void _goToDetails(BuildContext context, Place place) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = (user?.displayName ?? 'Explorer').split(' ').first;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () async {
            final uid = user?.uid;
            final hp = context.read<HomeProvider>();
            await hp.fetchPlaces();
            if (uid != null) {
              await hp.fetchPersonalizedRecommendationsForUser(uid);
            }
          },
          child: CustomScrollView(
            slivers: [
              // ── Header ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  color: AppTheme.dustyPink,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Discover Local',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppTheme.textLight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hello, $firstName 👋',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _IconBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        color: AppTheme.softBlue,
                        bg: const Color(0xFFE8F1F9),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ChatListScreen()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _NotificationBell(
                        onTap: () =>
                            Navigator.pushNamed(context, '/notifications'),
                      ),
                      const SizedBox(width: 8),
                      _IconBtn(
                        icon: Icons.auto_awesome_rounded,
                        color: AppTheme.peach,
                        bg: AppTheme.peachLight,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AiChatScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                        child: _Avatar(user: user, firstName: firstName),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Category chips ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _Chip(label: 'All', isActive: true),
                        _Chip(label: 'Food'),
                        _Chip(label: 'Culture'),
                        _Chip(label: 'Nightlife'),
                        _Chip(label: 'Hidden Gems'),
                        _Chip(label: 'Cafes'),
                      ],
                    ),
                  ),
                ),
              ),

              // ── AI pick banner ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiChatScreen()),
                  ),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryLight,
                          const Color(0xFFF0EDF9),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.primaryDim.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI pick for you ✨',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                              Text(
                                'Let AI find your perfect local spot',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Near me ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Consumer<HomeProvider>(
                  builder: (context, hp, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 28, 22, 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Near me',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MapScreen(),
                                  ),
                                ),
                                child: Text(
                                  'See all',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hp.isLoadingRecommendations)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 22),
                            child: ShimmerLoadingHorizontal(),
                          )
                        else if (hp.recommendations.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: Text(
                              'No recommendations yet.',
                              style: GoogleFonts.poppins(
                                color: AppTheme.textLight,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 220,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              itemCount: hp.recommendations.length,
                              itemBuilder: (context, i) {
                                final place = hp.recommendations[i];
                                return _NearbyCard(
                                  place: place,
                                  onTap: () => _goToDetails(context, place),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // ── Trending header ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trending',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'See all',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── All places ─────────────────────────────────────────────
              Consumer<HomeProvider>(
                builder: (context, hp, _) {
                  if (hp.isLoading) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22),
                        child: ShimmerLoadingList(),
                      ),
                    );
                  }

                  if (hp.errorMessage != null) {
                    return SliverToBoxAdapter(
                      child: _ErrorState(
                        message: hp.errorMessage!,
                        onRetry: hp.fetchPlaces,
                      ),
                    );
                  }

                  if (hp.places.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptyState(
                        icon: Icons.explore_outlined,
                        title: 'No places yet',
                        subtitle: 'Be the first to add one!',
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == hp.places.length) {
                        return const SizedBox(height: 100);
                      }
                      final place = hp.places[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: PlaceCard(
                          place: place,
                          onTap: () => _goToDetails(context, place),
                        ),
                      );
                    }, childCount: hp.places.length + 1),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final VoidCallback onTap;
  const _NotificationBell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _IconBtn(
        icon: Icons.notifications_none_rounded,
        color: AppTheme.primary,
        bg: AppTheme.primaryLight,
        onTap: onTap,
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        final unread = snap.data?.docs.length ?? 0;
        return GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppTheme.dustyPink,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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

class _Avatar extends StatelessWidget {
  final User? user;
  final String firstName;

  const _Avatar({required this.user, required this.firstName});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = user?.photoURL != null && user!.photoURL!.isNotEmpty;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primaryDim, width: 2),
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(user!.photoURL!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasPhoto
          ? null
          : Center(
              child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;

  const _Chip({required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppTheme.primary : AppTheme.border,
        ),
        boxShadow: isActive ? AppTheme.softShadow : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isActive ? Colors.white : AppTheme.textMid,
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
  bool _isFavorite = false;
  bool _isLoading = true;

  Place get place => widget.place;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final saved = await FavoriteService.isFavorite(widget.place.id);
    if (mounted) {
      setState(() {
        _isFavorite = saved;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;
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
                      onTap: _toggleFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isFavorite
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: _isFavorite
                              ? AppTheme.primary
                              : AppTheme.dustyPink,
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
                            '· ${place.budget}',
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.peachLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 36,
              color: AppTheme.peach,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: AppTheme.textMid, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: AppTheme.textLight, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
