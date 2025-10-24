import 'package:flutter/material.dart';
import '../services/push_service.dart';
import '../services/supabase_service.dart';

/// Example usage of PushService in StockDrop app
/// This file demonstrates how to integrate push notifications properly
class ExamplePushUsage extends StatefulWidget {
  const ExamplePushUsage({super.key});

  @override
  State<ExamplePushUsage> createState() => _ExamplePushUsageState();
}

class _ExamplePushUsageState extends State<ExamplePushUsage> {
  final PushService _pushService = PushService();
  final SupabaseService _supabaseService = SupabaseService();

  bool _isInitialized = false;
  bool _isRegistered = false;
  bool _hasPermission = false;
  String? _playerId;
  String? _pushToken;

  @override
  void initState() {
    super.initState();
    _setupPushService();
  }

  /// Initialize and configure push service
  Future<void> _setupPushService() async {
    try {
      // Initialize push service
      final initialized = await _pushService.initialize();

      setState(() {
        _isInitialized = initialized;
      });

      if (initialized) {
        // Set up custom notification handlers
        _pushService.onForegroundNotification = _handleForegroundNotification;
        _pushService.onNotificationOpened = _handleNotificationOpened;

        // Check permission status
        final hasPermission = await _pushService.hasNotificationPermission();

        setState(() {
          _hasPermission = hasPermission;
          _playerId = _pushService.playerId;
          _pushToken = _pushService.pushToken;
        });

        // Register user if authenticated
        if (_supabaseService.isAuthenticated) {
          await _registerUserWithPush();
        }
      }
    } catch (e) {
      _showError('Failed to setup push service: $e');
    }
  }

  /// Register authenticated user with push service
  Future<void> _registerUserWithPush() async {
    try {
      final registered = await _pushService.registerUser();

      setState(() {
        _isRegistered = registered;
      });

      if (registered) {
        // Add custom tags for better targeting
        await _addCustomTags();
        _showSuccess('User registered with push notifications');
      }
    } catch (e) {
      _showError('Failed to register user: $e');
    }
  }

  /// Add custom tags for targeted notifications
  Future<void> _addCustomTags() async {
    try {
      final tags = {
        'app_section': 'stocks',
        'user_preference': 'active_trader',
        'notification_frequency': 'high',
        'last_activity': DateTime.now().toIso8601String(),
      };

      await _pushService.addTags(tags);
    } catch (e) {
      debugPrint('Failed to add custom tags: $e');
    }
  }

  /// Handle foreground notifications
  void _handleForegroundNotification(notification) {
    debugPrint('Foreground notification received: ${notification.title}');

    // You can customize this behavior
    // For example, show a custom in-app notification
    _showNotificationSnackBar('${notification.title}: ${notification.body}');
  }

