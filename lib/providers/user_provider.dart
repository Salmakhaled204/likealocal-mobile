import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  UserRole _role = UserRole.regularFree();
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get profile => _profile;
  UserRole get role => _role;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _profile = null;
      _role = UserRole.regularFree();
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _profile = doc.data();
      _role = UserRole.fromData(_profile);
    } catch (e) {
      _error = 'Could not load user profile.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void updateLocalProfile(Map<String, dynamic> data) {
    _profile = {...?_profile, ...data};
    _role = UserRole.fromData(_profile);
    notifyListeners();
  }
}
