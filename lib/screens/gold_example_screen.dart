import 'package:flutter/material.dart';
import '../widgets/gold_card.dart';
import '../widgets/gold_chart_widget.dart';

/// Example screen showcasing the Gold Card and Gold Chart widgets
///
/// This demonstrates how to integrate gold commodity tracking in StockDrop app:
/// - Gold price card display
/// - Interactive gold price charts
/// - Different layout options and configurations
/// - Error handling and loading states
class GoldExampleScreen extends StatefulWidget {
  const GoldExampleScreen({super.key});

  @override
  State<GoldExampleScreen> createState() => _GoldExampleScreenState();
}

class _GoldExampleScreenState extends State<GoldExampleScreen> {
  bool _showCompactCards = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gold Commodity Tracking'),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: Icon(
              _showCompactCards ? Icons.view_list : Icons.view_compact,
            ),
            onPressed: () {
              setState(() {
                _showCompactCards = !_showCompactCards;
              });
            },
            tooltip: _showCompactCards ? 'Full View' : 'Compact View',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gold Market Overview',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track gold commodity prices (GCUSD) with real-time data and historical charts.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Gold price card section
            _buildGoldCardSection(theme),

            const SizedBox(height: 24),

            // Gold chart section
            _buildGoldChartSection(theme),

            const SizedBox(height: 24),

            // Multiple cards grid (for comparison or multiple timeframes)
            _buildMultipleCardsSection(theme),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Build the main gold card section
  Widget _buildGoldCardSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Current Gold Price',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Main gold card
        GoldCard(
          isCompact: _showCompactCards,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Navigate to detailed gold analysis'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),

        // Show skeleton for comparison in debug mode
        if (!_showCompactCards) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Loading State Example:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const GoldCardSkeleton(),
        ],
      ],
    );
  }

  /// Build the gold chart section
  Widget _buildGoldChartSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Price History',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Main chart
        const GoldChartWidget(
          height: 300,
          showPeriodSelector: true,
          initialPeriod: '1month',
        ),
      ],
    );
  }

  /// Build multiple cards section for comparison
  Widget _buildMultipleCardsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Quick Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Grid of cards and charts
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              // Compact gold card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        'Current Price',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Expanded(
                        child: GoldCard(
                          isCompact: true,
                          margin: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Compact chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        '5-Day Trend',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Expanded(
                        child: CompactGoldChart(
                          height: 80,
                          lineColor: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 32,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Market Info',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gold/USD pair\nCommodity tracking',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // Action card
              Card(
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Navigate to alerts setup'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          size: 32,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Set Alerts',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Price notifications',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
