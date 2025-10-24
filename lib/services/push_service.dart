import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Push notification service for OneSignal integration in StockDrop app
/// Handles initialization, user registration, and notification management
class PushService {
  static final PushService _instance = PushService._internal();
  factory PushService() => _instance;
  PushService._internal();

  bool _isInitialized = false;
  String? _playerId;
  String? _pushToken;

  /// Callback for handling notification navigation
  Function(Map<String, dynamic>)? onNotificationOpened;

  /// Callback for handling foreground notifications
  Function(OSNotification)? onForegroundNotification;

  /// Get OneSignal App ID from environment variables
  static String get _appId {
    final appId = dotenv.env['ONESIGNAL_APP_ID'];
    if (appId == null || appId.isEmpty) {
      throw Exception('ONESIGNAL_APP_ID not found in environment variables');
    }
    return appId;
  }

  /// Check if OneSignal is initialized
  bool get isInitialized => _isInitialized;

  /// Get current player ID (OneSignal user ID)
  String? get playerId => _playerId;

  /// Get current push token
  String? get pushToken => _pushToken;

  // ==================== INITIALIZATION ====================

  /// Initialize OneSignal with all necessary configurations
  Future<bool> initialize() async {
    try {
      if (_isInitialized) {
        debugPrint('🔔 PushService already initialized');
        return true;
      }

      debugPrint('🔔 Initializing PushService with OneSignal...');

      // Set debug level for development
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // Initialize OneSignal with App ID
      OneSignal.initialize(_appId);

      // Request notification permission
      final permissionGranted = await OneSignal.Notifications.requestPermission(
        true,
      );
      debugPrint('🔔 Notification permission granted: $permissionGranted');

      // Set up notification handlers
      await _setupNotificationHandlers();

      // Get initial player ID and push token
      await _getDeviceInfo();

      _isInitialized = true;
      debugPrint('✅ PushService initialized successfully');

      return true;
    } catch (e) {
      debugPrint('❌ Error initializing PushService: $e');
      return false;
    }
  }

  /// Set up all OneSignal notification handlers
  Future<void> _setupNotificationHandlers() async {
    try {
      // Handle foreground notifications (when app is open)
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        final notification = event.notification;
        debugPrint(
          '🔔 Foreground notification: ${notification.title} - ${notification.body}',
        );

        // Call custom handler if provided
        onForegroundNotification?.call(notification);

        // Show in-app alert for foreground notifications
        _showInAppNotification(notification);
      });

      // Handle notification clicks
      OneSignal.Notifications.addClickListener((event) {
        final notification = event.notification;
        final additionalData = notification.additionalData;

        debugPrint('🔔 Notification clicked: ${notification.title}');

        if (additionalData != null) {
          debugPrint('🔔 Additional data: $additionalData');

          // Call custom handler if provided
          onNotificationOpened?.call(additionalData);

          // Handle different notification types
          _handleNotificationClick(additionalData);
        }
      });

      // Handle permission changes
      OneSignal.Notifications.addPermissionObserver((state) {
        debugPrint('🔔 Notification permission changed: $state');
      });

      // Handle push subscription changes
      OneSignal.User.addObserver((state) {
        debugPrint('🔔 User state changed');
        // Note: User state properties depend on OneSignal SDK version
        // This is a placeholder for when user state changes
      });

      // Get initial player ID if available
      Future.delayed(const Duration(seconds: 1), () async {
        try {
          // OneSignal player ID is available after initialization
          debugPrint('🔔 Checking for player ID after initialization...');
        } catch (e) {
          debugPrint('❌ Error getting initial player ID: $e');
        }
      });

