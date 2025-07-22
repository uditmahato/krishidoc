import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;

  User? get user => _user;

  Future<void> signIn(String email, String password) async {
    _user = await AuthService().signIn(email, password);
    notifyListeners();
  }

  Future<void> signOut() async {
    await AuthService().signOut();
    _user = null;
    notifyListeners();
  }

  bool get isLoggedIn => _user != null;
}
