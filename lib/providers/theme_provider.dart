import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Theme provider for managing app theme state
/// Integrates with Supabase st_settings table to persist theme preferences
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = false;
  String? _error;

  ThemeMode get themeMode => _themeMode;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize theme from user settings in Supabase
  Future<void> initializeTheme() async {
    try {
      _setLoading(true);
      _clearError();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _themeMode = ThemeMode.system;
        notifyListeners();
        return;
      }

      // Fetch user settings from Supabase
      final response = await Supabase.instance.client
          .from('st_settings')
          .select('theme')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null && response['theme'] != null) {
        final themeString = response['theme'] as String;
        _themeMode = _stringToThemeMode(themeString);
      } else {
        // Create default settings if none exist
        await _createDefaultSettings(user.id);
        _themeMode = ThemeMode.light;
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load theme settings: $e');
      debugPrint('Error loading theme: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update theme and persist to Supabase
  Future<void> updateTheme(ThemeMode newTheme) async {
    try {
      _setLoading(true);
      _clearError();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Update theme in Supabase
      await Supabase.instance.client.from('st_settings').upsert({
        'user_id': user.id,
        'theme': _themeModeToString(newTheme),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      _themeMode = newTheme;
      notifyListeners();
    } catch (e) {
      _setError('Failed to update theme: $e');
      debugPrint('Error updating theme: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create default settings for new user
  Future<void> _createDefaultSettings(String userId) async {
    try {
      await Supabase.instance.client.from('st_settings').insert({
        'user_id': userId,
        'theme': 'light',
        'notification_threshold': 5,
      });
    } catch (e) {
      debugPrint('Error creating default settings: $e');
    }
  }

  /// Convert string to ThemeMode enum
  ThemeMode _stringToThemeMode(String theme) {
    switch (theme.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }

  /// Convert ThemeMode enum to string
  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
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
