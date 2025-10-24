import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Settings screen for StockDrop app
/// Manages user preferences including notifications, theme, and account settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _notificationThreshold = 5;
  String _selectedTheme = 'system';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  final List<int> _thresholdOptions = [3, 5, 10];
  final Map<String, String> _themeOptions = {
    'light': 'Light',
    'dark': 'Dark',
    'system': 'System',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget(theme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNotificationSettings(theme),
          const SizedBox(height: 24),
          _buildAppearanceSettings(theme),
          const SizedBox(height: 24),
          _buildAccountSettings(theme),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Notifications',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Price Change Threshold',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get notified when your favorite stocks change by this percentage or more.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _notificationThreshold,
                  isExpanded: true,
                  items: _thresholdOptions.map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('${value}%'),
                    );
                  }).toList(),
                  onChanged: _isSaving
                      ? null
                      : (int? newValue) {
                          if (newValue != null &&
                              newValue != _notificationThreshold) {
                            setState(() {
                              _notificationThreshold = newValue;
                            });
                            _saveSettings();
                          }
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSettings(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Appearance',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Theme',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your preferred app appearance.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ..._themeOptions.entries.map((entry) {
              return RadioListTile<String>(
                title: Text(entry.value),
                value: entry.key,
                groupValue: _selectedTheme,
                onChanged: _isSaving
                    ? null
                    : (String? value) {
                        if (value != null && value != _selectedTheme) {
                          setState(() {
                            _selectedTheme = value;
                          });
                          _saveSettings();
                        }
                      },
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSettings(ThemeData theme) {
    final user = Supabase.instance.client.auth.currentUser;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Account',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (user != null) ...[
              Row(
                children: [
                  Text(
                    'Email:',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user.email ?? 'No email',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showLogoutConfirmation,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Settings',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
                _loadSettings();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    try {
      // Load from SharedPreferences first for immediate UI update
      await _loadLocalTheme();

      // Then load from Supabase for authoritative data
      await _loadSupabaseSettings();

      setState(() {
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLocalTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('app_theme') ?? 'system';
      setState(() {
        _selectedTheme = savedTheme;
      });
    } catch (e) {
      debugPrint('Error loading local theme: $e');
    }
  }

  Future<void> _loadSupabaseSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await Supabase.instance.client
          .from('st_settings')
          .select('notification_threshold, theme')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _notificationThreshold = response['notification_threshold'] ?? 5;
          _selectedTheme = response['theme'] ?? 'system';
        });

        // Update local cache
        await _saveLocalTheme(_selectedTheme);
      } else {
        // Create default settings if none exist
        await _createDefaultSettings(user.id);
      }
    } catch (e) {
      debugPrint('Error loading Supabase settings: $e');
      // Continue with local settings if Supabase fails
    }
  }

  Future<void> _createDefaultSettings(String userId) async {
    try {
      await Supabase.instance.client.from('st_settings').insert({
        'user_id': userId,
        'notification_threshold': _notificationThreshold,
        'theme': _selectedTheme,
      });
    } catch (e) {
      debugPrint('Error creating default settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Save to Supabase
      await Supabase.instance.client.from('st_settings').upsert({
        'user_id': user.id,
        'notification_threshold': _notificationThreshold,
        'theme': _selectedTheme,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      // Save theme to local cache
      await _saveLocalTheme(_selectedTheme);

      _showMessage('Settings saved successfully');
    } catch (e) {
      _showMessage('Failed to save settings: $e', isError: true);
      debugPrint('Error saving settings: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _saveLocalTheme(String theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme', theme);
    } catch (e) {
      debugPrint('Error saving local theme: $e');
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        // Clear local cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Navigate to login screen
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      _showMessage('Failed to logout: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
