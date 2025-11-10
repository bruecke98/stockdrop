import 'package:flutter/material.dart';
import '../models/commodity.dart';
import '../services/api_service.dart';
import '../widgets/commodity_card.dart';
import '../widgets/chart_widget.dart';

/// Generic commodity screen that can display different commodities
/// Supports gold, oil, and silver with configurable parameters
class CommodityScreen extends StatefulWidget {
  final String commodityName;
  final String commoditySymbol;
  final Color themeColor;
  final String description;
  final String marketInfo;

  const CommodityScreen({
    super.key,
    required this.commodityName,
    required this.commoditySymbol,
    required this.themeColor,
    required this.description,
    required this.marketInfo,
  });

  @override
  State<CommodityScreen> createState() => _CommodityScreenState();
}

class _CommodityScreenState extends State<CommodityScreen> {
  bool _showCompactCards = false;
  final ApiService _apiService = ApiService();
  Commodity? _commodity;
  bool _isLoadingCommodity = true;

  @override
  void initState() {
    super.initState();
    _fetchCommodityData();
  }

  Future<void> _fetchCommodityData() async {
    try {
      setState(() {
        _isLoadingCommodity = true;
      });

      final commodity = await _apiService.getCommodityPrice(
        widget.commodityName.toLowerCase(),
      );

      if (mounted) {
        setState(() {
          _commodity = commodity;
          _isLoadingCommodity = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching commodity data: $e');
      if (mounted) {
        setState(() {
          _isLoadingCommodity = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.commodityName} Commodity Tracking'),
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
                    '${widget.commodityName} Market Overview',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Commodity price card section
            _buildCommodityCardSection(theme),
            const SizedBox(height: 24),

            // Commodity chart section
            _buildCommodityChartSection(theme),

            const SizedBox(height: 24),

            // Year range visualization
            _buildYearRangeCard(theme),

            const SizedBox(height: 24),

            // Multiple cards section
            // _buildMultipleCardsSection(theme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Build the main commodity card section
  Widget _buildCommodityCardSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Current ${widget.commodityName} Price',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Main commodity card (generic)
        CommodityCard(
          commodityType: widget.commodityName.toLowerCase(),
          isCompact: _showCompactCards,
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ],
    );
  }

  /// Build the commodity chart section
  Widget _buildCommodityChartSection(ThemeData theme) {
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

        // Main chart - generic ChartWidget using the commodity symbol
        ChartWidget(
          symbol: widget.commoditySymbol,
          height: 300,
          showVolume: false,
          initialPeriod: '1M',
          lineColor: widget.themeColor,
        ),
      ],
    );
  }

  /// Build multiple cards section for comparison
  /*Widget _buildMultipleCardsSection(ThemeData theme) {
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

        // Vertical stacked overview cards (one per row)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Year Range Visualization
              // _buildYearRangeCard(theme),

              const SizedBox(height: 12),

              // Info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 32,
                            color: widget.themeColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Market Info',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.marketInfo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

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
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 32,
                          color: widget.themeColor,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                          ],
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
  }*/
  Widget _buildYearRangeCard(ThemeData theme) {
    if (_commodity != null &&
        _commodity!.yearHigh != null &&
        _commodity!.yearLow != null) {
      return _buildYearRangeIndicator(
        context,
        '52-Week Range',
        _commodity!.price,
        _commodity!.yearLow!,
        _commodity!.yearHigh!,
        theme,
      );
    } else if (_isLoadingCommodity) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                '52-Week Range',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    } else {
      // Show debug info when data is not available
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                '52-Week Range',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _commodity != null
                      ? 'Year data: High=${_commodity!.yearHigh}, Low=${_commodity!.yearLow}'
                      : 'No commodity data loaded',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildYearRangeIndicator(
    BuildContext context,
    String title,
    double currentValue,
    double minValue,
    double maxValue,
    ThemeData theme,
  ) {
    // Calculate position as percentage (0.0 to 1.0)
    double position = 0.5; // Default to middle if calculation fails
    if (maxValue > minValue) {
      position = ((currentValue - minValue) / (maxValue - minValue)).clamp(
        0.0,
        1.0,
      );
    }

    // Determine color based on position
    Color indicatorColor;
    if (position < 0.33) {
      indicatorColor = Colors.red;
    } else if (position < 0.67) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = Colors.green;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // Range labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${minValue.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\$${currentValue.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '\$${maxValue.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [Colors.red, Colors.orange, Colors.green],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Current position indicator
                  Positioned(
                    left:
                        (position * (MediaQuery.of(context).size.width - 64)) -
                        6, // Account for padding
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: indicatorColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
