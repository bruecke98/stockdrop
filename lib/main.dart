import 'package:flutter/material.dart';
// Import screens
// import 'screens/login_screen.dart';
// import 'screens/home_screen.dart';
// import 'screens/search_screen.dart';
// import 'screens/favorites_screen.dart';
// import 'screens/detail_screen.dart';
// import 'screens/settings_screen.dart';

// Import providers
// import 'providers/stock_provider.dart';

void main() {
  runApp(const StockDropApp());
}

class StockDropApp extends StatelessWidget {
  const StockDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockDrop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // home: const LoginScreen(), // Uncomment when LoginScreen is implemented
      home: const Scaffold(
        body: Center(
          child: Text(
            'StockDrop App\nComing Soon!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
