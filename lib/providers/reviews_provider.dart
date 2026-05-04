import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/review.dart';

class ReviewsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isSaving = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Stream<List<Review>> watchReviews(String placeId) {
    return _reviewsRef(placeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    });
  }

  Future<void> addReview({
    required String placeId,
    required int rating,
    required String comment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _setError('You must be logged in to review places.');
      return;
    }

    await _saveReview(
      placeId: placeId,
      reviewId: user.uid,
      data: {
        'userId': user.uid,
        'userEmail': user.email ?? 'Anonymous',
        'rating': rating,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
      },
      merge: false,
    );
  }

  Future<void> editReview({
    required String placeId,
    required String reviewId,
    required int rating,
    required String comment,
  }) async {
    await _saveReview(
      placeId: placeId,
      reviewId: reviewId,
      data: {
        'rating': rating,
        'comment': comment.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  Future<void> deleteReview({
    required String placeId,
    required String reviewId,
  }) async {
    _startSaving();

    try {
      await _reviewsRef(placeId).doc(reviewId).delete();
      await _updatePlaceRating(placeId);
      _errorMessage = null;
    } catch (e) {
      _setError('Could not delete your review.');
      if (kDebugMode) {
        print('Error deleting review: $e');
      }
    } finally {
      _stopSaving();
    }
  }

  Future<void> _saveReview({
    required String placeId,
    required String reviewId,
    required Map<String, dynamic> data,
    required bool merge,
  }) async {
    _startSaving();

    try {
      await _reviewsRef(placeId)
          .doc(reviewId)
          .set(data, SetOptions(merge: merge));
      await _updatePlaceRating(placeId);
      _errorMessage = null;
    } catch (e) {
      _setError('Could not save your review.');
      if (kDebugMode) {
        print('Error saving review: $e');
      }
    } finally {
      _stopSaving();
    }
  }

  Future<void> _updatePlaceRating(String placeId) async {
    final reviewsSnapshot = await _reviewsRef(placeId).get();
    final ratings = reviewsSnapshot.docs
        .map((doc) => (doc.data()['rating'] ?? 0).toDouble())
        .where((rating) => rating > 0)
        .toList();

    final average = ratings.isEmpty
        ? 0.0
        : ratings.reduce((total, rating) => total + rating) / ratings.length;

    await _firestore.collection('places').doc(placeId).update({
      'averageRating': average,
      'reviewCount': ratings.length,
    });
  }

  CollectionReference<Map<String, dynamic>> _reviewsRef(String placeId) {
    return _firestore.collection('places').doc(placeId).collection('reviews');
  }

  void _startSaving() {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _stopSaving() {
    _isSaving = false;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }
}
