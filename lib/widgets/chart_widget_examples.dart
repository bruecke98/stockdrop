import 'package:flutter/material.dart';
import '../widgets/chart_widget.dart';
import '../models/stock.dart';

/// Example usage of ChartWidget in different contexts within StockDrop app
///
/// This demonstrates how to integrate the ChartWidget in:
/// - Stock detail screens
/// - Home screen with multiple charts
/// - Search results with compact charts
/// - Different chart configurations
class ChartWidgetExample extends StatefulWidget {
  const ChartWidgetExample({super.key});

  @override
  State<ChartWidgetExample> createState() => _ChartWidgetExampleState();
}

class _ChartWidgetExampleState extends State<ChartWidgetExample> {
  String _selectedSymbol = 'AAPL';
  final List<String> _popularSymbols = [
    'AAPL',
    'GOOGL',
    'MSFT',
    'TSLA',
    'AMZN',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chart Examples'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Full-featured Chart
            Text(
              'Full Chart Widget',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Interactive 5-minute intraday chart with touch support',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Symbol selector
            Row(
              children: [
                Text('Symbol: ', style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedSymbol,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedSymbol = newValue);
                    }
                  },
                  items: _popularSymbols.map((symbol) {
                    return DropdownMenuItem<String>(
                      value: symbol,
                      child: Text(symbol),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Main chart
            ChartWidget(symbol: _selectedSymbol, height: 350),

            const SizedBox(height: 32),

            // Section 2: Compact Charts
            Text(
              'Compact Charts',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Smaller charts for overview displays',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Grid of compact charts
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                final symbol = _popularSymbols[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CompactChartWidget(symbol: symbol, height: 120),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Section 3: Custom Styled Charts
            Text(
              'Custom Styled Charts',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Charts with custom colors and styling',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Green chart (gains)
            ChartWidget(symbol: 'AAPL', height: 250, lineColor: Colors.green),

            const SizedBox(height: 16),

            // Red chart (losses)
            ChartWidget(symbol: 'TSLA', height: 250, lineColor: Colors.red),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Example of using ChartWidget in a stock detail screen
class StockDetailWithChart extends StatelessWidget {
  final Stock stock;

  const StockDetailWithChart({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine chart color based on stock performance
    final chartColor = stock.changePercent >= 0
        ? colorScheme.primary
        : colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(stock.symbol),
        backgroundColor: colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stock info header
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

            // Chart section
            Text(
              'Price Chart',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            ChartWidget(
              symbol: stock.symbol,
              height: 400,
              lineColor: chartColor,
            ),

            const SizedBox(height: 24),

            // Additional stock info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Change',
                      '\$${stock.change.toStringAsFixed(2)}',
                    ),
                    _buildInfoRow('Volume', stock.volume?.toString() ?? 'N/A'),
                    if (stock.marketCap != null)
                      _buildInfoRow(
                        'Market Cap',
                        '\$${(stock.marketCap! / 1e9).toStringAsFixed(2)}B',
                      ),
                    if (stock.dayHigh != null)
                      _buildInfoRow(
                        'Day High',
                        '\$${stock.dayHigh!.toStringAsFixed(2)}',
                      ),
                    if (stock.dayLow != null)
                      _buildInfoRow(
                        'Day Low',
                        '\$${stock.dayLow!.toStringAsFixed(2)}',
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Example of using charts in a dashboard/home screen
class DashboardWithCharts extends StatelessWidget {
  final List<Stock> topStocks;

  const DashboardWithCharts({super.key, required this.topStocks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('StockDrop Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Market Overview',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Featured chart
            if (topStocks.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Featured: ${topStocks.first.symbol}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ChartWidget(symbol: topStocks.first.symbol, height: 300),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            Text(
              'Quick Charts',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Grid of quick charts
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: topStocks.length.clamp(0, 4),
              itemBuilder: (context, index) {
                final stock = topStocks[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.symbol,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${stock.price.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: CompactChartWidget(
                            symbol: stock.symbol,
                            lineColor: stock.changePercent >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
