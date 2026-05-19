import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/home_provider.dart';
import '../models/place.dart';
import '../models/user_role.dart';
import '../services/favorite_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';
import 'place_details_screen.dart';
import 'search_screen.dart';
import 'map_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'add_place_screen.dart';
import 'ai_chat_screen.dart';
import 'chat_list_screen.dart';
import 'settings_screen.dart';
import 'reminders_screen.dart';

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
    _screens = const [_HomeTab(), SearchScreen(), FavoritesScreen(), ProfileScreen()];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final hp = context.read<HomeProvider>();
      hp.fetchPlaces();
      if (uid != null) {
        hp.fetchPersonalizedRecommendationsForUser(uid);
        _checkAndPromoteSuperUser(uid);
      }
    });
  }

  Future<void> _checkAndPromoteSuperUser(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final role = UserRole.fromData(doc.data());
      if (!role.isAdmin && !role.isSuperUser && role.qualifiesForSuperUser) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {'role': AppUserRole.superUser, 'isSuperUser': true, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.workspace_premium_rounded, color: AppTheme.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('🎉 You\'ve been promoted to Super User!', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white))),
            ]),
            duration: const Duration(seconds: 4),
          ));
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayLight);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: _AppDrawer(uid: uid),
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: FutureBuilder<UserRole>(
        future: uid == null ? Future.value(UserRole.regularFree()) : fetchUserRole(uid),
        builder: (_, snap) {
          final role = snap.data ?? UserRole.regularFree();
          final canAddPlaces = uid != null && role.canAddPlaces;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: canAddPlaces ? AppTheme.tealShadow : [],
            ),
            child: FloatingActionButton(
              onPressed: () => _handleAddPlaceTap(context, role),
              backgroundColor: canAddPlaces ? AppTheme.primary : AppTheme.surfaceHigh,
              foregroundColor: canAddPlaces ? Colors.white : AppTheme.textLight,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Icon(canAddPlaces ? Icons.add_rounded : Icons.lock_outline_rounded, size: 28),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(currentIndex: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
    );
  }

  void _handleAddPlaceTap(BuildContext context, UserRole role) {
    if (FirebaseAuth.instance.currentUser != null && role.canAddPlaces) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlaceScreen()));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign in needed'),
        content: const Text('Create an account or sign in to add local places.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          TextButton(onPressed: () { Navigator.pop(ctx); setState(() => _currentIndex = 3); }, child: const Text('View profile')),
        ],
      ),
    );
  }
}

// ── Drawer ─────────────────────────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  final String? uid;
  const _AppDrawer({this.uid});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Explorer';
    final email = user?.email ?? '';
    final hasPhoto = user?.photoURL?.isNotEmpty == true;

    return Drawer(
      backgroundColor: AppTheme.surface,
      width: 285,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 54, 22, 28),
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 34, backgroundColor: AppTheme.accent,
                backgroundImage: hasPhoto ? NetworkImage(user!.photoURL!) : null,
                child: hasPhoto ? null : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              Text(name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              if (email.isNotEmpty) Text(email, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              children: [
                _DrawerItem(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.pop(context)),
                _DrawerItem(icon: Icons.explore_rounded, label: 'Explore Map', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())); }),
                _DrawerItem(icon: Icons.alarm_rounded, label: 'My Reminders', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen())); }),
                _DrawerItem(icon: Icons.chat_bubble_rounded, label: 'Messages', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())); }),
                _DrawerItem(icon: Icons.auto_awesome_rounded, label: 'AI Assistant', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())); }),
                Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Divider(color: AppTheme.border, thickness: 0.5)),
                _DrawerItem(icon: Icons.settings_rounded, label: 'Settings', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }),
                _DrawerItem(icon: Icons.logout_rounded, label: 'Logout', danger: true, onTap: () async { Navigator.pop(context); await FirebaseAuth.instance.signOut(); }),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: Text('LikeALocal v1.0', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textLight))),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.errorColor : AppTheme.primary;
    return ListTile(
      leading: Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 19)),
      title: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      dense: true,
    );
  }
}

// ── Bottom nav ──────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _BottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        notchMargin: 10,
        shape: const CircularNotchedRectangle(),
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', index: 0, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.search_outlined, activeIcon: Icons.search_rounded, label: 'Search', index: 1, current: currentIndex, onTap: onTap),
              const SizedBox(width: 60),
              _NavItem(icon: Icons.favorite_outline_rounded, activeIcon: Icons.favorite_rounded, label: 'Saved', index: 2, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', index: 3, current: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final void Function(int) onTap;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, color: active ? AppTheme.primary : AppTheme.textLight, size: 24),
            const SizedBox(height: 3),
            Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? AppTheme.primary : AppTheme.textLight)),
          ],
        ),
      ),
    );
  }
}

