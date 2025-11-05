import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/commodity_card.dart';

/// Oil example screen demonstrating crude oil commodity tracking
/// Shows current oil price, trends, and market information
class OilExampleScreen extends StatefulWidget {
  const OilExampleScreen({super.key});

  @override
  State<OilExampleScreen> createState() => _OilExampleScreenState();
}

class _OilExampleScreenState extends State<OilExampleScreen> {
  List<FlSpot> chartData = [];
  bool isLoading = true;
  double currentPrice = 0.0;
  double changePercent = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchOilData();
  }

  Future<void> _fetchOilData() async {
    try {
      // You should replace 'your_api_key' with actual API key from shared preferences
      const apiKey = 'your_api_key';

      // Fetch current price
      final quoteResponse = await http.get(
        Uri.parse(
          'https://financialmodelingprep.com/api/v3/quote/CLUSD?apikey=$apiKey',
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
          'https://financialmodelingprep.com/api/v3/historical-price-full/CLUSD?from=$fromDate&to=$toDate&apikey=$apiKey',
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
      print('Error fetching oil data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildOilChart() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.brown),
      );
    }

    if (chartData.isEmpty) {
      return const Center(child: Text('No chart data available'));
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            verticalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.brown.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.brown.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() % 40 == 0) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        '${(240 - value.toInt())}d',
                        style: const TextStyle(
                          color: Colors.brown,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return Container();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '\$${value.toInt()}',
                    style: const TextStyle(
                      color: Colors.brown,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
                reservedSize: 42,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.brown, width: 2),
          ),
          minX: 0,
          maxX: chartData.length.toDouble() - 1,
          minY:
              chartData.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) *
              0.95,
          maxY:
              chartData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) *
              1.05,
          lineBarsData: [
            LineChartBarData(
              spots: chartData,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF8B4513), // Saddle brown
                  Color(0xFFD2691E), // Chocolate
                  Color(0xFFCD853F), // Peru
                ],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B4513).withOpacity(0.3),
                    const Color(0xFFD2691E).withOpacity(0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.local_gas_station, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            const Text('Oil Tracking', style: TextStyle(color: Colors.white)),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
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
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withOpacity(0.3),
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
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_gas_station,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crude Oil Commodity',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Real-time BZUSD tracking',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Track crude oil prices with real-time data from Financial Modeling Prep API. Monitor energy market trends, analyze performance, and stay updated with oil commodity movements.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Current Oil Price Section
            _buildSectionHeader(theme, 'Current Oil Price', Icons.trending_up),
            const SizedBox(height: 12),

            // Real-time price display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.brown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.brown.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crude Oil (CLUSD)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                      Text(
                        '\$${currentPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
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
                      color: changePercent >= 0 ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Chart Section
            _buildSectionHeader(
              theme,
              '240-Day Oil Price Chart',
              Icons.show_chart,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildOilChart(),
            ),

            CommodityCard(
              commodityType: 'oil',
              isCompact: false,
              margin: EdgeInsets.zero,
            ),

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

            // Oil Facts Section
            _buildSectionHeader(
              theme,
              'About Crude Oil',
              Icons.lightbulb_outline,
            ),
            const SizedBox(height: 12),
            _buildOilFacts(theme),

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
        Icon(icon, color: Colors.black87, size: 20),
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
                'BZUSD',
                Icons.code,
                Colors.black87,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                theme,
                'Market',
                'Energy',
                Icons.bolt,
                Colors.black87,
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
                Colors.black87,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                theme,
                'Unit',
                'Per Barrel',
                Icons.oil_barrel,
                Colors.black87,
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

  Widget _buildOilFacts(ThemeData theme) {
    final facts = [
      {
        'title': 'Energy Source',
        'description':
            'Primary source of energy for transportation and industry worldwide.',
        'icon': Icons.local_gas_station,
      },
      {
        'title': 'Global Commodity',
        'description':
            'Most traded commodity globally, affecting world economies.',
        'icon': Icons.public,
      },
      {
        'title': 'Petrochemicals',
        'description':
            'Used to produce plastics, chemicals, and synthetic materials.',
        'icon': Icons.science,
      },
      {
        'title': 'Strategic Resource',
        'description': 'Critical for national security and economic stability.',
        'icon': Icons.security,
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
            border: Border.all(color: Colors.black.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  fact['icon'] as IconData,
                  color: Colors.black87,
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
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.api, color: Colors.black87, size: 20),
              const SizedBox(width: 8),
              Text(
                'API Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Data Source: Financial Modeling Prep API\nEndpoint: /quote/BZUSD\nUpdate Frequency: Real-time\nSymbol: BZUSD (Brent Crude Oil in USD)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
