import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _markAllRead();
  }

  Future<void> _markAllRead() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'proximity':
        return Icons.location_on_rounded;
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'recommendation':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  // All notification types map to teal palette colours — no external accents needed
  Color _colorFor(String? type) {
    switch (type) {
      case 'proximity':
        return AppTheme.primary; // teal
      case 'chat':
        return AppTheme.softBlue; // periwinkle
      case 'recommendation':
        return AppTheme.accent; // bright teal
      default:
        return AppTheme.amber; // warm amber for general
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayDark,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Teal header ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
              decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notifications',
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text('Stay up to date',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white60)),
                        ]),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.notifications_rounded,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),

            // ── Notification list ──────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_uid)
                    .collection('notifications')
                    .orderBy('createdAt', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary));
                  }

                  final docs = snap.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  shape: BoxShape.circle),
                              child: const Icon(
                                  Icons.notifications_off_outlined,
                                  size: 40,
                                  color: AppTheme.primary),
                            ),
                            const SizedBox(height: 18),
                            Text('No notifications yet',
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark)),
                            const SizedBox(height: 6),
                            Text(
                                "We'll notify you when\nsomething happens",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppTheme.textLight)),
                          ]),
                    );
                  }

                  // Group: Today vs Earlier
                  final today = <DocumentSnapshot>[];
                  final earlier = <DocumentSnapshot>[];
                  for (final doc in docs) {
                    final d = doc.data() as Map<String, dynamic>;
                    final ts = d['createdAt'] as Timestamp?;
                    final isToday = ts != null &&
                        DateTime.now()
                                .difference(ts.toDate())
                                .inHours <
                            24;
                    (isToday ? today : earlier).add(doc);
                  }

                  return ListView(
                    padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    children: [
                      if (today.isNotEmpty) ...[
                        _SectionLabel('Today'),
                        ...today.map((doc) => _NotifCard(
                              doc: doc,
                              iconFor: _iconFor,
                              colorFor: _colorFor,
                              timeAgo: _timeAgo,
                            )),
                      ],
                      if (earlier.isNotEmpty) ...[
                        if (today.isNotEmpty)
                          const SizedBox(height: 6),
                        _SectionLabel('Earlier'),
                        ...earlier.map((doc) => _NotifCard(
                              doc: doc,
                              iconFor: _iconFor,
                              colorFor: _colorFor,
                              timeAgo: _timeAgo,
                            )),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Notification card ──────────────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final IconData Function(String?) iconFor;
  final Color Function(String?) colorFor;
  final String Function(Timestamp?) timeAgo;

  const _NotifCard({
    required this.doc,
    required this.iconFor,
    required this.colorFor,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final type = d['type'] as String?;
    final read = d['read'] == true;
    final color = colorFor(type);
    final title = (d['title'] as String?) ?? 'Notification';
    final body = (d['body'] as String?) ?? '';
    final ts = d['createdAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: read
              ? AppTheme.border
              : color.withValues(alpha: 0.35),
          width: read ? 1 : 1.5,
        ),
        boxShadow: read
            ? AppTheme.softShadow
            : [
                ...AppTheme.softShadow,
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(iconFor(type), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          // Text content
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight:
                          read ? FontWeight.w500 : FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textMid,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    timeAgo(ts),
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppTheme.textLight),
                  ),
                ]),
          ),
          // Unread dot
          if (!read) ...[
            const SizedBox(width: 10),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}