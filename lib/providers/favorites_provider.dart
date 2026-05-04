import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/place.dart';

class FavoritesProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isSaving = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Stream<bool> watchIsFavorite(String placeId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _favoritesRef(user.uid).doc(placeId).snapshots().map((doc) {
      return doc.exists;
    });
  }

  Stream<List<Place>> watchFavorites() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _favoritesRef(user.uid)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Place.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> toggleFavorite(Place place, bool isFavorite) async {
    final user = _auth.currentUser;
    if (user == null) {
      _setError('You must be logged in to save places.');
      return;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docRef = _favoritesRef(user.uid).doc(place.id);
      if (isFavorite) {
        await docRef.delete();
      } else {
        await docRef.set({
          ...place.toFirestore(),
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _setError('Could not update favorites.');
      if (kDebugMode) {
        print('Error updating favorite: $e');
      }
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  CollectionReference<Map<String, dynamic>> _favoritesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('favorites');
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }
}
