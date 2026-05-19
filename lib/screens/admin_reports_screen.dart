import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  Future<void> _markResolved(DocumentReference ref) {
    return ref.set({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteReportedTarget(BuildContext context, DocumentSnapshot report) async {
    final data = report.data() as Map<String, dynamic>;
    final targetRef = report.reference.parent.parent;
    if (targetRef == null) return;
    final type = (data['type'] ?? 'content').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete reported $type?'),
        content: const Text('This moderation action removes the reported item for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await targetRef.delete();
    await _markResolved(report.reference);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Moderation',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('reports')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No reports yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['status'] ?? 'open').toString();
              final type = (data['type'] ?? 'place').toString();
              final title = data['placeTitle']?.toString() ?? 'Reported content';
              final details = data['details']?.toString() ?? '';
              final reportedText = data['reportedText']?.toString() ?? '';
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Chip(label: Text(type)),
                        const SizedBox(width: 6),
                        Chip(label: Text(status)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Reason: ${data['reason']?.toString() ?? 'No reason provided.'}'),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Details: $details'),
                    ],
                    if (reportedText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reported text: $reportedText',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Reporter: ${data['reporterEmail']?.toString().isNotEmpty == true ? data['reporterEmail'] : data['reporterId'] ?? 'Unknown'}',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textLight),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: status == 'resolved'
                                ? null
                                : () => _markResolved(doc.reference),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Resolve'),
                          ),
                          TextButton.icon(
                            onPressed: status == 'resolved'
                                ? null
                                : () => _deleteReportedTarget(context, doc),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Delete content'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
