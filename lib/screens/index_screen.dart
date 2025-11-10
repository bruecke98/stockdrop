import 'package:flutter/material.dart';
import '../models/commodity.dart';
import '../services/api_service.dart';
import '../widgets/chart_widget.dart';

/// Generic index screen that can display different market indexes
/// Similar to CommodityScreen but for stock market indexes
class IndexScreen extends StatefulWidget {
  final String indexName;
  final String indexSymbol;
  final Color themeColor;
  final String description;
  final String marketInfo;

  const IndexScreen({
    super.key,
    required this.indexName,
    required this.indexSymbol,
    required this.themeColor,
    required this.description,
    required this.marketInfo,
  });

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  final ApiService _apiService = ApiService();
  Index? _index;
  bool _isLoadingIndex = true;
  bool _showCompactCards = false;

  @override
  void initState() {
    super.initState();
    _fetchIndexData();
  }

  Future<void> _fetchIndexData() async {
    setState(() {
      _isLoadingIndex = true;
    });

    try {
      final index = await _apiService.getIndexPrice(widget.indexSymbol);
      setState(() {
        _index = index;
        _isLoadingIndex = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingIndex = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load ${widget.indexName} data: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _refreshIndexData() async {
    await _fetchIndexData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.indexName} Index Tracking'),
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
      body: RefreshIndicator(
        onRefresh: _refreshIndexData,
        child: SingleChildScrollView(
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
                      '${widget.indexName} Market Overview',
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

              // Index price card section
              _buildIndexCardSection(theme),
              const SizedBox(height: 24),

              // Index chart section
              _buildIndexChartSection(theme),
              const SizedBox(height: 24),

              // Year range visualization
              _buildYearRangeCard(theme),
              const SizedBox(height: 24),

              // Multiple cards section
              _buildMultipleCardsSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the main index card section
  Widget _buildIndexCardSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Current ${widget.indexName} Price',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Main index card
        if (_isLoadingIndex)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          )
        else if (_index != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_index!.icon, size: 32, color: widget.themeColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _index!.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _index!.symbol,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _index!.formattedPrice,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _index!.isGaining
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            Text(
                              _index!.formattedChangePercent,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _index!.isGaining
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem(
                          theme,
                          'Change',
                          _index!.formattedChange,
                          _index!.isGaining,
                        ),
                        _buildStatItem(
                          theme,
                          'Day High',
                          _index!.dayHigh != null
                              ? _index!.dayHigh!.toStringAsFixed(0)
                              : 'N/A',
                          true,
                        ),
                        _buildStatItem(
                          theme,
                          'Day Low',
                          _index!.dayLow != null
                              ? _index!.dayLow!.toStringAsFixed(0)
                              : 'N/A',
                          false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Failed to load ${widget.indexName} data',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build stat item for the index card
  Widget _buildStatItem(
    ThemeData theme,
    String label,
    String value,
    bool isPositive,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: isPositive ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  /// Build the index chart section
  Widget _buildIndexChartSection(ThemeData theme) {
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

        // Main chart - ChartWidget using the index symbol
        ChartWidget(symbol: widget.indexSymbol, height: 300),
      ],
    );
  }

  /// Build year range card with conditional content
  Widget _buildYearRangeCard(ThemeData theme) {
    if (_index != null && _index!.yearHigh != null && _index!.yearLow != null) {
      return _buildYearRangeIndicator(
        context,
        '52-Week Range',
        _index!.price,
        _index!.yearLow!,
        _index!.yearHigh!,
        theme,
      );
    } else if (_isLoadingIndex) {
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
                  _index != null
                      ? 'Year data: High=${_index!.yearHigh}, Low=${_index!.yearLow}'
                      : 'No index data loaded',
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
                  '${minValue.toStringAsFixed(0)}',
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
                    currentValue.toStringAsFixed(0),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${maxValue.toStringAsFixed(0)}',
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

  /// Build multiple cards section for comparison
  Widget _buildMultipleCardsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Market Information',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Info card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
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
        ),

        const SizedBox(height: 12),

        // Action card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
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
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
