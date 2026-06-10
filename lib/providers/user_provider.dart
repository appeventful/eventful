import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null && _user!.email.isNotEmpty;

  UserProvider() {
    FirebaseAuth.instance.authStateChanges().listen((User? firebaseUser) {
      if (firebaseUser == null) {
        _user = null;
        _isLoading = false;
        _userSubscription?.cancel();
        notifyListeners();
      } else {
        _listenToUserDoc(firebaseUser.uid);
      }
    });
  }

  void _listenToUserDoc(String uid) {
    _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _user = UserModel.fromFirestore(snapshot);
      } else {
        _user = null;
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint("UserProvider Error: $e");
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
