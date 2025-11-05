import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/commodity_card.dart';

/// Silver example screen demonstrating silver commodity tracking
/// Shows current silver price, trends, and market information
class SilverExampleScreen extends StatefulWidget {
  const SilverExampleScreen({super.key});

  @override
  State<SilverExampleScreen> createState() => _SilverExampleScreenState();
}

class _SilverExampleScreenState extends State<SilverExampleScreen> {
  List<FlSpot> chartData = [];
  bool isLoading = true;
  double currentPrice = 0.0;
  double changePercent = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchSilverData();
  }

  Future<void> _fetchSilverData() async {
    try {
      // You should replace 'your_api_key' with actual API key from shared preferences
      const apiKey = 'your_api_key';

      // Fetch current price
      final quoteResponse = await http.get(
        Uri.parse(
          'https://financialmodelingprep.com/api/v3/quote/SIUSD?apikey=$apiKey',
        ),
      );

      // Fetch historical data (240 days)
      final DateTime endDate = DateTime.now();
      final DateTime startDate = endDate.subtract(const Duration(days: 240));
      final String fromDate =
          "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      final String toDate =
          "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";

      final historicalResponse = await http.get(
        Uri.parse(
          'https://financialmodelingprep.com/api/v3/historical-price-full/SIUSD?from=$fromDate&to=$toDate&apikey=$apiKey',
        ),
      );

      if (quoteResponse.statusCode == 200 &&
          historicalResponse.statusCode == 200) {
        final quoteData = json.decode(quoteResponse.body);
        final historicalData = json.decode(historicalResponse.body);

        if (quoteData.isNotEmpty) {
          setState(() {
            currentPrice = quoteData[0]['price']?.toDouble() ?? 0.0;
            changePercent =
                quoteData[0]['changesPercentage']?.toDouble() ?? 0.0;
          });
        }

        if (historicalData['historical'] != null) {
          final List<dynamic> historical = historicalData['historical'];
          setState(() {
            chartData = historical
                .asMap()
                .entries
                .map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    entry.value['close']?.toDouble() ?? 0.0,
                  );
                })
                .toList()
                .reversed
                .toList(); // Reverse to get chronological order
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching silver data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.circle, color: Colors.grey.shade600, size: 24),
            const SizedBox(width: 8),
            const Text('Silver Tracking'),
          ],
        ),
        centerTitle: false,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.withOpacity(0.15),
                    Colors.grey.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.circle,
                          color: Colors.grey.shade600,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Silver Commodity',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              'Real-time SIUSD tracking',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Track silver prices with real-time data from Financial Modeling Prep API. Monitor trends, analyze performance, and stay updated with precious metals market movements.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Current Silver Price Section
            _buildSectionHeader(
              theme,
              'Current Silver Price',
              Icons.trending_up,
            ),
            const SizedBox(height: 12),
            CommodityCard(
              commodityType: 'silver',
              isCompact: false,
              margin: EdgeInsets.zero,
            ),

            const SizedBox(height: 32),

            // Silver Price Chart Section
            _buildSectionHeader(
              theme,
              'Silver Price Chart (240 Days)',
              Icons.show_chart,
            ),
            const SizedBox(height: 12),
            _buildSilverChart(theme),

            const SizedBox(height: 32),

            // Market Information Section
            _buildSectionHeader(
              theme,
              'Market Information',
              Icons.info_outline,
            ),
            const SizedBox(height: 12),
            _buildMarketInfoCards(theme),

            const SizedBox(height: 32),

            // Silver Facts Section
            _buildSectionHeader(theme, 'About Silver', Icons.lightbulb_outline),
            const SizedBox(height: 12),
            _buildSilverFacts(theme),

            const SizedBox(height: 32),

            // API Information
            _buildApiInfo(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildMarketInfoCards(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                theme,
                'Symbol',
                'SIUSD',
                Icons.code,
                Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                theme,
                'Market',
                'Commodities',
                Icons.store,
                Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                theme,
                'Currency',
                'USD',
                Icons.attach_money,
                Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                theme,
                'Type',
                'Precious Metal',
                Icons.diamond,
                Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSilverFacts(ThemeData theme) {
    final facts = [
      {
        'title': 'Industrial Metal',
        'description':
            'Silver has the highest electrical and thermal conductivity of all metals.',
        'icon': Icons.electrical_services,
      },
      {
        'title': 'Investment Asset',
        'description':
            'Precious metal used as store of value and portfolio diversification.',
        'icon': Icons.savings,
      },
      {
        'title': 'Medical Uses',
        'description':
            'Silver has antimicrobial properties and is used in medical applications.',
        'icon': Icons.medical_services,
      },
      {
        'title': 'Photography',
        'description':
            'Historically important in photography and still used in film.',
        'icon': Icons.camera_alt,
      },
    ];

    return Column(
      children: facts.map((fact) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  fact['icon'] as IconData,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fact['title'] as String,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fact['description'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildApiInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.api, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'API Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Data Source: Financial Modeling Prep API\nEndpoint: /quote/SIUSD\nUpdate Frequency: Real-time\nSymbol: SIUSD (Silver in USD)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSilverChart(ThemeData theme) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.grey))
          : chartData.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.grey.shade400,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load chart data',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${currentPrice.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: changePercent >= 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '240D',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Chart
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: null,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: null,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '\$${value.toInt()}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: chartData,
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey.shade600,
                              Colors.grey.shade400,
                            ],
                          ),
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.shade300.withOpacity(0.3),
                                Colors.grey.shade100.withOpacity(0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
