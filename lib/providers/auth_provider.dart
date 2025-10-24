import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication provider for managing user authentication state
/// Handles login, logout, and session management with Supabase
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  Session? _session;

  User? get user => _user;
  Session? get session => _session;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null && _session != null;

  AuthProvider() {
    _initializeAuth();
  }

  /// Initialize authentication state and listen for auth changes
  void _initializeAuth() {
    // Get current session
    _session = Supabase.instance.client.auth.currentSession;
    _user = _session?.user;

    // Listen for auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      _user = data.session?.user;
      notifyListeners();
    });
  }

  /// Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _user = response.user;
        _session = response.session;
        notifyListeners();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmailAndPassword(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _user = response.user;
        _session = response.session;
        notifyListeners();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _clearError();

      await Supabase.instance.client.auth.signOut();

      _user = null;
      _session = null;
      notifyListeners();
    } catch (e) {
      _setError('Failed to sign out: $e');
      debugPrint('Error signing out: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _clearError();

      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if current session is valid
  bool isSessionValid() {
    if (_session == null) return false;

    final expiresAt = _session!.expiresAt;
    if (expiresAt == null) return false;

    return DateTime.now().millisecondsSinceEpoch < expiresAt * 1000;
  }

  /// Refresh current session
  Future<void> refreshSession() async {
    try {
      final response = await Supabase.instance.client.auth.refreshSession();
      _session = response.session;
      _user = response.user;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing session: $e');
      // If refresh fails, sign out the user
      await signOut();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
