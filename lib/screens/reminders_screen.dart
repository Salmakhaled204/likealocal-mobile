import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_role.dart';
import '../theme/app_theme.dart';

/// Stores a reminder tied to a place.
/// Saved under users/{uid}/reminders/{placeId}.
class PlaceReminder {
  final String placeId;
  final String placeTitle;
  final String note;
  final double radiusMeters;
  final DateTime createdAt;

  PlaceReminder({
    required this.placeId,
    required this.placeTitle,
    required this.note,
    required this.radiusMeters,
    required this.createdAt,
  });

  factory PlaceReminder.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PlaceReminder(
      placeId: d['placeId'] ?? doc.id,
      placeTitle:
          d['title'] ?? d['placeTitle'] ?? '', // place_details writes 'title'
      note: d['note'] ?? '',
      radiusMeters: (d['radiusMeters'] as num?)?.toDouble() ?? 300.0,
      createdAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'placeId': placeId,
    'placeTitle': placeTitle,
    'note': note,
    'radiusMeters': radiusMeters,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

/// Screen that lists all reminders the user has set on places.
/// Users can add reminders from PlaceDetailsScreen; here they view/delete them.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _deleteReminder(
    BuildContext context,
    String placeId,
    UserRole role,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    // Collection name matches place_details_screen.dart: 'locationReminders'
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('locationReminders')
        .doc(placeId)
        .delete();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reminder removed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        title: Text(
          'My Reminders',
          style: GoogleFonts.poppins(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Please log in.'))
          : FutureBuilder<UserRole>(
              future: fetchUserRole(uid),
              builder: (context, roleSnap) {
                final role = roleSnap.data ?? UserRole.regularFree();
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('locationReminders')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _EmptyState();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Usage bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryDim),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.alarm_on_outlined,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${docs.length} / ${role.maxReminders} reminders used',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (!role.isPremium) ...[
                                  const Spacer(),
                                  Text(
                                    'Upgrade for more',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppTheme.textLight,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final reminder = PlaceReminder.fromFirestore(
                                docs[i],
                              );
                              return _ReminderCard(
                                reminder: reminder,
                                onDelete: () => _deleteReminder(
                                  context,
                                  reminder.placeId,
                                  role,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final PlaceReminder reminder;
  final VoidCallback onDelete;

  const _ReminderCard({required this.reminder, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.alarm_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.placeTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                if (reminder.note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    reminder.note,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMid,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.radar_rounded,
                      size: 13,
                      color: AppTheme.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Notify within ${reminder.radiusMeters.toInt()} m',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.peach,
              size: 20,
            ),
            tooltip: 'Remove reminder',
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.alarm_add_outlined,
                color: AppTheme.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No reminders yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open a place and tap "Set Reminder"\nto be notified when you are nearby.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textLight,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper called from PlaceDetailsScreen to add a reminder for a place.
Future<void> addReminder({
  required BuildContext context,
  required String placeId,
  required String placeTitle,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Please log in first.')));
    return;
  }

  // Check role limits
  final role = await fetchUserRole(uid);
  final remindersRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('reminders');
  final existing = await remindersRef.limit(role.maxReminders + 1).get();

  if (existing.docs.length >= role.maxReminders) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder limit reached (${role.maxReminders}). '
            '${role.isPremium ? '' : 'Upgrade to Premium for more.'}',
          ),
        ),
      );
    }
    return;
  }

  // Check if already exists
  final existing2 = await remindersRef.doc(placeId).get();
  if (existing2.exists) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder already set for this place.')),
      );
    }
    return;
  }

  // Show dialog to pick radius and note
  if (!context.mounted) return;
  double radius = 300;
  final noteCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(
          'Set Reminder',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              placeTitle,
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textMid),
            ),
            const SizedBox(height: 16),
            Text(
              'Notify me within  ${radius.toInt()} m',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            Slider(
              value: radius,
              min: 100,
              max: 1000,
              divisions: 9,
              activeColor: AppTheme.primary,
              label: '${radius.toInt()} m',
              onChanged: (v) => setDialogState(() => radius = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                hintText: 'Optional note (e.g. "Try the kofta")',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Set Reminder'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true) return;

  final reminder = PlaceReminder(
    placeId: placeId,
    placeTitle: placeTitle,
    note: noteCtrl.text.trim(),
    radiusMeters: radius,
    createdAt: DateTime.now(),
  );

  await remindersRef.doc(placeId).set(reminder.toFirestore());

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder set for "$placeTitle". We\'ll notify you nearby!',
        ),
      ),
    );
  }
}
