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

  print('Testing sector P/E API endpoint...');

  // Test without date
  final url1 = Uri.parse(
    'https://financialmodelingprep.com/api/v3/sector-pe-snapshot?apikey=$apiKey',
  );
  print('URL without date: $url1');

  try {
    final response1 = await http.get(url1);
    print('Status: ${response1.statusCode}');
    print('Response length: ${response1.body.length}');
    if (response1.body.length < 500) {
      print('Response: ${response1.body}');
    } else {
      print('Response preview: ${response1.body.substring(0, 200)}...');
    }

    if (response1.statusCode == 200) {
      final data = json.decode(response1.body);
      print('Data type: ${data.runtimeType}');
      if (data is List && data.isNotEmpty) {
        print('First item: ${data[0]}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test with date
  final url2 = Uri.parse(
    'https://financialmodelingprep.com/api/v3/sector-pe-snapshot?date=2025-11-03&apikey=$apiKey',
  );
  print('\nURL with date: $url2');

  try {
    final response2 = await http.get(url2);
    print('Status: ${response2.statusCode}');
    print('Response length: ${response2.body.length}');
    if (response2.body.length < 500) {
      print('Response: ${response2.body}');
    } else {
      print('Response preview: ${response2.body.substring(0, 200)}...');
    }
  } catch (e) {
    print('Error: $e');
  }
}
