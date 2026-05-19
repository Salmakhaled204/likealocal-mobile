import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/place.dart';
import '../models/user_role.dart';

enum FavoriteResult { saved, removed, limitReached, loginRequired, failed }

class FavoriteService {
  FavoriteService._();

  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<bool> isFavorite(String placeId) async {
    final currentUid = uid;
    if (currentUid == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('favorites')
        .doc(placeId)
        .get();
    return doc.exists;
  }

  static Future<FavoriteResult> togglePlace(
    Place place, {
    bool? currentlySaved,
  }) {
    return togglePlaceData(
      placeId: place.id,
      data: {...place.toFirestore(), 'placeId': place.id},
      currentlySaved: currentlySaved,
    );
  }

  static Future<FavoriteResult> togglePlaceData({
    required String placeId,
    required Map<String, dynamic> data,
    bool? currentlySaved,
  }) async {
    final currentUid = uid;
    if (currentUid == null) return FavoriteResult.loginRequired;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid);
    final favRef = userRef.collection('favorites').doc(placeId);

    try {
      final saved = currentlySaved ?? (await favRef.get()).exists;
      if (saved) {
        await favRef.delete();
        await userRef.set({
          'limits': {'pinsUsed': FieldValue.increment(-1)},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return FavoriteResult.removed;
      }

      final userDoc = await userRef.get();
      final role = UserRole.fromData(userDoc.data());
      final current = await userRef
          .collection('favorites')
          .limit(role.maxFavorites + 1)
          .get();
      if (current.docs.length >= role.maxPins) {
        return FavoriteResult.limitReached;
      }

      await favRef.set({
        ...data,
        'placeId': placeId,
        'savedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await userRef.set({
        'limits': {'pinsUsed': FieldValue.increment(1)},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return FavoriteResult.saved;
    } catch (_) {
      return FavoriteResult.failed;
    }
  }
}
