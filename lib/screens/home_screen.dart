import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/place.dart';
import '../providers/home_provider.dart';
import '../widgets/place_card.dart';
import '../widgets/shimmer_loading.dart';
import 'search_screen.dart';
import 'place_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Read the provider once and hold a local reference.
      // Do NOT use a computed getter — context.read traverses the tree every call.
      final homeProvider = context.read<HomeProvider>();

      // Run both independent queries concurrently to halve loading time
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await Future.wait([
        homeProvider.fetchPlaces(),
        if (uid != null) homeProvider.fetchPersonalizedRecommendationsForUser(uid),
      ]);
    });
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  /// Typed push to PlaceDetailsScreen.
  /// `place` is explicitly typed as [Place] — no dynamic parameters.
  void _navigateToDetails(BuildContext context, Place place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceDetailsScreen(place: place),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration:
                  BoxDecoration(color: Theme.of(context).primaryColor),
              child: Text(
                'LikeALocal',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
      body: Consumer<HomeProvider>(
        builder: (context, homeProvider, _) {
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context),

              // ── Error state ──────────────────────────────────────────────
              if (homeProvider.errorMessage != null && !homeProvider.isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            homeProvider.errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: homeProvider.fetchPlaces,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Recommendations section ──────────────────────────────────
              if (homeProvider.errorMessage == null)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: Text(
                          // Fix: use isPersonalized bool getter — not a
                          // list-identity != comparison (which is always true).
                          homeProvider.isPersonalized
                              ? 'Recommended for You ✨'
                              : 'Top Picks',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: homeProvider.isLoading &&
                                homeProvider.places.isEmpty
                            ? const ShimmerLoadingHorizontal()
                            : _buildRecommendations(context, homeProvider),
                      ),
                    ],
                  ),
                ),

              // ── Feed section header ──────────────────────────────────────
              if (homeProvider.errorMessage == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      'Explore Like A Local',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // ── Empty state ──────────────────────────────────────────────
              if (!homeProvider.isLoading &&
                  homeProvider.places.isEmpty &&
                  homeProvider.errorMessage == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.travel_explore,
                              size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No places found yet.\nBe the first to add one!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Shimmer (initial load) ───────────────────────────────────
              if (homeProvider.isLoading && homeProvider.places.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: ShimmerLoadingList(),
                  ),
                )

              // ── Main feed list ───────────────────────────────────────────
              else if (homeProvider.places.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final Place place = homeProvider.places[index];
                        return PlaceCard(
                          place: place,
                          onTap: () => _navigateToDetails(context, place),
                        );
                      },
                      childCount: homeProvider.places.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Text(
          'Discover',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1518684079-3c830dcef090'
              '?q=80&w=1000&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Recommendations carousel ─────────────────────────────────────────────

  Widget _buildRecommendations(BuildContext context, HomeProvider provider) {
    final recommendations = provider.recommendations;

    if (recommendations.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Text(
            'No recommendations available',
            style: GoogleFonts.inter(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          final Place place = recommendations[index];
          return GestureDetector(
            onTap: () => _navigateToDetails(context, place),
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(
                    place.imageUrls.isNotEmpty
                        ? place.imageUrls.first
                        : 'https://via.placeholder.com/150',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          place.averageRating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
