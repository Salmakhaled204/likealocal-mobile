import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_role.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isSaving = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _startDemoPremium() async {
    final uid = _uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Demo checkout'),
        content: const Text(
          'This is a university demo checkout. No real payment will be made.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start Demo Premium'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final now = Timestamp.now();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      );
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'isPremium': true,
        'subscription': {
          'plan': AppSubscriptionPlan.premium,
          'source': AppSubscriptionSource.demo,
          'startedAt': now,
          'expiresAt': expiresAt,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Premium unlocked! This is a demo subscription for the university project. No real payment was made.',
          ),
        ),
      );
      setState(() {});
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _cancelDemoPremium() async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'isPremium': false,
        'subscription': {
          'plan': AppSubscriptionPlan.free,
          'source': null,
          'startedAt': null,
          'expiresAt': null,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo Premium cancelled. Back to Free.')),
      );
      setState(() {});
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Go Premium')),
      body: uid == null
          ? const Center(child: Text('Sign in to manage Premium.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final role = UserRole.fromData(snapshot.data?.data());
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Unlock the full LikeALocal experience with Premium.',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Monthly: 99 EGP/month   |   Yearly: 899 EGP/year',
                      style: GoogleFonts.inter(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 18),
                    _PlanCard(
                      title: 'Free Plan',
                      rows: const [
                        'Limited favorites and AI',
                        'Role-based place posting limits',
                        'Basic discovery and reviews',
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PlanCard(
                      title: 'Premium Plan',
                      highlighted: true,
                      rows: const [
                        '999 favorites and monthly places',
                        'Advanced filters and premium recommendations',
                        'Exclusive hidden gems and custom trip plans',
                        '100 demo AI requests per day',
                      ],
                    ),
                    const SizedBox(height: 18),
                    _ComparisonTable(role: role),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed:
                          _isSaving || role.isPremium ? null : _startDemoPremium,
                      child: Text(
                        role.isPremium ? 'Premium Active' : 'Start Demo Premium',
                      ),
                    ),
                    if (role.isPremium)
                      TextButton(
                        onPressed: _isSaving ? null : _cancelDemoPremium,
                        child: const Text('Cancel Demo Premium'),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      'This is a university demo checkout. No real payment will be made.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final List<String> rows;
  final bool highlighted;

  const _PlanCard({
    required this.title,
    required this.rows,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final MaterialColor color = highlighted ? Colors.teal : Colors.grey;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? Colors.teal.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: highlighted ? Colors.teal[800] : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, size: 16, color: color[700]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(row)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final UserRole role;

  const _ComparisonTable({required this.role});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Favorites', '${role.maxFavorites}', '999'),
      ('Places / month', '${role.maxPlacesPerMonth}', '999'),
      ('Reviews / day', '${role.maxReviewsPerDay}', '50'),
      ('AI / day', '${role.maxAiRequestsPerDay}', '100'),
      ('Advanced filters', role.advancedFilters ? 'Yes' : 'No', 'Yes'),
      ('Premium recs', role.premiumRecommendations ? 'Yes' : 'No', 'Yes'),
    ];

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
      },
      children: [
        _row('Feature', 'Current', 'Premium', header: true),
        for (final row in rows) _row(row.$1, row.$2, row.$3),
      ],
    );
  }

  TableRow _row(String a, String b, String c, {bool header = false}) {
    TextStyle style = TextStyle(
      fontWeight: header ? FontWeight.bold : FontWeight.normal,
      fontSize: 12,
    );
    return TableRow(
      decoration: BoxDecoration(color: header ? Colors.grey.shade100 : null),
      children: [
        _cell(a, style),
        _cell(b, style),
        _cell(c, style),
      ],
    );
  }

  Widget _cell(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: style),
    );
  }
}
