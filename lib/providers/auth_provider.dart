// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  AppUser? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;

  AuthProvider() {
    _checkAuthState();
  }

  // Listen to auth state changes from Firebase
  void _checkAuthState() {
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
      } else {
        // Fetch user data from Firestore
        final userData = await _authService.getCurrentUserData();
        _currentUser = userData;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  // Login method
  Future<AppUser?> login(
    String email,
    String password,
    String ipAddress,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithEmailPassword(
        email,
        password,
        ipAddress,
      );

      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return user;
      } else {
        _errorMessage = 'Login failed';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Logout method
  Future<void> logout(String ipAddress) async {
    if (_currentUser != null) {
      await _authService.signOut(
        _currentUser!.uid,
        _currentUser!.email,
        ipAddress,
      );
      _currentUser = null;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
