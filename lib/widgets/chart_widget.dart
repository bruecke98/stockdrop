import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Chart data point representing a single price at a specific time
class ChartDataPoint {
  final DateTime date;
  final double price;
  final double volume;

  ChartDataPoint({
    required this.date,
    required this.price,
    required this.volume,
  });

  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(
      date: DateTime.parse(json['date']),
      price: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// A comprehensive chart widget for displaying 5-minute intraday stock price data
///
/// Features:
/// - Material 3 design with proper theming
/// - Real-time data from Financial Modeling Prep API
/// - Loading states with CircularProgressIndicator
/// - Error handling with retry functionality
/// - Empty data state handling
/// - Interactive chart with touch support
/// - Price and time axis formatting
/// - Gradient fill under the line
class ChartWidget extends StatefulWidget {
  /// The stock symbol to display chart for (e.g., 'AAPL')
  final String symbol;

  /// Height of the chart widget
  final double height;

  /// Whether to show the volume indicator
  final bool showVolume;

  /// Chart line color (defaults to theme primary color)
  final Color? lineColor;

  const ChartWidget({
    super.key,
    required this.symbol,
    this.height = 300,
    this.showVolume = false,
    this.lineColor,
  });

  @override
  State<ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<ChartWidget> {
  static const String _baseUrl = 'https://financialmodelingprep.com/api/v3';

  List<ChartDataPoint> _chartData = [];
  bool _isLoading = true;
  String? _errorMessage;
  double? _minPrice;
  double? _maxPrice;

  /// Get API key from environment variables
  String get _apiKey {
    final key = dotenv.env['FMP_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('FMP_API_KEY not found in environment variables');
    }
    return key;
  }

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  @override
  void didUpdateWidget(ChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data if symbol changed
    if (oldWidget.symbol != widget.symbol) {
      _loadChartData();
    }
  }

  /// Fetch 5-minute intraday chart data from FMP API
  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('📈 Fetching 5min chart data for ${widget.symbol}');

      final url = Uri.parse(
        '$_baseUrl/historical-chart/5min/${widget.symbol.toUpperCase()}'
        '?apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);

        if (jsonData.isEmpty) {
          setState(() {
            _chartData = [];
            _isLoading = false;
            _errorMessage = 'No chart data available for ${widget.symbol}';
          });
          return;
        }

        // Parse and sort data (FMP returns newest first, we want oldest first)
        final chartData = jsonData
            .map((item) => ChartDataPoint.fromJson(item))
            .toList()
            .reversed
            .toList();

        // Take only the last 100 data points for better performance
        final limitedData = chartData.length > 100
            ? chartData.sublist(chartData.length - 100)
            : chartData;

        // Calculate price range for better scaling
        if (limitedData.isNotEmpty) {
          _minPrice = limitedData
              .map((d) => d.price)
              .reduce((a, b) => a < b ? a : b);
          _maxPrice = limitedData
              .map((d) => d.price)
              .reduce((a, b) => a > b ? a : b);

          // Add 2% padding to min/max for better visualization
          final range = _maxPrice! - _minPrice!;
          _minPrice = _minPrice! - (range * 0.02);
          _maxPrice = _maxPrice! + (range * 0.02);
        }

        setState(() {
          _chartData = limitedData;
          _isLoading = false;
        });

        debugPrint(
          '✅ Loaded ${limitedData.length} chart points for ${widget.symbol}',
        );
      } else if (response.statusCode == 404) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Stock symbol "${widget.symbol}" not found';
        });
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error loading chart data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load chart data: $e';
      });
    }
  }

  /// Build the actual line chart
  Widget _buildChart(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final lineColor = widget.lineColor ?? colorScheme.primary;

    // Convert data points to FlSpot for fl_chart
    final spots = _chartData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.price);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (_maxPrice! - _minPrice!) / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.outline.withOpacity(0.1),
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
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (_chartData.length / 4).ceil().toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _chartData.length) {
                  final time = _chartData[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (_maxPrice! - _minPrice!) / 4,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
            left: BorderSide(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        minX: 0,
        maxX: (_chartData.length - 1).toDouble(),
        minY: _minPrice,
        maxY: _maxPrice,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withOpacity(0.3),
                  lineColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => colorScheme.inverseSurface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < _chartData.length) {
                  final data = _chartData[index];
                  return LineTooltipItem(
                    '\$${spot.y.toStringAsFixed(2)}\n${data.date.hour.toString().padLeft(2, '0')}:${data.date.minute.toString().padLeft(2, '0')}',
                    TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chart header
            Row(
              children: [
                Text(
                  '${widget.symbol.toUpperCase()} - 5min Chart',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                else if (_errorMessage != null)
                  IconButton(
                    onPressed: _loadChartData,
                    icon: Icon(Icons.refresh, color: colorScheme.primary),
                    tooltip: 'Retry',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Chart content
            Expanded(child: _buildChartContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading chart data...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadChartData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_chartData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No chart data available',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chart data may not be available for ${widget.symbol.toUpperCase()}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _buildChart(context);
  }
}

/// A simplified chart widget for smaller spaces
class CompactChartWidget extends StatelessWidget {
  final String symbol;
  final double height;
  final Color? lineColor;

  const CompactChartWidget({
    super.key,
    required this.symbol,
    this.height = 150,
    this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return ChartWidget(
      symbol: symbol,
      height: height,
      lineColor: lineColor,
      showVolume: false,
    );
  }
}
