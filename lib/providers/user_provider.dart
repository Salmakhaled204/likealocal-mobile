import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSaving = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _auth.currentUser;

  DocumentReference<Map<String, dynamic>>? get userDoc {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentUserProfile() {
    final doc = userDoc;
    if (doc == null) {
      return const Stream.empty();
    }
    return doc.snapshots();
  }

  Future<void> ensureUserDocument(User user) async {
    final doc = _firestore.collection('users').doc(user.uid);
    try {
      final snapshot = await doc.get();
      if (snapshot.exists) return;

      await doc.set({
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'bio': '',
        'phone': '',
        'chatEnabled': true,
        'publicProfile': true,
        'preferredCategories': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      _errorMessage = e.message ?? 'Could not load your profile.';
      if (kDebugMode) {
        print('User document setup error: $e');
      }
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String bio,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _setError('You must be logged in to update your profile.');
      return;
    }

    _startSaving();
    try {
      await user.updateDisplayName(displayName.trim());
      await _firestore.collection('users').doc(user.uid).set(
        {
          'email': user.email ?? '',
          'displayName': displayName.trim(),
          'bio': bio.trim(),
          'phone': phone.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _errorMessage = null;
    } on FirebaseException catch (e) {
      _setError(_firestoreErrorMessage(e, 'Could not update profile.'));
    } catch (e) {
      _setError('Could not update profile.');
      if (kDebugMode) {
        print('Profile update error: $e');
      }
    } finally {
      _stopSaving();
    }
  }

  Future<void> updatePrivacySettings({
    required bool chatEnabled,
    required bool publicProfile,
    required List<String> preferredCategories,
  }) async {
    final doc = userDoc;
    if (doc == null) {
      _setError('You must be logged in to update settings.');
      return;
    }

    _startSaving();
    try {
      await doc.set(
        {
          'chatEnabled': chatEnabled,
          'publicProfile': publicProfile,
          'preferredCategories': List<String>.from(preferredCategories),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _errorMessage = null;
    } on FirebaseException catch (e) {
      _setError(_firestoreErrorMessage(e, 'Could not update settings.'));
    } catch (e) {
      _setError('Could not update settings.');
      if (kDebugMode) {
        print('Settings update error: $e');
      }
    } finally {
      _stopSaving();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
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

  String _firestoreErrorMessage(FirebaseException e, String fallback) {
    if (e.code == 'permission-denied') {
      return 'Firestore rules are blocking this action. Deploy the project rules or allow users to edit their own profile.';
    }
    return e.message ?? fallback;
  }
}
