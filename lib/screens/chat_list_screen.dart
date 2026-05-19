import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';

/// Shows all conversations the current user is part of.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text(
            'Messages',
            style: GoogleFonts.inter(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(child: Text('Please sign in to view messages.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Messages',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load messages.',
                style: GoogleFonts.inter(color: Colors.red),
              ),
            );
          }

          final docs = List<QueryDocumentSnapshot>.from(
            snapshot.data?.docs ?? [],
          )..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['lastMessageTime'] as Timestamp?;
              final bTime = bData['lastMessageTime'] as Timestamp?;
              return (bTime?.toDate().millisecondsSinceEpoch ?? 0).compareTo(
                aTime?.toDate().millisecondsSinceEpoch ?? 0,
              );
            });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 72,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No conversations yet',
                    style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a chat from a place\'s details screen',
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final chatId = docs[index].id;

              // Find the other participant's info
              final participants = List<String>.from(
                data['participants'] ?? [],
              );
              final otherId = participants.firstWhere(
                (id) => id != uid,
                orElse: () => '',
              );
              final otherName = _getOtherName(data, otherId);
              final lastMessage = data['lastMessage'] as String? ?? '';
              final lastTime = data['lastMessageTime'] as Timestamp?;
              final unreadCount = (data['unreadCount_$uid'] ?? 0) as int;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        otherName,
                        style: GoogleFonts.inter(
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatTime(lastTime),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: unreadCount > 0
                            ? Colors.blue[600]
                            : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lastMessage,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: unreadCount > 0
                              ? Colors.black87
                              : Colors.grey[500],
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chatId,
                        otherUserId: otherId,
                        otherUserName: otherName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Returns the display name of the other participant stored in the chat doc.
  String _getOtherName(Map<String, dynamic> data, String otherId) {
    final names = data['participantNames'] as Map<String, dynamic>?;
    return names?[otherId] as String? ?? 'Unknown User';
  }
}
