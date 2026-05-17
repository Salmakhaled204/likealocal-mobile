import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

/// Creates a chat between the current user and [otherUserId] if one doesn't
/// exist, then navigates to [ChatScreen].
///
/// Call this from any screen — e.g. a "Message Owner" button on PlaceDetailsScreen.
///
/// Usage:
/// ```dart
/// ElevatedButton(
///   onPressed: () => ChatService.startChat(context, place.ownerId),
///   child: Text('Message Owner'),
/// )
/// ```
class ChatService {
  ChatService._();

  static Future<void> startChat(
    BuildContext context,
    String otherUserId, {
    String? otherUserName,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Log in to send messages.')));
      return;
    }

    if (currentUser.uid == otherUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't message yourself.")),
      );
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final otherUserDoc = await firestore
          .collection('users')
          .doc(otherUserId)
          .get();
      final otherUserData = otherUserDoc.data() ?? {};
      if (otherUserData['chatEnabled'] == false) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This user is not accepting chats.')),
        );
        return;
      }
      final schedule = otherUserData['chatSchedule'];
      if (schedule is Map<String, dynamic> && schedule['enabled'] == true) {
        final start = (schedule['startTime'] ?? '00:00').toString();
        final end = (schedule['endTime'] ?? '23:59').toString();
        if (!_isWithinSchedule(DateTime.now(), start, end)) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This user is available from $start to $end.'),
            ),
          );
          return;
        }
      }

      // Check if a chat between these two users already exists.
      // Chat IDs are deterministic: sorted UIDs joined by '_'
      final ids = [currentUser.uid, otherUserId]..sort();
      final chatId = '${ids[0]}_${ids[1]}';
      final chatRef = firestore.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();

      // Resolve the other user's display name if not provided
      String resolvedName = otherUserName ?? 'User';
      if (otherUserName == null) {
        resolvedName = otherUserData['displayName'] ?? 'User';
      }

      if (!chatDoc.exists) {
        // Create the chat document for the first time
        await chatRef.set({
          'participants': [currentUser.uid, otherUserId],
          'participantNames': {
            currentUser.uid: currentUser.displayName ?? 'Me',
            otherUserId: resolvedName,
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount_${currentUser.uid}': 0,
          'unreadCount_$otherUserId': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: otherUserId,
            otherUserName: resolvedName,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open chat. Please try again.'),
          ),
        );
      }
    }
  }

  static bool _isWithinSchedule(DateTime now, String start, String end) {
    int parseMinutes(String value) {
      final parts = value.split(':');
      if (parts.length != 2) return 0;
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return hour * 60 + minute;
    }

    final current = now.hour * 60 + now.minute;
    final startMinutes = parseMinutes(start);
    final endMinutes = parseMinutes(end);
    if (startMinutes <= endMinutes) {
      return current >= startMinutes && current <= endMinutes;
    }
    return current >= startMinutes || current <= endMinutes;
  }
}
