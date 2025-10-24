import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/user_settings.dart';

/// Example usage of SupabaseService in StockDrop app
/// This file demonstrates how to integrate the service in your screens
class ExampleSupabaseUsage extends StatefulWidget {
  const ExampleSupabaseUsage({super.key});

  @override
  State<ExampleSupabaseUsage> createState() => _ExampleSupabaseUsageState();
}

class _ExampleSupabaseUsageState extends State<ExampleSupabaseUsage> {
  final SupabaseService _supabaseService = SupabaseService();
  List<String> _favorites = [];
  UserSettings? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupStreams();
  }

  /// Load initial data
  Future<void> _loadData() async {
    try {
      // Check authentication
      if (!_supabaseService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      // Load favorites and settings
      final favorites = await _supabaseService.getFavorites();
      final settings = await _supabaseService.getSettings();

      setState(() {
        _favorites = favorites;
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load data: $e');
    }
  }

  /// Setup real-time streams
  void _setupStreams() {
    // Listen to favorites changes
    _supabaseService.getFavoritesStream().listen(
      (favorites) {
        if (mounted) {
          setState(() {
            _favorites = favorites;
          });
        }
      },
      onError: (error) {
        _showError('Favorites stream error: $error');
      },
    );

    // Listen to settings changes
    _supabaseService.getSettingsStream().listen(
      (settings) {
        if (mounted) {
          setState(() {
            _settings = settings;
          });
        }
      },
      onError: (error) {
        _showError('Settings stream error: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Service Example'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info
          _buildUserInfo(),
          const SizedBox(height: 20),

          // Settings
          _buildSettings(),
          const SizedBox(height: 20),

          // Favorites
          _buildFavorites(),
          const SizedBox(height: 20),

          // Actions
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Email: ${_supabaseService.userEmail ?? 'Unknown'}'),
            Text('Authenticated: ${_supabaseService.isAuthenticated}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_settings != null) ...[
              Text(
                'Notification Threshold: ${_settings!.notificationThreshold}%',
              ),
              Text('Theme: ${_settings!.theme}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _updateTheme('light'),
                    child: const Text('Light'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _updateTheme('dark'),
                    child: const Text('Dark'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _updateTheme('system'),
                    child: const Text('System'),
                  ),
                ],
              ),
            ] else
              const Text('No settings loaded'),
          ],
        ),
      ),
    );
  }

  Widget _buildFavorites() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Favorites (${_favorites.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_favorites.isEmpty)
              const Text('No favorites yet')
            else
              Wrap(
                spacing: 8,
                children: _favorites.map((symbol) {
                  return Chip(
                    label: Text(symbol),
                    onDeleted: () => _removeFavorite(symbol),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _addSampleFavorite,
                  child: const Text('Add AAPL'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addSampleFavorite2,
                  child: const Text('Add TSLA'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _updateNotificationThreshold,
                  child: const Text('Set 10%'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _checkConnection,
                  child: const Text('Test Connection'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _updateTheme(String theme) async {
    try {
      await _supabaseService.updateTheme(theme);
      _showSuccess('Theme updated to $theme');
    } catch (e) {
      _showError('Failed to update theme: $e');
    }
  }

  Future<void> _updateNotificationThreshold() async {
    try {
      await _supabaseService.updateNotificationThreshold(10);
      _showSuccess('Notification threshold updated to 10%');
    } catch (e) {
      _showError('Failed to update threshold: $e');
    }
  }

  Future<void> _addSampleFavorite() async {
    try {
      await _supabaseService.addToFavorites('AAPL');
      _showSuccess('Added AAPL to favorites');
    } catch (e) {
      _showError('Failed to add AAPL: $e');
    }
  }

  Future<void> _addSampleFavorite2() async {
    try {
      await _supabaseService.addToFavorites('TSLA');
      _showSuccess('Added TSLA to favorites');
    } catch (e) {
      _showError('Failed to add TSLA: $e');
    }
  }

  Future<void> _removeFavorite(String symbol) async {
    try {
      await _supabaseService.removeFromFavorites(symbol);
      _showSuccess('Removed $symbol from favorites');
    } catch (e) {
      _showError('Failed to remove $symbol: $e');
    }
  }

  Future<void> _checkConnection() async {
    try {
      final isConnected = await _supabaseService.checkConnection();
      _showSuccess(
        'Connection status: ${isConnected ? 'Connected' : 'Disconnected'}',
      );
    } catch (e) {
      _showError('Connection check failed: $e');
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _supabaseService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      _showError('Failed to logout: $e');
    }
  }

  // ==================== HELPERS ====================

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// How to integrate SupabaseService in existing screens:
/// 
/// 1. IMPORT THE SERVICE:
/// ```dart
/// import '../services/supabase_service.dart';
/// ```
/// 
/// 2. CREATE SERVICE INSTANCE:
/// ```dart
/// final SupabaseService _supabaseService = SupabaseService();
/// ```
/// 
/// 3. REPLACE DIRECT SUPABASE CALLS:
/// 
/// OLD WAY:
/// ```dart
/// await Supabase.instance.client
///     .from('st_favorites')
///     .insert({'user_id': userId, 'symbol': symbol});
/// ```
/// 
/// NEW WAY:
/// ```dart
/// await _supabaseService.addToFavorites(symbol);
/// ```
/// 
/// 4. USE REAL-TIME STREAMS:
/// ```dart
/// _supabaseService.getFavoritesStream().listen((favorites) {
///   setState(() {
///     _favorites = favorites;
///   });
/// });
/// ```
/// 
/// 5. AUTHENTICATION CHECKS:
/// ```dart
/// if (_supabaseService.isAuthenticated) {
///   // User is logged in
/// }
/// ```