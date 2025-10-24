import 'package:flutter/material.dart';
import '../widgets/chart_widget.dart';
import '../widgets/stock_card.dart';
import '../models/stock.dart';

/// Simple demo screen to showcase ChartWidget integration
/// This can be used for testing and demonstration purposes
class ChartDemoScreen extends StatelessWidget {
  const ChartDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample stock data for demonstration
    final sampleStocks = [
      Stock(
        symbol: 'AAPL',
        name: 'Apple Inc.',
        price: 175.43,
        change: 2.15,
        changePercent: 1.24,
      ),
      Stock(
        symbol: 'GOOGL',
        name: 'Alphabet Inc.',
        price: 142.56,
        change: -1.23,
        changePercent: -0.85,
      ),
      Stock(
        symbol: 'MSFT',
        name: 'Microsoft Corporation',
        price: 378.85,
        change: 5.67,
        changePercent: 1.52,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chart Demo'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Demo header
            Text(
              'StockDrop Chart Integration Demo',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This demonstrates the ChartWidget integrated with stock cards.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Stock cards with integrated charts
            ...sampleStocks.map(
              (stock) => Column(
                children: [
                  // Stock card
                  StockCard(
                    stock: stock,
                    onTap: () {
                      // Navigate to detail screen or show chart
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              _StockChartDetailScreen(stock: stock),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Compact chart preview
                  CompactChartWidget(
                    symbol: stock.symbol,
                    height: 150,
                    lineColor: stock.changePercent >= 0
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Full chart example
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Full Chart Example',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ChartWidget(symbol: 'AAPL', height: 400, lineColor: Colors.blue),
          ],
        ),
      ),
    );
  }
}

/// Detail screen showing a stock with its chart
class _StockChartDetailScreen extends StatelessWidget {
  final Stock stock;

  const _StockChartDetailScreen({required this.stock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chartColor = stock.changePercent >= 0
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(stock.symbol),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stock info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '\$${stock.price.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: chartColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${stock.changePercent >= 0 ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: chartColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Chart
            ChartWidget(
              symbol: stock.symbol,
              height: 400,
              lineColor: chartColor,
            ),

            const SizedBox(height: 24),

            // Chart features info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chart Features',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem('📊', 'Real-time 5-minute intraday data'),
                    _buildFeatureItem('🎯', 'Interactive touch tooltips'),
                    _buildFeatureItem(
                      '🔄',
                      'Automatic loading and error handling',
                    ),
                    _buildFeatureItem(
                      '🎨',
                      'Material 3 design with gradient fills',
                    ),
                    _buildFeatureItem(
                      '📈',
                      'Performance optimized for smooth scrolling',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
