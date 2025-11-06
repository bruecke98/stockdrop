import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// Import the new ChartWidget
import '../widgets/chart_widget.dart';
import '../services/api_service.dart';

/// Detail screen for StockDrop app
/// Shows detailed stock information including price, chart, and news
class DetailScreen extends StatefulWidget {
  final String? symbol;

  const DetailScreen({super.key, this.symbol});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  StockDetail? _stockDetail;
  List<StockNews> _news = [];
  PriceTargetConsensus? _priceTarget;
  DcfAnalysis? _dcfAnalysis;
  List<KeyMetrics> _keyMetrics = [];
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isTogglingFavorite = false;
  String? _error;
  String? _stockSymbol;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  void _initializeScreen() {
    // Get symbol from widget parameter or route arguments
    _stockSymbol = widget.symbol;

    if (_stockSymbol == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        _stockSymbol = args?['symbol'] as String?;

        if (_stockSymbol != null) {
          _loadStockData();
        } else {
          setState(() {
            _error = 'No stock symbol provided';
            _isLoading = false;
          });
        }
      });
    } else {
      _loadStockData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_stockSymbol ?? 'Stock Details'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
          ),
          if (_stockDetail != null) _buildFavoriteButton(theme),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildFavoriteButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: _isTogglingFavorite
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onSurface,
                ),
              )
            : Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : theme.colorScheme.onSurface,
              ),
        onPressed: _isTogglingFavorite ? null : _toggleFavorite,
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget(theme);
    }

    if (_stockDetail == null) {
      return _buildNotFoundWidget(theme);
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStockHeader(theme),
            const SizedBox(height: 24),
            _buildPriceChart(theme),
            const SizedBox(height: 24),
            _buildPriceTargetSection(theme),
            const SizedBox(height: 24),
            _buildDcfAnalysisSection(theme),
            const SizedBox(height: 24),
            _buildKeyMetricsSection(theme),
            const SizedBox(height: 24),
            _buildNewsSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStockHeader(ThemeData theme) {
    final stock = _stockDetail!;
    final isPositive = (stock.changesPercentage ?? 0) >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    stock.symbol.length >= 2
                        ? stock.symbol.substring(0, 2).toUpperCase()
                        : stock.symbol.toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock.symbol,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stock.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Price',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '\$${stock.price.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
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
                    color: isPositive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPositive ? '+' : ''}${stock.changesPercentage?.toStringAsFixed(2) ?? '0.00'}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // First row: Day High, Day Low, Volume
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Day High',
                    stock.dayHigh != null
                        ? '\$${stock.dayHigh!.toStringAsFixed(2)}'
                        : 'N/A',
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Day Low',
                    stock.dayLow != null
                        ? '\$${stock.dayLow!.toStringAsFixed(2)}'
                        : 'N/A',
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem('Volume', stock.formattedVolume, theme),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Second row: Market Cap, Exchange, Open
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Market Cap',
                    stock.formattedMarketCap,
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Exchange',
                    stock.exchange ?? 'N/A',
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Open',
                    stock.open != null
                        ? '\$${stock.open!.toStringAsFixed(2)}'
                        : 'N/A',
                    theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Third row: Previous Close, 52W High, 52W Low
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Prev Close',
                    stock.previousClose != null
                        ? '\$${stock.previousClose!.toStringAsFixed(2)}'
                        : 'N/A',
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '52W High',
                    stock.yearHigh != null
                        ? '\$${stock.yearHigh!.toStringAsFixed(2)}'
                        : 'N/A',
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '52W Low',
                    stock.yearLow != null
                        ? '\$${stock.yearLow!.toStringAsFixed(2)}'
                        : 'N/A',
                    theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 52-Week Range Visual Indicator
            if (stock.yearLow != null && stock.yearHigh != null)
              _buildRangeIndicator(
                'Current Price in 52-Week Range',
                stock.price,
                stock.yearLow!,
                stock.yearHigh!,
                theme,
              ),
            const SizedBox(height: 16),
            // Fourth row: 50D Avg, 200D Avg, Day Range
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '50D Avg',
                    stock.formattedPriceAvg50,
                    theme,
                    isPositive: stock.isAbove50DayAvg,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '200D Avg',
                    stock.formattedPriceAvg200,
                    theme,
                    isPositive: stock.isAbove200DayAvg,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Day Range',
                    stock.formattedDayRange,
                    theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Day Range Visual Indicator
            if (stock.dayLow != null && stock.dayHigh != null)
              _buildRangeIndicator(
                'Current Price in Today\'s Range',
                stock.price,
                stock.dayLow!,
                stock.dayHigh!,
                theme,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    ThemeData theme, {
    bool? isPositive,
  }) {
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
        Row(
          children: [
            if (isPositive != null) ...[
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: 14,
                color: isPositive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isPositive != null
                      ? (isPositive ? Colors.green : Colors.red)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRangeIndicator(
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          const SizedBox(height: 8),

          // Position percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                position < 0.33
                    ? Icons.trending_down
                    : position < 0.67
                    ? Icons.trending_flat
                    : Icons.trending_up,
                size: 16,
                color: indicatorColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${(position * 100).toStringAsFixed(1)}% of range',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: indicatorColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChart(ThemeData theme) {
    if (_stockSymbol == null) {
      return Card(
        child: Container(
          height: 350,
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No stock symbol available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    // Determine chart color based on stock performance
    Color? chartColor;
    if (_stockDetail != null) {
      final changePercent = _stockDetail!.changesPercentage ?? 0;
      chartColor = changePercent >= 0
          ? theme.colorScheme.primary
          : theme.colorScheme.error;
    }

    return ChartWidget(
      symbol: _stockSymbol!,
      height: 350,
      lineColor: chartColor,
    );
  }

  Widget _buildNewsSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Latest News',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_news.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_news.length} articles',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_news.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No recent news available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._news.map((article) => _buildNewsItem(article, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsItem(StockNews article, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // News source and date
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  article.site.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.access_time,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(article.publishedDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            article.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Summary
          if (article.summary.isNotEmpty)
            Text(
              article.summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),

          const SizedBox(height: 12),

          // Read more indicator
          Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Read full article',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  Widget _buildPriceTargetSection(ThemeData theme) {
    if (_priceTarget == null) {
      return const SizedBox.shrink();
    }

    final currentPrice = _stockDetail?.price ?? 0.0;
    final target = _priceTarget!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Analyst Price Targets',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Price target visual indicator
          if (target.targetLow != null && target.targetHigh != null) ...[
            _buildTargetRangeIndicator(theme, currentPrice, target),
            const SizedBox(height: 20),
          ],

          // Target statistics
          Row(
            children: [
              Expanded(
                child: _buildTargetStatItem(
                  'Consensus Target',
                  '\$${target.targetConsensus?.toStringAsFixed(2) ?? 'N/A'}',
                  target.getPotentialReturn(currentPrice),
                  theme,
                ),
              ),
              Expanded(
                child: _buildTargetStatItem(
                  'Median Target',
                  '\$${target.targetMedian?.toStringAsFixed(2) ?? 'N/A'}',
                  target.targetMedian != null
                      ? _calculatePotentialReturn(
                          currentPrice,
                          target.targetMedian!,
                        )
                      : null,
                  theme,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTargetStatItem(
                  'Low Target',
                  '\$${target.targetLow?.toStringAsFixed(2) ?? 'N/A'}',
                  null,
                  theme,
                ),
              ),
              Expanded(
                child: _buildTargetStatItem(
                  'High Target',
                  '\$${target.targetHigh?.toStringAsFixed(2) ?? 'N/A'}',
                  null,
                  theme,
                ),
              ),
            ],
          ),

          if (target.numberOfAnalysts != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${target.numberOfAnalysts} analyst${target.numberOfAnalysts == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Bull/Bear sentiment
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: target.isBullish(currentPrice)
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  target.isBullish(currentPrice)
                      ? Icons.trending_up
                      : Icons.trending_down,
                  size: 16,
                  color: target.isBullish(currentPrice)
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  target.isBullish(currentPrice) ? 'Bullish' : 'Bearish',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: target.isBullish(currentPrice)
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _calculatePotentialReturn(double currentPrice, double targetPrice) {
    final potential = ((targetPrice - currentPrice) / currentPrice) * 100;
    final sign = potential >= 0 ? '+' : '';
    return '$sign${potential.toStringAsFixed(1)}%';
  }

  Widget _buildTargetRangeIndicator(
    ThemeData theme,
    double currentPrice,
    PriceTargetConsensus target,
  ) {
    final low = target.targetLow!;
    final high = target.targetHigh!;
    final consensus = target.targetConsensus ?? ((low + high) / 2);

    // Calculate position percentages
    final range = high - low;
    final currentPosition = ((currentPrice - low) / range).clamp(0.0, 1.0);
    final consensusPosition = ((consensus - low) / range).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Current: \$${currentPrice.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Range: \$${low.toStringAsFixed(2)} - \$${high.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Container(
          height: 32,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: Stack(
            children: [
              // Background gradient
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.3),
                      Colors.orange.withOpacity(0.3),
                      Colors.green.withOpacity(0.3),
                    ],
                  ),
                ),
              ),

              // Consensus target marker
              Positioned(
                left:
                    consensusPosition *
                    (MediaQuery.of(context).size.width -
                        72), // Account for padding
                top: 4,
                child: Container(
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),

              // Current price indicator
              Positioned(
                left:
                    currentPosition * (MediaQuery.of(context).size.width - 72) -
                    8, // Account for padding and center the dot
                top: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Low',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Consensus',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'High',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTargetStatItem(
    String label,
    String value,
    String? percentage,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (percentage != null) ...[
          const SizedBox(height: 2),
          Text(
            percentage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: percentage.startsWith('+') ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDcfAnalysisSection(ThemeData theme) {
    if (_dcfAnalysis == null) {
      return const SizedBox.shrink();
    }

    final dcf = _dcfAnalysis!;
    final currentPrice = _stockDetail?.price ?? dcf.price ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calculate_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'DCF Valuation Analysis',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fair Value vs Current Price
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dcf.isUndervalued
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DCF Fair Value',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dcf.formattedFairValue,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: dcf.isUndervalued ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Price',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${currentPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      dcf.isUndervalued
                          ? Icons.trending_up
                          : Icons.trending_down,
                      color: dcf.isUndervalued ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    Text(
                      dcf.getValuationGap(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: dcf.isUndervalued ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Key DCF Metrics
          Row(
            children: [
              Expanded(
                child: _buildDcfMetricItem(
                  'WACC',
                  dcf.formattedWacc,
                  Icons.percent,
                  theme,
                ),
              ),
              Expanded(
                child: _buildDcfMetricItem(
                  'Enterprise Value',
                  dcf.formattedEnterpriseValue,
                  Icons.business,
                  theme,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildDcfMetricItem(
                  'Terminal Growth',
                  dcf.longTermGrowthRate != null
                      ? '${dcf.longTermGrowthRate!.toStringAsFixed(1)}%'
                      : 'N/A',
                  Icons.trending_up,
                  theme,
                ),
              ),
              Expanded(
                child: _buildDcfMetricItem(
                  'Beta',
                  dcf.beta?.toStringAsFixed(2) ?? 'N/A',
                  Icons.show_chart,
                  theme,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Investment Recommendation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getRecommendationColor(
                dcf.recommendation,
              ).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getRecommendationColor(
                  dcf.recommendation,
                ).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getRecommendationIcon(dcf.recommendation),
                      color: _getRecommendationColor(dcf.recommendation),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DCF Recommendation: ${dcf.recommendation}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getRecommendationColor(dcf.recommendation),
                      ),
                    ),
                  ],
                ),
                if (dcf.recommendation != 'N/A') ...[
                  const SizedBox(height: 8),
                  Text(
                    _getRecommendationDescription(dcf.recommendation),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDcfMetricItem(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRecommendationColor(String recommendation) {
    switch (recommendation) {
      case 'Strong Buy':
      case 'Buy':
        return Colors.green;
      case 'Hold':
        return Colors.orange;
      case 'Sell':
      case 'Strong Sell':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getRecommendationIcon(String recommendation) {
    switch (recommendation) {
      case 'Strong Buy':
        return Icons.keyboard_double_arrow_up;
      case 'Buy':
        return Icons.arrow_upward;
      case 'Hold':
        return Icons.horizontal_rule;
      case 'Sell':
        return Icons.arrow_downward;
      case 'Strong Sell':
        return Icons.keyboard_double_arrow_down;
      default:
        return Icons.help_outline;
    }
  }

  String _getRecommendationDescription(String recommendation) {
    switch (recommendation) {
      case 'Strong Buy':
        return 'Significantly undervalued - Strong upside potential (>20%)';
      case 'Buy':
        return 'Undervalued - Good upside potential (10-20%)';
      case 'Hold':
        return 'Fairly valued - Limited upside/downside (-10% to +10%)';
      case 'Sell':
        return 'Overvalued - Downside risk (-10% to -20%)';
      case 'Strong Sell':
        return 'Significantly overvalued - High downside risk (>20%)';
      default:
        return 'Analysis not available';
    }
  }

  Widget _buildKeyMetricsSection(ThemeData theme) {
    if (_keyMetrics.isEmpty) {
      return const SizedBox.shrink();
    }

    final latestMetrics = _keyMetrics.first;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assessment_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Key Financial Metrics',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'FY ${latestMetrics.fiscalYear ?? 'N/A'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Financial Health Score
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getHealthScoreColor(
                latestMetrics.financialHealthScore,
              ).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getHealthScoreColor(
                  latestMetrics.financialHealthScore,
                ).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial Health Score',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latestMetrics.financialHealthDescription,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getHealthScoreColor(
                      latestMetrics.financialHealthScore,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${latestMetrics.financialHealthScore}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Valuation Metrics
          _buildMetricsCategory('Valuation Metrics', [
            _buildMetricRow(
              'Market Cap',
              latestMetrics.formattedMarketCap,
              theme,
            ),
            _buildMetricRow(
              'Enterprise Value',
              latestMetrics.formattedEnterpriseValue,
              theme,
            ),
            _buildMetricRow(
              'EV/Sales',
              latestMetrics.formatRatio(latestMetrics.evToSales),
              theme,
            ),
            _buildMetricRow(
              'EV/EBITDA',
              latestMetrics.formatRatio(latestMetrics.evToEBITDA),
              theme,
            ),
            _buildMetricRow(
              'EV/FCF',
              latestMetrics.formatRatio(latestMetrics.evToFreeCashFlow),
              theme,
            ),
          ], theme),

          const SizedBox(height: 16),

          // Profitability Metrics
          _buildMetricsCategory('Profitability Metrics', [
            _buildMetricRow(
              'Return on Equity (ROE)',
              latestMetrics.formatPercentage(latestMetrics.returnOnEquity),
              theme,
            ),
            _buildMetricRow(
              'Return on Assets (ROA)',
              latestMetrics.formatPercentage(latestMetrics.returnOnAssets),
              theme,
            ),
            _buildMetricRow(
              'Return on Invested Capital',
              latestMetrics.formatPercentage(
                latestMetrics.returnOnInvestedCapital,
              ),
              theme,
            ),
            _buildMetricRow(
              'Operating ROA',
              latestMetrics.formatPercentage(
                latestMetrics.operatingReturnOnAssets,
              ),
              theme,
            ),
            _buildMetricRow(
              'Earnings Yield',
              latestMetrics.formatPercentage(latestMetrics.earningsYield),
              theme,
            ),
          ], theme),

          const SizedBox(height: 16),

          // Liquidity & Efficiency Metrics
          _buildMetricsCategory('Liquidity & Efficiency', [
            _buildMetricRow(
              'Current Ratio',
              latestMetrics.formatRatio(latestMetrics.currentRatio),
              theme,
            ),
            _buildMetricRow(
              'Working Capital',
              latestMetrics.formattedWorkingCapital,
              theme,
            ),
            _buildMetricRow(
              'Cash Conversion Cycle',
              latestMetrics.formatDays(latestMetrics.cashConversionCycle),
              theme,
            ),
            _buildMetricRow(
              'Days Sales Outstanding',
              latestMetrics.formatDays(latestMetrics.daysOfSalesOutstanding),
              theme,
            ),
            _buildMetricRow(
              'Income Quality',
              latestMetrics.formatRatio(latestMetrics.incomeQuality),
              theme,
            ),
          ], theme),

          const SizedBox(height: 16),

          // Cash Flow Metrics
          _buildMetricsCategory('Cash Flow Metrics', [
            _buildMetricRow(
              'Free Cash Flow Yield',
              latestMetrics.formatPercentage(latestMetrics.freeCashFlowYield),
              theme,
            ),
            _buildMetricRow(
              'CapEx to Operating CF',
              latestMetrics.formatPercentage(
                latestMetrics.capexToOperatingCashFlow,
              ),
              theme,
            ),
            _buildMetricRow(
              'CapEx to Revenue',
              latestMetrics.formatPercentage(latestMetrics.capexToRevenue),
              theme,
            ),
            _buildMetricRow(
              'R&D to Revenue',
              latestMetrics.formatPercentage(
                latestMetrics.researchAndDevelopementToRevenue,
              ),
              theme,
            ),
          ], theme),

          if (_keyMetrics.length > 1) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_keyMetrics.length} years of historical data available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsCategory(
    String title,
    List<Widget> metrics,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: metrics),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 65) return Colors.lightGreen;
    if (score >= 50) return Colors.orange;
    if (score >= 35) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildErrorWidget(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Stock',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadStockData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundWidget(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Stock Not Found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The stock symbol "${_stockSymbol ?? 'N/A'}" could not be found.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadStockData() async {
    if (_stockSymbol == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _fetchStockQuote(),
        _fetchNews(),
        _checkFavoriteStatus(),
        _fetchPriceTarget(),
        _fetchDcfAnalysis(),
        _fetchKeyMetrics(),
      ]);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStockQuote() async {
    final apiKey = dotenv.env['FMP_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('FMP API key not found');
    }

    final url =
        'https://financialmodelingprep.com/api/v3/quote/$_stockSymbol?apikey=$apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        _stockDetail = StockDetail.fromJson(data.first);
      } else {
        throw Exception('Stock not found');
      }
    } else {
      throw Exception('Failed to fetch stock quote');
    }
  }

  Future<void> _fetchNews() async {
    final apiKey = dotenv.env['FMP_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return;

    try {
      final url =
          'https://financialmodelingprep.com/api/v3/stock_news?tickers=$_stockSymbol&limit=10&apikey=$apiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _news = data.map((item) => StockNews.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching news: $e');
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _stockSymbol == null) return;

    try {
      final response = await Supabase.instance.client
          .from('st_favorites')
          .select('id')
          .eq('user_id', user.id)
          .eq('symbol', _stockSymbol!)
          .maybeSingle();

      _isFavorite = response != null;
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
    }
  }

  Future<void> _fetchPriceTarget() async {
    if (_stockSymbol == null) return;

    try {
      final apiService = ApiService();
      _priceTarget = await apiService.getPriceTargetConsensus(_stockSymbol!);
    } catch (e) {
      debugPrint('Error fetching price target: $e');
    }
  }

  Future<void> _fetchDcfAnalysis() async {
    if (_stockSymbol == null) return;

    try {
      final apiService = ApiService();
      _dcfAnalysis = await apiService.getCustomDcfAnalysis(_stockSymbol!);
    } catch (e) {
      debugPrint('Error fetching DCF analysis: $e');
    }
  }

  Future<void> _fetchKeyMetrics() async {
    if (_stockSymbol == null) return;

    try {
      final apiService = ApiService();
      _keyMetrics = await apiService.getKeyMetrics(_stockSymbol!, limit: 5);
    } catch (e) {
      debugPrint('Error fetching key metrics: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _stockSymbol == null) return;

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      if (_isFavorite) {
        await Supabase.instance.client
            .from('st_favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('symbol', _stockSymbol!);

        setState(() {
          _isFavorite = false;
        });

        _showMessage('Removed from favorites');
      } else {
        await Supabase.instance.client.from('st_favorites').insert({
          'user_id': user.id,
          'symbol': _stockSymbol!,
        });

        setState(() {
          _isFavorite = true;
        });

        _showMessage('Added to favorites');
      }
    } catch (e) {
      _showMessage('Failed to update favorites', isError: true);
    } finally {
      setState(() {
        _isTogglingFavorite = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadStockData();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// Data Models
class StockDetail {
  final String symbol;
  final String name;
  final double price;
  final double? changesPercentage;
  final double? change;
  final double? dayHigh;
  final double? dayLow;
  final double? yearHigh;
  final double? yearLow;
  final double? priceAvg50;
  final double? priceAvg200;
  final String? exchange;
  final double? open;
  final double? previousClose;
  final int? volume;
  final double? marketCap;
  final int? timestamp;

  StockDetail({
    required this.symbol,
    required this.name,
    required this.price,
    this.changesPercentage,
    this.change,
    this.dayHigh,
    this.dayLow,
    this.yearHigh,
    this.yearLow,
    this.priceAvg50,
    this.priceAvg200,
    this.exchange,
    this.open,
    this.previousClose,
    this.volume,
    this.marketCap,
    this.timestamp,
  });

  factory StockDetail.fromJson(Map<String, dynamic> json) {
    return StockDetail(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      changesPercentage:
          (json['changesPercentage'] as num?)?.toDouble() ??
          (json['changePercentage'] as num?)?.toDouble(),
      change: (json['change'] as num?)?.toDouble(),
      dayHigh: (json['dayHigh'] as num?)?.toDouble(),
      dayLow: (json['dayLow'] as num?)?.toDouble(),
      yearHigh: (json['yearHigh'] as num?)?.toDouble(),
      yearLow: (json['yearLow'] as num?)?.toDouble(),
      priceAvg50: (json['priceAvg50'] as num?)?.toDouble(),
      priceAvg200: (json['priceAvg200'] as num?)?.toDouble(),
      exchange: json['exchange']?.toString(),
      open: (json['open'] as num?)?.toDouble(),
      previousClose: (json['previousClose'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toInt(),
      marketCap: (json['marketCap'] as num?)?.toDouble(),
      timestamp: (json['timestamp'] as num?)?.toInt(),
    );
  }

  // Utility methods
  String get formattedVolume {
    if (volume == null) return 'N/A';

    if (volume! >= 1e9) {
      return '${(volume! / 1e9).toStringAsFixed(2)}B';
    } else if (volume! >= 1e6) {
      return '${(volume! / 1e6).toStringAsFixed(2)}M';
    } else if (volume! >= 1e3) {
      return '${(volume! / 1e3).toStringAsFixed(2)}K';
    } else {
      return volume!.toString();
    }
  }

  String get formattedMarketCap {
    if (marketCap == null) return 'N/A';

    if (marketCap! >= 1e12) {
      return '\$${(marketCap! / 1e12).toStringAsFixed(2)}T';
    } else if (marketCap! >= 1e9) {
      return '\$${(marketCap! / 1e9).toStringAsFixed(2)}B';
    } else if (marketCap! >= 1e6) {
      return '\$${(marketCap! / 1e6).toStringAsFixed(2)}M';
    } else {
      return '\$${marketCap!.toStringAsFixed(0)}';
    }
  }

  String get formattedPriceAvg50 {
    if (priceAvg50 == null) return 'N/A';
    return '\$${priceAvg50!.toStringAsFixed(2)}';
  }

  String get formattedPriceAvg200 {
    if (priceAvg200 == null) return 'N/A';
    return '\$${priceAvg200!.toStringAsFixed(2)}';
  }

  String get formattedDayRange {
    if (dayLow == null || dayHigh == null) return 'N/A';
    return '\$${dayLow!.toStringAsFixed(2)} - \$${dayHigh!.toStringAsFixed(2)}';
  }

  bool get isAbove50DayAvg {
    if (priceAvg50 == null) return false;
    return price > priceAvg50!;
  }

  bool get isAbove200DayAvg {
    if (priceAvg200 == null) return false;
    return price > priceAvg200!;
  }
}

class StockNews {
  final String title;
  final String summary;
  final String publishedDate;
  final String site;

  StockNews({
    required this.title,
    required this.summary,
    required this.publishedDate,
    required this.site,
  });

  factory StockNews.fromJson(Map<String, dynamic> json) {
    return StockNews(
      title: json['title']?.toString() ?? '',
      summary: json['text']?.toString() ?? '',
      publishedDate: json['publishedDate']?.toString() ?? '',
      site: json['site']?.toString() ?? '',
    );
  }
}
