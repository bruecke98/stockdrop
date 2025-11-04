import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service to manage Android home screen widget communication
class WidgetService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.stockdrop/widget',
  );

  /// Initialize the widget service and send API key to Android
  static Future<void> initialize() async {
    try {
      final apiKey = dotenv.env['FMP_API_KEY'];
      if (apiKey != null && apiKey.isNotEmpty) {
        await _channel.invokeMethod('setApiKey', {'apiKey': apiKey});
        print('✅ API key sent to Android widget');

        // Refresh widget after setting API key
        await refreshWidget();
      } else {
        print('⚠️ API key not found in environment variables');
      }
    } catch (e) {
      print('❌ Error initializing widget service: $e');
    }
  }

  /// Refresh the Android home screen widget
  static Future<void> refreshWidget() async {
    try {
      await _channel.invokeMethod('refreshWidget');
      print('🔄 Widget refresh triggered');
    } catch (e) {
      print('❌ Error refreshing widget: $e');
    }
  }
}
