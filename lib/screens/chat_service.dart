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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log in to send messages.')),
      );
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

      // Check if a chat between these two users already exists.
      // Chat IDs are deterministic: sorted UIDs joined by '_'
      final ids = [currentUser.uid, otherUserId]..sort();
      final chatId = '${ids[0]}_${ids[1]}';
      final chatRef = firestore.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();

      // Resolve the other user's display name if not provided
      String resolvedName = otherUserName ?? 'User';
      if (otherUserName == null) {
        final userDoc = await firestore.collection('users').doc(otherUserId).get();
        resolvedName = userDoc.data()?['displayName'] ?? 'User';
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
          const SnackBar(content: Text('Could not open chat. Please try again.')),
        );
      }
    }
  }
}