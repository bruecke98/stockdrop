import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/top_decline_widget.dart';

/// Home screen widget app specifically for Android widgets
/// This creates a minimal app that shows just the top decline widget
class HomeScreenWidgetApp extends StatelessWidget {
  const HomeScreenWidgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockDrop Widget',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreenWidgetPage(),
    );
  }
}

class HomeScreenWidgetPage extends StatelessWidget {
  const HomeScreenWidgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TopDeclineWidget(
            height: 100,
            padding: const EdgeInsets.all(12),
            onTap: () {
              // When tapped, try to open the main app
              _openMainApp();
            },
          ),
        ),
      ),
    );
  }

  void _openMainApp() {
    // This would typically launch the main app
    // For now, we'll just provide haptic feedback
    HapticFeedback.lightImpact();
  }
}

/// Compact widget specifically designed for small Android home screen widgets
class CompactHomeScreenWidget extends StatelessWidget {
  const CompactHomeScreenWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockDrop Mini',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CompactTopDeclineWidget(
            onTap: () {
              HapticFeedback.lightImpact();
            },
          ),
        ),
      ),
    );
  }
}
