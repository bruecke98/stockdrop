import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/gold.dart';
import '../services/api_service.dart';

/// A sophisticated chart widget for displaying gold price historical data
///
/// Features:
/// - Interactive line chart with touch support
/// - Multiple time period options (1D, 5D, 1M, 3M, 6M, 1Y, 5Y)
/// - Material 3 design with gradient fills
/// - Loading states and error handling
/// - Responsive design for different screen sizes
/// - Price tooltips on touch
/// - Smooth animations and transitions
class GoldChartWidget extends StatefulWidget {
  /// Height of the chart widget
  final double height;

  /// Whether to show volume data (if available)
  final bool showVolume;

  /// Chart line color (defaults to gold/amber color)
  final Color? lineColor;

  /// Whether to show the time period selector
  final bool showPeriodSelector;

  /// Initial time period
  final String initialPeriod;

  const GoldChartWidget({
    super.key,
    this.height = 300,
    this.showVolume = false,
    this.lineColor,
    this.showPeriodSelector = true,
    this.initialPeriod = '1month',
  });

  @override
  State<GoldChartWidget> createState() => _GoldChartWidgetState();
}

class _GoldChartWidgetState extends State<GoldChartWidget> {
  final ApiService _apiService = ApiService();

  List<GoldHistoricalPoint> _chartData = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedPeriod = '1month';
  double? _minPrice;
  double? _maxPrice;

  // Available time periods
  final Map<String, String> _periods = {
    '1day': '1D',
    '5day': '5D',
    '1month': '1M',
    '3month': '3M',
    '6month': '6M',
    '1year': '1Y',
    '5year': '5Y',
  };

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialPeriod;
    _fetchChartData();
  }

  /// Fetch gold historical data from API
  Future<void> _fetchChartData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.getGoldHistoricalData(
        period: _selectedPeriod,
      );

      if (mounted) {
        setState(() {
          _chartData = data;
          _isLoading = false;
          _calculatePriceRange();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Calculate min and max prices for chart scaling
  void _calculatePriceRange() {
    if (_chartData.isEmpty) return;

    final prices = _chartData.map((point) => point.price).toList();
    _minPrice = prices.reduce((a, b) => a < b ? a : b);
    _maxPrice = prices.reduce((a, b) => a > b ? a : b);

    // Add some padding to the range
    final range = _maxPrice! - _minPrice!;
    _minPrice = _minPrice! - (range * 0.05);
    _maxPrice = _maxPrice! + (range * 0.05);
  }

  /// Handle period selection
  void _onPeriodSelected(String period) {
    if (_selectedPeriod != period) {
      setState(() {
        _selectedPeriod = period;
      });
      _fetchChartData();
    }
  }

  /// Retry fetching data
  void _retry() {
    _fetchChartData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and period selector
            _buildHeader(theme, colorScheme),

            const SizedBox(height: 16),

            // Chart content
            SizedBox(
              height: widget.height,
              child: _buildChart(theme, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the header with title and period selector
  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        // Gold icon and title
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.toll, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'Gold Price Chart',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const Spacer(),

        // Period selector
        if (widget.showPeriodSelector) _buildPeriodSelector(colorScheme),
      ],
    );
  }

  /// Build the period selector buttons
  Widget _buildPeriodSelector(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _periods.entries.map((entry) {
          final isSelected = entry.key == _selectedPeriod;
          return GestureDetector(
            onTap: () => _onPeriodSelected(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Build the main chart content
  Widget _buildChart(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return _buildLoadingState(colorScheme);
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme, colorScheme);
    }

    if (_chartData.isEmpty) {
      return _buildNoDataState(theme, colorScheme);
    }

    return _buildLineChart(colorScheme);
  }

  /// Build loading state
  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Loading gold price data...',
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load chart data',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Build no data state
  Widget _buildNoDataState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timeline_outlined,
            color: colorScheme.onSurface.withOpacity(0.5),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No chart data available',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Build the actual line chart
  Widget _buildLineChart(ColorScheme colorScheme) {
    final lineColor = widget.lineColor ?? Colors.amber;

    // Convert data to FlSpot for fl_chart
    final spots = _chartData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.price);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (_maxPrice! - _minPrice!) / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.outline.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: (_chartData.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _chartData.length) {
                  final date = _chartData[index].date;
                  return Text(
                    '${date.month}/${date.day}',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
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
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < _chartData.length) {
                  final point = _chartData[index];
                  return LineTooltipItem(
                    '${point.date.month}/${point.date.day}/${point.date.year}\n\$${point.price.toStringAsFixed(2)}',
                    TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
          touchCallback:
              (FlTouchEvent event, LineTouchResponse? touchResponse) {
                // Handle touch events if needed
              },
          handleBuiltInTouches: true,
        ),
      ),
    );
  }
}

/// Compact version of the gold chart for smaller displays
class CompactGoldChart extends StatelessWidget {
  final double height;
  final Color? lineColor;

  const CompactGoldChart({super.key, this.height = 150, this.lineColor});

  @override
  Widget build(BuildContext context) {
    return GoldChartWidget(
      height: height,
      showPeriodSelector: false,
      lineColor: lineColor,
      initialPeriod: '5day',
    );
  }
}
