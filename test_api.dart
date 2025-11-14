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

  print('Testing market hours API endpoint...');

  // Test market hours endpoint
  final url = Uri.parse(
    'https://financialmodelingprep.com/stable/all-exchange-market-hours?apikey=$apiKey',
  );
  print('URL: $url');

  try {
    final response = await http.get(url);
    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Data type: ${data.runtimeType}');
      if (data is List && data.isNotEmpty) {
        print('Number of exchanges: ${data.length}');
        // Find NYSE
        final nyse = data.firstWhere(
          (item) => item['exchange'] == 'NYSE',
          orElse: () => null,
        );
        if (nyse != null) {
          print('NYSE data: $nyse');
        } else {
          print('NYSE not found');
          print('First few exchanges:');
          for (var i = 0; i < min(5, data.length); i++) {
            print(
              '  ${data[i]['exchange']}: ${data[i]['name']} - ${data[i]['timezone']}',
            );
          }
        }
      } else {
        print('Response: ${response.body}');
      }
    } else {
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}

int min(int a, int b) => a < b ? a : b;