      debugPrint('✅ Notification handlers set up successfully');
    } catch (e) {
      debugPrint('❌ Error setting up notification handlers: $e');
    }
  }

  /// Get initial device information
  Future<void> _getDeviceInfo() async {
    try {
      // OneSignal player ID and push token are obtained differently
      // depending on the SDK version. This is a placeholder implementation.
      debugPrint('🔔 Getting device info...');

      // Player ID might be available through different methods
      // depending on OneSignal SDK version
      debugPrint('🔔 Device info retrieval completed');
    } catch (e) {
      debugPrint('❌ Error getting device info: $e');
    }
  }

  // ==================== USER REGISTRATION ====================

  /// Register user with OneSignal using Supabase user ID
  ///
  /// This links the Supabase user with OneSignal for targeted notifications
  Future<bool> registerUser() async {
    try {
      if (!_isInitialized) {
        throw Exception(
          'PushService not initialized. Call initialize() first.',
        );
      }

      // Get current Supabase user
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      if (supabaseUser == null) {
        throw Exception('No authenticated Supabase user found');
      }

      final userId = supabaseUser.id;
      final userEmail = supabaseUser.email;

      debugPrint('🔔 Registering user with OneSignal: $userId');

      // Set external user ID (Supabase user ID) in OneSignal
      await OneSignal.login(userId);

      // Set user email for better targeting (if supported by SDK version)
      if (userEmail != null) {
        try {
          // Note: Email setting method depends on OneSignal SDK version
          debugPrint(
            '🔔 User email: $userEmail (setting not implemented for this SDK version)',
          );
        } catch (e) {
          debugPrint(
            '⚠️ Email setting not supported in this OneSignal version: $e',
          );
        }
      }

      // Add custom tags for user segmentation
      await _setUserTags(supabaseUser);

      debugPrint('✅ User registered successfully with OneSignal');
      return true;
    } catch (e) {
      debugPrint('❌ Error registering user: $e');
      return false;
    }
  }

  /// Set custom tags for user segmentation
  Future<void> _setUserTags(User user) async {
    try {
      final tags = <String, String>{
        'user_id': user.id,
        'user_type': 'authenticated',
        'app_version': '1.0.0', // You can get this dynamically
        'registration_date': DateTime.now().toIso8601String(),
      };

      // Add email if available
      if (user.email != null) {
        tags['email'] = user.email!;
      }

      // Set tags in OneSignal
      OneSignal.User.addTags(tags);

      debugPrint('🔔 User tags set: $tags');
    } catch (e) {
      debugPrint('❌ Error setting user tags: $e');
    }
  }

  /// Logout user from OneSignal
  Future<bool> logoutUser() async {
    try {
      if (!_isInitialized) {
        debugPrint('⚠️ PushService not initialized');
        return false;
      }

      await OneSignal.logout();

      // Clear local data
      _playerId = null;

      debugPrint('✅ User logged out from OneSignal');
      return true;
    } catch (e) {
      debugPrint('❌ Error logging out user: $e');
      return false;
    }
  }

  // ==================== NOTIFICATION HANDLING ====================

  /// Show in-app notification alert when app is in foreground
  void _showInAppNotification(OSNotification notification) {
    // Get the current context - this would need to be set from main app
    final context = _getCurrentContext();
    if (context == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          notification.title ?? 'Notification',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.body != null) ...[
              Text(notification.body!),
              const SizedBox(height: 12),
            ],
            if (notification.additionalData != null &&
                notification.additionalData!.isNotEmpty) ...[
              const Text(
                'Additional Info:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                notification.additionalData.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
          if (notification.additionalData != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleNotificationClick(notification.additionalData!);
              },
              child: const Text('View'),
            ),
        ],
      ),
    );
  }

  /// Handle notification click navigation
  void _handleNotificationClick(Map<String, dynamic> additionalData) {
    try {
      final context = _getCurrentContext();
      if (context == null) return;

      // Handle different notification types based on additional data
      final type = additionalData['type']?.toString();
      final symbol = additionalData['symbol']?.toString();
      final route = additionalData['route']?.toString();

      debugPrint(
        '🔔 Handling notification click - Type: $type, Symbol: $symbol',
      );

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
        case 'market_news':
          Navigator.pushNamed(context, '/home');
          break;
        case 'custom_route':
          if (route != null) {
            Navigator.pushNamed(context, route);
          }
          break;
        default:
          // Default action - go to home
          Navigator.pushNamed(context, '/home');
      }
    } catch (e) {
      debugPrint('❌ Error handling notification click: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Get current navigation context
  /// Note: This is a placeholder - you'll need to implement this based on your app structure
  BuildContext? _getCurrentContext() {
    // In a real app, you might store the navigator key globally
    // or use a different approach to get the current context
    return null; // This should be implemented based on your app architecture
  }

  /// Set the navigation context for notifications
  void setNavigationContext(BuildContext context) {
    // Store context reference for navigation
    // Implement this based on your app's navigation structure
  }

  /// Check notification permission status
  Future<bool> hasNotificationPermission() async {
    try {
      final permission = OneSignal.Notifications.permission;
      return permission;
    } catch (e) {
      debugPrint('❌ Error checking notification permission: $e');
      return false;
    }
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    try {
      final granted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('🔔 Notification permission request result: $granted');
      return granted;
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  /// Add custom tags for targeting
  Future<bool> addTags(Map<String, String> tags) async {
    try {
      if (!_isInitialized) {
        throw Exception('PushService not initialized');
      }

      OneSignal.User.addTags(tags);
      debugPrint('🔔 Custom tags added: $tags');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding tags: $e');
      return false;
    }
  }

  /// Remove specific tags
  Future<bool> removeTags(List<String> tagKeys) async {
    try {
      if (!_isInitialized) {
        throw Exception('PushService not initialized');
      }

      OneSignal.User.removeTags(tagKeys);
      debugPrint('🔔 Tags removed: $tagKeys');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing tags: $e');
      return false;
    }
  }

  /// Send test notification (for development)
  Future<void> sendTestNotification() async {
    try {
      if (!kDebugMode) {
        debugPrint('⚠️ Test notifications only available in debug mode');
        return;
      }

      // This would typically be done from your backend
      debugPrint('🔔 Test notification would be sent from backend');
      debugPrint('🔔 Player ID for testing: $_playerId');
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
    }
  }

  /// Get notification history (if supported)
  Future<List<OSNotification>> getNotificationHistory() async {
    try {
      // OneSignal doesn't provide a built-in history API
      // You might want to store notifications locally or on your backend
      debugPrint('🔔 Notification history not implemented');
      return [];
    } catch (e) {
      debugPrint('❌ Error getting notification history: $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _isInitialized = false;
    _playerId = null;
    _pushToken = null;
    onNotificationOpened = null;
    onForegroundNotification = null;
    debugPrint('🔔 PushService disposed');
  }

  // ==================== DEBUG METHODS ====================

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'playerId': _playerId,
      'hasPushToken': _pushToken != null,
      'pushTokenLength': _pushToken?.length,
      'appId': _appId,
    };
  }

  /// Print debug information
  void printDebugInfo() {
    final info = getDebugInfo();
    debugPrint('🔔 PushService Debug Info:');
    info.forEach((key, value) {
      debugPrint('   $key: $value');
    });
  }
}

// ==================== MODELS ====================

/// Notification data model for structured handling
class NotificationData {
  final String? title;
  final String? body;
  final String? type;
  final String? symbol;
  final String? route;
  final Map<String, dynamic>? additionalData;
  final DateTime receivedAt;

  NotificationData({
    this.title,
    this.body,
    this.type,
    this.symbol,
    this.route,
    this.additionalData,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory NotificationData.fromOSNotification(OSNotification notification) {
    final additionalData = notification.additionalData ?? {};

    return NotificationData(
      title: notification.title,
      body: notification.body,
      type: additionalData['type']?.toString(),
      symbol: additionalData['symbol']?.toString(),
      route: additionalData['route']?.toString(),
      additionalData: additionalData,
    );
  }

  @override
  String toString() {
    return 'NotificationData(title: $title, type: $type, symbol: $symbol)';
  }
}

/// Push service exception for error handling
class PushServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  PushServiceException(this.message, {this.code, this.originalError});

  @override
  String toString() {
    return 'PushServiceException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}