  /// Handle notification opening/clicking
  void _handleNotificationOpened(Map<String, dynamic> data) {
    debugPrint('Notification opened with data: $data');

    // Handle navigation based on notification data
    final type = data['type']?.toString();
    final symbol = data['symbol']?.toString();

    switch (type) {
      case 'stock_alert':
        if (symbol != null) {
          Navigator.pushNamed(
            context,
            '/detail',
            arguments: {'symbol': symbol},
          );
        }
        break;
      case 'price_change':
        if (symbol != null) {
          Navigator.pushNamed(
            context,
            '/detail',
            arguments: {'symbol': symbol},
          );
        }
        break;
      default:
        Navigator.pushNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notifications'),
        actions: [
          IconButton(icon: const Icon(Icons.info), onPressed: _showDebugInfo),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Cards
          _buildStatusCard(),
          const SizedBox(height: 20),

          // Device Info
          _buildDeviceInfo(),
          const SizedBox(height: 20),

          // Actions
          _buildActions(),
          const SizedBox(height: 20),

          // Test Features
          if (_isInitialized) _buildTestFeatures(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Push Service Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Initialized', _isInitialized),
            _buildStatusRow('Permission Granted', _hasPermission),
            _buildStatusRow('User Registered', _isRegistered),
            _buildStatusRow(
              'User Authenticated',
              _supabaseService.isAuthenticated,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Player ID', _playerId ?? 'Not available'),
            _buildInfoRow(
              'Push Token',
              _pushToken != null
                  ? '${_pushToken!.substring(0, 20)}...'
                  : 'Not available',
            ),
            _buildInfoRow(
              'User Email',
              _supabaseService.userEmail ?? 'Not available',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
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
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isInitialized ? null : _setupPushService,
                  child: const Text('Initialize'),
                ),
                ElevatedButton(
                  onPressed: !_hasPermission ? _requestPermission : null,
                  child: const Text('Request Permission'),
                ),
                ElevatedButton(
                  onPressed:
                      _isInitialized &&
                          !_isRegistered &&
                          _supabaseService.isAuthenticated
                      ? _registerUserWithPush
                      : null,
                  child: const Text('Register User'),
                ),
                ElevatedButton(
                  onPressed: _isRegistered ? _logoutUser : null,
                  child: const Text('Logout'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestFeatures() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Features',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _sendTestNotification,
                  child: const Text('Test Notification'),
                ),
                ElevatedButton(
                  onPressed: _addTestTags,
                  child: const Text('Add Test Tags'),
                ),
                ElevatedButton(
                  onPressed: _removeTestTags,
                  child: const Text('Remove Tags'),
                ),
                ElevatedButton(
                  onPressed: _showDebugInfo,
                  child: const Text('Debug Info'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _requestPermission() async {
    try {
      final granted = await _pushService.requestNotificationPermission();

      setState(() {
        _hasPermission = granted;
      });

      if (granted) {
        _showSuccess('Notification permission granted');
      } else {
        _showError('Notification permission denied');
      }
    } catch (e) {
      _showError('Failed to request permission: $e');
    }
  }

  Future<void> _logoutUser() async {
    try {
      final success = await _pushService.logoutUser();

      if (success) {
        setState(() {
          _isRegistered = false;
          _playerId = null;
        });
        _showSuccess('User logged out from push service');
      }
    } catch (e) {
      _showError('Failed to logout: $e');
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await _pushService.sendTestNotification();
      _showSuccess('Test notification sent (check debug console)');
    } catch (e) {
      _showError('Failed to send test notification: $e');
    }
  }

  Future<void> _addTestTags() async {
    try {
      final testTags = {
        'test_tag': 'test_value',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      final success = await _pushService.addTags(testTags);

      if (success) {
        _showSuccess('Test tags added');
      }
    } catch (e) {
      _showError('Failed to add test tags: $e');
    }
  }

  Future<void> _removeTestTags() async {
    try {
      final success = await _pushService.removeTags(['test_tag', 'timestamp']);

      if (success) {
        _showSuccess('Test tags removed');
      }
    } catch (e) {
      _showError('Failed to remove test tags: $e');
    }
  }

  void _showDebugInfo() {
    _pushService.printDebugInfo();

    final debugInfo = _pushService.getDebugInfo();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: debugInfo.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${entry.key}: ${entry.value}'),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ==================== HELPERS ====================

  void _showSuccess(String message) {
    _showSnackBar(message, Colors.green);
  }

  void _showError(String message) {
    _showSnackBar(message, Colors.red);
  }

  void _showNotificationSnackBar(String message) {
    _showSnackBar(message, Colors.blue);
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// How to integrate PushService in your app:
/// 
/// 1. INITIALIZE IN MAIN.DART:
/// Instead of manual OneSignal setup, use PushService:
/// ```dart
/// import 'services/push_service.dart';
/// 
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await dotenv.load(fileName: ".env");
///   
///   // Initialize Supabase first
///   await Supabase.initialize(...);
///   
///   // Initialize PushService (replaces manual OneSignal setup)
///   final pushService = PushService();
///   await pushService.initialize();
///   
///   runApp(MyApp());
/// }
/// ```
/// 
/// 2. REGISTER USER AFTER LOGIN:
/// ```dart
/// // After successful Supabase authentication
/// final pushService = PushService();
/// await pushService.registerUser();
/// ```
/// 
/// 3. HANDLE NOTIFICATIONS:
/// ```dart
/// pushService.onNotificationOpened = (data) {
///   // Handle navigation based on notification data
///   final symbol = data['symbol'];
///   if (symbol != null) {
///     Navigator.pushNamed(context, '/detail', arguments: {'symbol': symbol});
///   }
/// };
/// ```
/// 
/// 4. LOGOUT HANDLING:
/// ```dart
/// // When user logs out
/// await pushService.logoutUser();
/// await supabaseService.signOut();
/// ```
/// 
/// 5. PERMISSION MANAGEMENT:
/// ```dart
/// // Check permission
/// final hasPermission = await pushService.hasNotificationPermission();
/// 
/// // Request permission
/// if (!hasPermission) {
///   await pushService.requestNotificationPermission();
/// }
/// ```