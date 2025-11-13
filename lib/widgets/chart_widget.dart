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

/// A comprehensive chart widget for displaying stock price data with selectable time periods
///
/// Features:
/// - Material 3 design with proper theming
/// - Real-time data from Financial Modeling Prep API
/// - Multiple time periods: 1D, 5D, 1M, 3M, 6M, 1Y
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

  /// Initial time period for the chart
  final String initialPeriod;

  const ChartWidget({
    super.key,
    required this.symbol,
    this.height = 300,
    this.showVolume = false,
    this.lineColor,
    this.initialPeriod = '1D',
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
  double? _priceAvg50;
  late String _selectedPeriod;

  /// Available time periods for the chart
  static const List<String> _availablePeriods = [
    '1D',
    '5D',
    '1M',
    '3M',
    '6M',
    '1Y',
    '5Y',
  ];

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
    _selectedPeriod = widget.initialPeriod;
    _loadChartData();
  }

  @override
  void didUpdateWidget(ChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data if symbol changed
    if (oldWidget.symbol != widget.symbol) {
      _loadChartData();
    }
    // Update period if it changed
    if (oldWidget.initialPeriod != widget.initialPeriod) {
      _selectedPeriod = widget.initialPeriod;
      _loadChartData();
    }
  }

  /// Fetch chart data from FMP API based on selected period
  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint(
        '📈 Fetching ${_selectedPeriod} chart data for ${widget.symbol}',
      );

      final url = _getChartUrl();
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        // Handle different response formats based on API endpoint
        List<dynamic> jsonData;
        if (responseData is List) {
          // Direct list response (historical-chart endpoints)
          jsonData = responseData;
        } else if (responseData is Map &&
            responseData.containsKey('historical')) {
          // Map with historical key (historical-price-full endpoint)
          jsonData = responseData['historical'] as List<dynamic>;
        } else {
          throw Exception('Unexpected API response format');
        }

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

        // Limit data points based on period for better performance
        final maxPoints = _getMaxDataPoints();
        final limitedData = chartData.length > maxPoints
            ? chartData.sublist(chartData.length - maxPoints)
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
          '✅ Loaded ${limitedData.length} data points for ${widget.symbol}',
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

  /// Get the appropriate API URL based on selected period
  Uri _getChartUrl() {
    final symbol = widget.symbol.toUpperCase();

    switch (_selectedPeriod) {
      case '1D':
        return Uri.parse(
          '$_baseUrl/historical-chart/5min/$symbol?apikey=$_apiKey',
        );
      case '5D':
        return Uri.parse(
          '$_baseUrl/historical-chart/1hour/$symbol?apikey=$_apiKey',
        );
      case '1M':
        return Uri.parse(
          '$_baseUrl/historical-price-full/$symbol?apikey=$_apiKey',
        );
      case '3M':
        return Uri.parse(
          '$_baseUrl/historical-price-full/$symbol?apikey=$_apiKey',
        );
      case '6M':
        return Uri.parse(
          '$_baseUrl/historical-price-full/$symbol?apikey=$_apiKey',
        );
      case '1Y':
        return Uri.parse(
          '$_baseUrl/historical-price-full/$symbol?apikey=$_apiKey',
        );
      case '5Y':
        return Uri.parse(
          '$_baseUrl/historical-price-full/$symbol?apikey=$_apiKey',
        );
      default:
        return Uri.parse(
          '$_baseUrl/historical-chart/5min/$symbol?apikey=$_apiKey',
        );
    }
  }

  /// Change the selected time period and reload data
  void _changePeriod(String period) {
    if (_selectedPeriod != period) {
      setState(() {
        _selectedPeriod = period;
      });
      _loadChartData();
    }
  }

  /// Get maximum data points to display based on period
  int _getMaxDataPoints() {
    switch (_selectedPeriod) {
      case '1D':
        return 100; // 5-minute intervals for 1 day
      case '5D':
        return 120; // Hourly intervals for 5 days
      case '1M':
        return 30; // Daily for 1 month
      case '3M':
        return 90; // Daily for 3 months
      case '6M':
        return 180; // Daily for 6 months
      case '1Y':
        return 365; // Daily for 1 year
      case '5Y':
        return 1825; // Daily for 5 years (365 * 5)
      default:
        return 100;
    }
  }

  /// Calculate 50-day moving average from chart data
  List<FlSpot> _calculateMovingAverage50() {
    if (_chartData.isEmpty) return [];

    final movingAverageSpots = <FlSpot>[];

    for (int i = 0; i < _chartData.length; i++) {
      final startIndex = (i - 49).clamp(0, i);
      final count = i - startIndex + 1;
      double sum = 0;
      for (int j = startIndex; j <= i; j++) {
        sum += _chartData[j].price;
      }
      final average = sum / count;
      movingAverageSpots.add(FlSpot(i.toDouble(), average));
    }

    return movingAverageSpots;
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

    // Calculate 50-day moving average
    final movingAverageSpots = _calculateMovingAverage50();

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

                  // Show time format for 1D, date format for longer periods
                  String formattedTime;
                  if (_selectedPeriod == '1D') {
                    formattedTime =
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                  } else {
                    formattedTime =
                        '${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      formattedTime,
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
          // 50-day moving average line
          if (movingAverageSpots.isNotEmpty)
            LineChartBarData(
              spots: movingAverageSpots,
              isCurved: true,
              color: Colors.orange,
              barWidth: 1.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
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
                  final isMovingAverage =
                      spot.barIndex == 1; // Index 1 is the moving average line

                  if (isMovingAverage) {
                    return LineTooltipItem(
                      '50MA: \$${spot.y.toStringAsFixed(2)}',
                      TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  } else {
                    // Format date/time based on selected period
                    String dateTimeString;
                    if (_selectedPeriod == '1D') {
                      dateTimeString =
                          '${data.date.hour.toString().padLeft(2, '0')}:${data.date.minute.toString().padLeft(2, '0')}';
                    } else {
                      dateTimeString =
                          '${data.date.month.toString().padLeft(2, '0')}/${data.date.day.toString().padLeft(2, '0')}/${data.date.year.toString().substring(2)}';
                    }

                    return LineTooltipItem(
                      '\$${spot.y.toStringAsFixed(2)}\n$dateTimeString',
                      TextStyle(
                        color: colorScheme.onInverseSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }
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
            // Chart header with period selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${widget.symbol.toUpperCase()} - ${_selectedPeriod} Chart',
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
                const SizedBox(height: 4),
                // Legend for chart lines
                Row(
                  children: [
                    // Price line indicator
                    Container(
                      width: 12,
                      height: 2,
                      color: widget.lineColor ?? theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Price',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 50-day MA indicator (only show if data is available)
                    if (_calculateMovingAverage50().isNotEmpty) ...[
                      Container(width: 12, height: 2, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '50-Day MA',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Period selector buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _availablePeriods.map((period) {
                      final isSelected = period == _selectedPeriod;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton(
                          onPressed: () => _changePeriod(period),
                          style: TextButton.styleFrom(
                            backgroundColor: isSelected
                                ? colorScheme.primaryContainer
                                : Colors.transparent,
                            foregroundColor: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            period,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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
