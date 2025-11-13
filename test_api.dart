import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load();

  final apiKey = dotenv.env['FMP_API_KEY'];
  if (apiKey == null) {
    print('API key not found');
    return;
  }

  print('Testing stock-screener API endpoint...');

  // Test stock-screener endpoint
  final url = Uri.parse(
    'https://financialmodelingprep.com/api/v3/stock-screener?sector=Technology&limit=2&apikey=$apiKey',
  );
  print('URL: $url');

  try {
    final response = await http.get(url);
    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Data type: ${data.runtimeType}');
      if (data is List && data.isNotEmpty) {
        print('First item keys: ${data[0].keys.toList()}');
        print('First item: ${data[0]}');
      }
    } else {
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