// ── Home Tab ───────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String _selectedCategory = 'All';
  final _cats = ['All', 'Food', 'Culture', 'Cafes', 'Hidden', 'Night'];

  // Category icon mapping
  static const _catIcons = {
    'All': Icons.apps_rounded,
    'Food': Icons.restaurant_rounded,
    'Culture': Icons.museum_rounded,
    'Cafes': Icons.local_cafe_rounded,
    'Hidden': Icons.explore_rounded,
    'Night': Icons.nightlife_rounded,
  };

  void _goToDetails(Place place) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)));

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = (user?.displayName ?? 'Explorer').split(' ').first;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayDark,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            final uid = user?.uid;
            final hp = context.read<HomeProvider>();
            await hp.fetchPlaces();
            if (uid != null) await hp.fetchPersonalizedRecommendationsForUser(uid);
          },
          child: CustomScrollView(
            slivers: [
              // ── Dark teal header (matches reference) ───────────────────
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 56, 22, 30),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.headerGradient,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row
                      Row(children: [
                        GestureDetector(
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: _buildAvatar(user, firstName),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Hi, $firstName', style: GoogleFonts.poppins(fontSize: 15, color: Colors.white70)),
                        ])),
                        _HeaderIconBtn(
                          icon: Icons.notifications_outlined,
                          onTap: () => Navigator.pushNamed(context, '/notifications'),
                          badge: _NotifBadge(uid: user?.uid),
                        ),
                        const SizedBox(width: 10),
                        _HeaderIconBtn(icon: Icons.menu_rounded, onTap: () => Scaffold.of(context).openDrawer()),
                      ]),
                      const SizedBox(height: 24),
                      // Headline
                      Text('Where do\nyou want to go?', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
                      const SizedBox(height: 20),
                      // Search bar — white pill
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: Row(children: [
                            Expanded(child: Text('Search your destination', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textLight))),
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Category icon row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _cats.map((cat) {
                          final active = cat == _selectedCategory;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: Column(children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: active ? AppTheme.accent : Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: active ? AppTheme.accent : Colors.white.withValues(alpha: 0.3), width: 1.5),
                                ),
                                child: Icon(_catIcons[cat] ?? Icons.place_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(height: 6),
                              Text(cat, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
                            ]),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Offline banner ─────────────────────────────────────────
              Consumer<HomeProvider>(builder: (_, hp, _) {
                if (!hp.isOffline) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.wifi_off_rounded, color: AppTheme.amber, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text("You're offline. Showing cached places.", style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.amber))),
                    ]),
                  ),
                );
              }),

              // ── AI Assistant banner ────────────────────────────────────
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE0F2EE), Color(0xFFC8EAE4)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.primaryDim),
                    ),
                    child: Row(children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('AI picks for you ✨', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
                        Text('Personalized local recommendations', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMid)),
                      ])),
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                      ),
                    ]),
                  ),
                ),
              ),

              // ── Popular Travel section header ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Popular Travel', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
                      child: Row(children: [
                        Text('Explore', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 3),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primary),
                      ]),
                    ),
                  ]),
                ),
              ),

              // ── 2-column grid (matches reference exactly) ──────────────
              Consumer<HomeProvider>(builder: (_, hp, _) {
                if (hp.isLoading) {
                  return SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: ShimmerLoadingGrid(),
                  ));
                }
                if (hp.errorMessage != null) {
                  return SliverToBoxAdapter(child: _ErrorState(message: hp.errorMessage!, onRetry: hp.fetchPlaces));
                }
                if (hp.places.isEmpty) {
                  return SliverToBoxAdapter(child: _EmptyState(icon: Icons.explore_outlined, title: 'No places yet', subtitle: 'Be the first to add one!'));
                }

              final filtered = _selectedCategory == 'All'
    ? hp.places
    : hp.places.where((p) {
        final selected = _selectedCategory.toLowerCase();

        final text = [
          p.title,
          p.description,
          p.category,
          p.address,
          p.atmosphere,
          p.localTip,
          p.recommendedDish,
        ].join(' ').toLowerCase();

        if (selected == 'food') {
          return text.contains('food') ||
              text.contains('restaurant') ||
              text.contains('restaurants') ||
              text.contains('cafe') ||
              text.contains('cafes') ||
              text.contains('coffee') ||
              text.contains('dessert') ||
              text.contains('brunch');
        }

        if (selected == 'culture') {
          return text.contains('culture') ||
              text.contains('museum') ||
              text.contains('palace') ||
              text.contains('history') ||
              text.contains('heritage') ||
              text.contains('art');
        }

        if (selected == 'hidden') {
          return text.contains('hidden') ||
              text.contains('hidden gems') ||
              text.contains('local') ||
              text.contains('secret');
        }

        if (selected == 'night') {
          return text.contains('night') ||
              text.contains('nightlife') ||
              text.contains('bar') ||
              text.contains('club') ||
              text.contains('evening');
        }

        return text.contains(selected);
      }).toList();
                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(child: _EmptyState(icon: Icons.search_off_rounded, title: 'No results', subtitle: 'Try a different category'));
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _GridPlaceCard(place: filtered[i], onTap: () => _goToDetails(filtered[i])),
                      childCount: filtered.length,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(User? user, String firstName) {
    final hasPhoto = user?.photoURL?.isNotEmpty == true;
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accent,
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        image: hasPhoto ? DecorationImage(image: NetworkImage(user!.photoURL!), fit: BoxFit.cover) : null,
      ),
      child: hasPhoto ? null : Center(child: Text(
        firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      )),
    );
  }
}

