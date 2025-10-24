import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_settings.dart';

/// Service class for handling all Supabase operations in StockDrop app
/// Provides centralized access to authentication, favorites, and settings management
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  /// Get the Supabase client instance
  SupabaseClient get client => Supabase.instance.client;

  /// Get the current authenticated user
  User? get currentUser => client.auth.currentUser;

  /// Check if user is currently authenticated
  bool get isAuthenticated => currentUser != null;

  /// Get current user ID, throws if not authenticated
  String get currentUserId {
    final user = currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.id;
  }

  // ==================== FAVORITES MANAGEMENT ====================

  /// Add a stock to user's favorites
  ///
  /// [symbol] - The stock symbol to add (e.g., 'AAPL')
  /// Returns true if successful, throws exception on error
  Future<bool> addToFavorites(String symbol) async {
    try {
      if (!isAuthenticated) {
        throw Exception('User must be authenticated to add favorites');
      }

      await client.from('st_favorites').insert({
        'user_id': currentUserId,
        'symbol': symbol.toUpperCase(),
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Successfully added $symbol to favorites');
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique constraint violation - stock already in favorites
        throw Exception('$symbol is already in your favorites');
      }
      debugPrint('PostgrestException adding favorite: ${e.message}');
      throw Exception('Failed to add to favorites: ${e.message}');
    } catch (e) {
      debugPrint('Error adding favorite: $e');
      throw Exception('Failed to add to favorites: $e');
    }
  }

  /// Remove a stock from user's favorites
  ///
  /// [symbol] - The stock symbol to remove (e.g., 'AAPL')
  /// Returns true if successful, throws exception on error
  Future<bool> removeFromFavorites(String symbol) async {
    try {
      if (!isAuthenticated) {
        throw Exception('User must be authenticated to remove favorites');
      }

      await client
          .from('st_favorites')
          .delete()
          .eq('user_id', currentUserId)
          .eq('symbol', symbol.toUpperCase());

      debugPrint('Successfully removed $symbol from favorites');
      return true;
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException removing favorite: ${e.message}');
      throw Exception('Failed to remove from favorites: ${e.message}');
    } catch (e) {
      debugPrint('Error removing favorite: $e');
      throw Exception('Failed to remove from favorites: $e');
    }
  }

  /// Check if a stock is in user's favorites
  ///
  /// [symbol] - The stock symbol to check (e.g., 'AAPL')
  /// Returns true if in favorites, false otherwise
  Future<bool> isFavorite(String symbol) async {
    try {
      if (!isAuthenticated) return false;

      final response = await client
          .from('st_favorites')
          .select('symbol')
          .eq('user_id', currentUserId)
          .eq('symbol', symbol.toUpperCase())
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
      return false;
    }
  }

  /// Get all favorite stocks for the current user
  ///
  /// Returns a list of stock symbols
  Future<List<String>> getFavorites() async {
    try {
      if (!isAuthenticated) {
        throw Exception('User must be authenticated to get favorites');
      }

      final response = await client
          .from('st_favorites')
          .select('symbol')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      return response.map<String>((item) => item['symbol'] as String).toList();
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException getting favorites: ${e.message}');
      throw Exception('Failed to load favorites: ${e.message}');
    } catch (e) {
      debugPrint('Error getting favorites: $e');
      throw Exception('Failed to load favorites: $e');
    }
  }

  /// Get a real-time stream of user's favorite stocks
  ///
  /// Returns a stream that emits the complete list of favorites when changes occur
  Stream<List<String>> getFavoritesStream() {
    if (!isAuthenticated) {
      return Stream.value([]);
    }

    return client
        .from('st_favorites')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false)
        .map((data) {
          return data.map<String>((item) => item['symbol'] as String).toList();
        })
        .handleError((error) {
          debugPrint('Error in favorites stream: $error');
          return <String>[];
        });
  }

  /// Toggle a stock's favorite status
  ///
  /// [symbol] - The stock symbol to toggle
  /// Returns the new favorite status (true if added, false if removed)
  Future<bool> toggleFavorite(String symbol) async {
    try {
      final isFav = await isFavorite(symbol);

      if (isFav) {
        await removeFromFavorites(symbol);
        return false;
      } else {
        await addToFavorites(symbol);
        return true;
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      rethrow;
    }
  }

  // ==================== SETTINGS MANAGEMENT ====================

  /// Get user settings from Supabase
  ///
  /// Returns UserSettings object with current settings, or default values if none exist
  Future<UserSettings> getSettings() async {
    try {
      if (!isAuthenticated) {
        throw Exception('User must be authenticated to get settings');
      }

      final response = await client
          .from('st_settings')
          .select('notification_threshold, theme, updated_at')
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (response != null) {
        return UserSettings.fromJson(response);
      } else {
        // Return default settings if none exist
        final defaultSettings = UserSettings(
          notificationThreshold: 5,
          theme: 'system',
        );

        // Create default settings in database
        await saveSettings(defaultSettings);
        return defaultSettings;
      }
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException getting settings: ${e.message}');
      throw Exception('Failed to load settings: ${e.message}');
    } catch (e) {
      debugPrint('Error getting settings: $e');
      throw Exception('Failed to load settings: $e');
    }
  }

  /// Save user settings to Supabase
  ///
  /// [settings] - The UserSettings object to save
  /// Returns true if successful, throws exception on error
  Future<bool> saveSettings(UserSettings settings) async {
    try {
      if (!isAuthenticated) {
        throw Exception('User must be authenticated to save settings');
      }

      final data = settings.toJson();
      data['user_id'] = currentUserId;

      await client.from('st_settings').upsert(data, onConflict: 'user_id');

      debugPrint('Successfully saved settings: $settings');
      return true;
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException saving settings: ${e.message}');
      throw Exception('Failed to save settings: ${e.message}');
    } catch (e) {
      debugPrint('Error saving settings: $e');
      throw Exception('Failed to save settings: $e');
    }
  }

  /// Update notification threshold only
  ///
  /// [threshold] - The new notification threshold (3, 5, or 10)
  Future<bool> updateNotificationThreshold(int threshold) async {
    try {
      final currentSettings = await getSettings();
      final updatedSettings = UserSettings(
        notificationThreshold: threshold,
        theme: currentSettings.theme,
      );

      return await saveSettings(updatedSettings);
    } catch (e) {
      debugPrint('Error updating notification threshold: $e');
      rethrow;
    }
  }

  /// Update theme only
  ///
  /// [theme] - The new theme ('light', 'dark', or 'system')
  Future<bool> updateTheme(String theme) async {
    try {
      final currentSettings = await getSettings();
      final updatedSettings = UserSettings(
        notificationThreshold: currentSettings.notificationThreshold,
        theme: theme,
      );

      return await saveSettings(updatedSettings);
    } catch (e) {
      debugPrint('Error updating theme: $e');
      rethrow;
    }
  }

  /// Get a real-time stream of user settings
  ///
  /// Returns a stream that emits UserSettings when changes occur
  Stream<UserSettings> getSettingsStream() {
    if (!isAuthenticated) {
      return Stream.value(
        UserSettings(notificationThreshold: 5, theme: 'system'),
      );
    }

    return client
        .from('st_settings')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', currentUserId)
        .map((data) {
          if (data.isNotEmpty) {
            return UserSettings.fromJson(data.first);
          } else {
            return UserSettings(notificationThreshold: 5, theme: 'system');
          }
        })
        .handleError((error) {
          debugPrint('Error in settings stream: $error');
          return UserSettings(notificationThreshold: 5, theme: 'system');
        });
  }

  // ==================== AUTHENTICATION HELPERS ====================

  /// Sign out the current user
  ///
  /// Returns true if successful, throws exception on error
  Future<bool> signOut() async {
    try {
      await client.auth.signOut();
      debugPrint('User signed out successfully');
      return true;
    } catch (e) {
      debugPrint('Error signing out: $e');
      throw Exception('Failed to sign out: $e');
    }
  }

  /// Get current user email
  ///
  /// Returns email string or null if not authenticated
  String? get userEmail => currentUser?.email;

  /// Listen to auth state changes
  ///
  /// Returns a stream of AuthState changes
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ==================== UTILITY METHODS ====================

  /// Clear all cached data (useful for logout)
  ///
  /// Note: This doesn't clear Supabase data, only local references
  void clearCache() {
    // This method can be extended to clear any local caches
    debugPrint('Supabase service cache cleared');
  }

  /// Check database connection
  ///
  /// Returns true if connected, false otherwise
  Future<bool> checkConnection() async {
    try {
      await client.from('st_favorites').select('count').limit(1);
      return true;
    } catch (e) {
      debugPrint('Database connection check failed: $e');
      return false;
    }
  }

  /// Dispose resources (call when app is disposed)
  void dispose() {
    debugPrint('SupabaseService disposed');
  }
}