// ── Header icon button ─────────────────────────────────────────────────────────
class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Widget? badge;
  const _HeaderIconBtn({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        if (badge != null) Positioned(top: -2, right: -2, child: badge!),
      ]),
    );
  }
}

class _NotifBadge extends StatelessWidget {
  final String? uid;
  const _NotifBadge({this.uid});
  @override
  Widget build(BuildContext context) {
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').where('read', isEqualTo: false).snapshots(),
      builder: (_, snap) {
        final n = snap.data?.docs.length ?? 0;
        if (n == 0) return const SizedBox.shrink();
        return Container(
          width: 16, height: 16,
          decoration: const BoxDecoration(color: AppTheme.peach, shape: BoxShape.circle),
          child: Center(child: Text(n > 9 ? '9+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
        );
      },
    );
  }
}

// ── 2-column grid card (exactly like the reference) ────────────────────────────
class _GridPlaceCard extends StatefulWidget {
  final Place place;
  final VoidCallback onTap;
  const _GridPlaceCard({required this.place, required this.onTap});
  @override
  State<_GridPlaceCard> createState() => _GridPlaceCardState();
}

class _GridPlaceCardState extends State<_GridPlaceCard> {
  bool _isFav = false, _loading = true;

  Place get place => widget.place;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await FavoriteService.isFavorite(widget.place.id);

    if (mounted) {
      setState(() {
        _isFav = s;
        _loading = false;
      });
    }
  }

  Future<void> _toggle() async {
    if (_loading) return;

    final next = !_isFav;

    setState(() => _isFav = next);

    final result = await FavoriteService.togglePlace(
      widget.place,
      currentlySaved: !next,
    );

    if (!mounted) return;

    if (result == FavoriteResult.limitReached) {
      setState(() => _isFav = false);
      _snack('Limit reached.');
    } else if (result == FavoriteResult.loginRequired) {
      setState(() => _isFav = false);
      _snack('Log in first.');
    } else if (result == FavoriteResult.failed) {
      setState(() => _isFav = !next);
      _snack('Could not update.');
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    place.imageUrls.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: place.imageUrls.first,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              color: AppTheme.surfaceWarm,
                            ),
                            errorWidget: (_, _, _) => _imgFallback(),
                          )
                        : _imgFallback(),

                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0x881A2B2A),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.5, 1.0],
                        ),
                      ),
                    ),

                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _toggle,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _isFav
                                ? AppTheme.peach
                                : Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: _isFav
                                ? Colors.white
                                : AppTheme.peach,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                    if (place.ownerIsSuperUser)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Top',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 3),

                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 11,
                        color: AppTheme.textLight,
                      ),

                      const SizedBox(width: 2),

                      Expanded(
                        child: Text(
                          place.address.isNotEmpty
                              ? place.address
                              : place.category,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < place.averageRating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppTheme.amber,
                          size: 13,
                        ),
                      ),

                      const SizedBox(width: 4),

                      Text(
                        place.averageRating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textMid,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const Spacer(),

                      if (place.budget.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            place.budget,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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

  Widget _imgFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.white54,
          size: 36,
        ),
      ),
    );
  }
}
// ── Empty / Error ──────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle), child: const Icon(Icons.wifi_off_rounded, size: 36, color: AppTheme.primary)),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: AppTheme.textMid, fontSize: 13)),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle), child: Icon(icon, size: 36, color: AppTheme.primary)),
        const SizedBox(height: 14),
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: AppTheme.textLight, fontSize: 13)),
      ]),
    );
  }
}
