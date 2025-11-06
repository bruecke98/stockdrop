import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// Import the new ChartWidget
import '../widgets/chart_widget.dart';
import '../services/api_service.dart';
import '../models/stock.dart';

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
  CompanyProfile? _companyProfile;
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isTogglingFavorite = false;
  bool _isDescriptionExpanded = false;
  bool _isDcfExtendedView = false;
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
            _buildCompanyProfileSection(theme),
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      'https://images.financialmodelingprep.com/symbol/${stock.symbol}.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          child: Icon(
                            Icons.business,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        );
                      },
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
            // Day Range Visual Indicator
            if (stock.dayLow != null && stock.dayHigh != null)
              _buildRangeIndicator(
                'Current Price in Today\'s Range',
                stock.price,
                stock.dayLow!,
                stock.dayHigh!,
                theme,
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
            // Market Cap with categorization
            if (stock.marketCap != null)
              _buildMarketCapDisplay(stock.marketCap!, theme),
          ],
        ),
      ),
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

  Widget _buildMarketCapDisplay(double marketCap, ThemeData theme) {
    // Determine market cap category
    String category;
    Color categoryColor;

    if (marketCap >= 200000000000) {
      // $200B+
      category = 'Mega Cap';
      categoryColor = Colors.purple;
    } else if (marketCap >= 10000000000) {
      // $10B+
      category = 'Large Cap';
      categoryColor = Colors.blue;
    } else if (marketCap >= 2000000000) {
      // $2B+
      category = 'Mid Cap';
      categoryColor = Colors.green;
    } else if (marketCap >= 300000000) {
      // $300M+
      category = 'Small Cap';
      categoryColor = Colors.orange;
    } else if (marketCap >= 50000000) {
      // $50M+
      category = 'Micro Cap';
      categoryColor = Colors.red;
    } else {
      category = 'Nano Cap';
      categoryColor = Colors.grey;
    }

    // Format market cap value
    String formattedValue;
    if (marketCap >= 1000000000000) {
      // $1T+
      formattedValue = '\$${(marketCap / 1000000000000).toStringAsFixed(2)}T';
    } else if (marketCap >= 1000000000) {
      // $1B+
      formattedValue = '\$${(marketCap / 1000000000).toStringAsFixed(2)}B';
    } else if (marketCap >= 1000000) {
      // $1M+
      formattedValue = '\$${(marketCap / 1000000).toStringAsFixed(2)}M';
    } else {
      formattedValue = '\$${marketCap.toStringAsFixed(0)}';
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
            'Market Capitalization',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Market cap value and category
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedValue,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: categoryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  category,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: categoryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyProfileSection(ThemeData theme) {
    if (_companyProfile == null) {
      return const SizedBox.shrink();
    }

    final profile = _companyProfile!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.business,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Company Profile',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Industry and Sector
            Row(
              children: [
                if (profile.industry != null) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Industry',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.industry!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
                if (profile.sector != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sector',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.sector!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // CEO
            if (profile.ceo != null) ...[
              Text(
                'CEO',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(profile.ceo!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
            ],

            // Full Time Employees
            if (profile.fullTimeEmployees != null) ...[
              Text(
                'Full Time Employees',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.fullTimeEmployees!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],

            // Description
            if (profile.description != null &&
                profile.description!.isNotEmpty) ...[
              Text(
                'Description',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isDescriptionExpanded
                        ? profile.description!
                        : _getFirstSentence(profile.description!),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  if (!_isDescriptionExpanded &&
                      _hasMoreThanOneSentence(profile.description!)) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isDescriptionExpanded = true;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Read more',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else if (_isDescriptionExpanded) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isDescriptionExpanded = false;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Read less',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Additional details
            Row(
              children: [
                if (profile.country != null) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Country',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.country!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
                if (profile.exchange != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exchange',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.exchange!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            // Website
            if (profile.website != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.language,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Website',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                profile.website!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ],
        ),
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
          const SizedBox(height: 12),

          // Toggle Button below header
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _isDcfExtendedView = !_isDcfExtendedView;
                });
              },
              icon: Icon(
                _isDcfExtendedView ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              label: Text(
                _isDcfExtendedView ? 'Simple' : 'Detailed',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isDcfExtendedView) ...[
            // Extended DCF View with detailed visualizations
            _buildDcfCalculationFlow(theme, dcf),
            const SizedBox(height: 24),
            _buildDcfValuationComparison(theme, dcf, currentPrice),
            const SizedBox(height: 24),
            _buildDcfAssumptionsSection(theme, dcf),
            const SizedBox(height: 20),
          ] else ...[
            // Simple DCF View
            _buildSimpleDcfView(theme, dcf, currentPrice),
            const SizedBox(height: 20),
          ],

          // Investment Recommendation (always shown)
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
                // "DCF Recommendation" label
                Text(
                  'DCF Recommendation',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                // Actual recommendation
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
                      dcf.recommendation,
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

  Widget _buildSimpleDcfView(
    ThemeData theme,
    DcfAnalysis dcf,
    double currentPrice,
  ) {
    return Column(
      children: [
        // Fair Value vs Current Price Comparison
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    'DCF Fair Value',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
            Container(
              width: 1,
              height: 40,
              color: theme.colorScheme.outline.withOpacity(0.3),
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Current Price',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
          ],
        ),
        const SizedBox(height: 16),
        // Upside/Downside
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: dcf.isUndervalued
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: dcf.isUndervalued
                  ? Colors.green.withOpacity(0.3)
                  : Colors.red.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                dcf.isUndervalued ? Icons.trending_up : Icons.trending_down,
                color: dcf.isUndervalued ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                dcf.getValuationGap(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: dcf.isUndervalued ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Key DCF Metrics
        Text(
          'Key Valuation Inputs',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildSimpleDcfMetricItem(
                'WACC',
                dcf.formattedWacc,
                Icons.percent,
                theme,
              ),
            ),
            Expanded(
              child: _buildSimpleDcfMetricItem(
                'Beta',
                dcf.beta?.toStringAsFixed(2) ?? 'N/A',
                Icons.show_chart,
                theme,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildSimpleDcfMetricItem(
                'Terminal Growth',
                dcf.longTermGrowthRate != null
                    ? '${dcf.longTermGrowthRate!.toStringAsFixed(1)}%'
                    : 'N/A',
                Icons.trending_up,
                theme,
              ),
            ),
            Expanded(
              child: _buildSimpleDcfMetricItem(
                'Risk-Free Rate',
                dcf.riskFreeRate != null
                    ? '${dcf.riskFreeRate!.toStringAsFixed(1)}%'
                    : 'N/A',
                Icons.account_balance,
                theme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleDcfMetricItem(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 16),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDcfCalculationFlow(ThemeData theme, DcfAnalysis dcf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How DCF Fair Value is Calculated',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // Step 1: Cost of Capital (WACC)
        _buildDcfStep(
          theme,
          step: 1,
          title: 'Calculate Cost of Capital (WACC)',
          description:
              'Weighted Average Cost of Capital combines cost of equity and debt',
          visual: _buildWaccVisualization(theme, dcf),
        ),

        // Arrow
        Center(
          child: Icon(
            Icons.arrow_downward,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),

        // Step 2: Free Cash Flow
        _buildDcfStep(
          theme,
          step: 2,
          title: 'Project Free Cash Flows',
          description: 'Estimate future cash flows available to all investors',
          visual: _buildCashFlowVisualization(theme, dcf),
        ),

        // Arrow
        Center(
          child: Icon(
            Icons.arrow_downward,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),

        // Step 3: Terminal Value
        _buildDcfStep(
          theme,
          step: 3,
          title: 'Calculate Terminal Value',
          description: 'Value of business beyond explicit forecast period',
          visual: _buildTerminalValueVisualization(theme, dcf),
        ),

        // Arrow
        Center(
          child: Icon(
            Icons.arrow_downward,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),

        // Step 4: Present Value
        _buildDcfStep(
          theme,
          step: 4,
          title: 'Discount to Present Value',
          description: 'Convert future values to today\'s dollars using WACC',
          visual: _buildPresentValueVisualization(theme, dcf),
        ),

        // Arrow
        Center(
          child: Icon(
            Icons.arrow_downward,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),

        // Step 5: Fair Value per Share
        _buildDcfStep(
          theme,
          step: 5,
          title: 'Calculate Fair Value per Share',
          description: 'Divide equity value by diluted shares outstanding',
          visual: _buildFairValueVisualization(theme, dcf),
        ),
      ],
    );
  }

  Widget _buildDcfStep(
    ThemeData theme, {
    required int step,
    required String title,
    required String description,
    required Widget visual,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    step.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          visual,
        ],
      ),
    );
  }

  Widget _buildWaccVisualization(ThemeData theme, DcfAnalysis dcf) {
    final costOfEquity = dcf.costOfEquity ?? 0;
    final afterTaxCostOfDebt = dcf.afterTaxCostOfDebt ?? 0;
    final equityWeighting = dcf.equityWeighting ?? 0.7; // Default assumption
    final debtWeighting = dcf.debtWeighting ?? 0.3; // Default assumption

    return Column(
      children: [
        // WACC Formula
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'WACC = (Cost of Equity × % Equity) + (After-tax Cost of Debt × % Debt)',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),

        // Cost of Equity Breakdown
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Cost of Equity',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${costOfEquity.toStringAsFixed(1)}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    'Risk-free + (Beta × Risk Premium)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 40, color: theme.colorScheme.outline),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Cost of Debt',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${afterTaxCostOfDebt.toStringAsFixed(1)}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    'After-tax',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Capital Structure Visualization
        Text(
          'Capital Structure',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 20,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Expanded(
                flex: (equityWeighting * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(10),
                      right: equityWeighting == 1.0
                          ? Radius.circular(10)
                          : Radius.zero,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${(equityWeighting * 100).toStringAsFixed(0)}% Equity',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: (debtWeighting * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(10),
                      left: debtWeighting == 1.0
                          ? Radius.circular(10)
                          : Radius.zero,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${(debtWeighting * 100).toStringAsFixed(0)}% Debt',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Final WACC
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'WACC: ${dcf.formattedWacc}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCashFlowVisualization(ThemeData theme, DcfAnalysis dcf) {
    // Show simplified cash flow projection
    final years = ['Year 1', 'Year 2', 'Year 3', 'Year 4', 'Year 5'];
    final cashFlows = [
      dcf.ufcf ?? 0,
      (dcf.ufcf ?? 0) * 1.05,
      (dcf.ufcf ?? 0) * 1.10,
      (dcf.ufcf ?? 0) * 1.15,
      (dcf.ufcf ?? 0) * 1.20,
    ];

    return Column(
      children: [
        Text(
          'Free Cash Flow (FCF) = EBIT × (1-tax) + Depreciation - CapEx',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Cash Flow Timeline
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(years.length, (index) {
            return Column(
              children: [
                Container(
                  width: 50,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(
                      '\$${(cashFlows[index] / 1000000).toStringAsFixed(0)}M',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  years[index],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            );
          }),
        ),

        const SizedBox(height: 8),
        Center(
          child: Text(
            'Projected FCF growing at ~5-10% annually',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTerminalValueVisualization(ThemeData theme, DcfAnalysis dcf) {
    final terminalValue = dcf.terminalValue ?? 0;
    final lastCashFlow = dcf.ufcf ?? 0;
    final growthRate = dcf.longTermGrowthRate ?? 0.025; // 2.5% default
    final wacc = (dcf.wacc ?? 10) / 100;

    return Column(
      children: [
        Text(
          'Terminal Value = Final Year FCF × (1 + g) ÷ (WACC - g)',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Terminal Value Calculation Breakdown
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Final FCF',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${(lastCashFlow / 1000000).toStringAsFixed(0)}M',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.close, size: 16, color: theme.colorScheme.primary),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '(1 + g)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(growthRate * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.call_split, size: 16, color: theme.colorScheme.primary),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '(WACC - g)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${((wacc - growthRate) * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Result
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Text(
              'Terminal Value: \$${((terminalValue / 1000000).toStringAsFixed(0))}M',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.purple[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresentValueVisualization(ThemeData theme, DcfAnalysis dcf) {
    final presentTerminalValue = dcf.presentTerminalValue ?? 0;
    final sumPvUfcf = dcf.sumPvUfcf ?? 0;

    return Column(
      children: [
        Text(
          'Present Value = Future Value ÷ (1 + WACC)^n',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Present Value Breakdown
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    'PV of FCFs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${(sumPvUfcf / 1000000).toStringAsFixed(0)}M',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'PV of Terminal',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${(presentTerminalValue / 1000000).toStringAsFixed(0)}M',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Result
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Enterprise Value: ${dcf.formattedEnterpriseValue}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFairValueVisualization(ThemeData theme, DcfAnalysis dcf) {
    final netDebt = dcf.netDebt ?? 0;
    final equityValue = dcf.equityValue ?? 0;
    final sharesOutstanding = dcf.dilutedSharesOutstanding ?? 1;

    return Column(
      children: [
        Text(
          'Fair Value per Share = Equity Value ÷ Diluted Shares Outstanding',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Equity Value Calculation
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Enterprise Value',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dcf.formattedEnterpriseValue}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.remove, size: 16, color: theme.colorScheme.primary),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Net Debt',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${(netDebt / 1000000).toStringAsFixed(0)}M',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Equals
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 1, color: theme.colorScheme.outline),
              const SizedBox(width: 8),
              Text(
                '=',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 40, height: 1, color: theme.colorScheme.outline),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Equity Value
        Center(
          child: Column(
            children: [
              Text(
                'Equity Value',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${(equityValue / 1000000).toStringAsFixed(0)}M',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Per Share Calculation
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Equity Value',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${(equityValue / 1000000).toStringAsFixed(0)}M',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.call_split, size: 16, color: theme.colorScheme.primary),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Shares',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(sharesOutstanding / 1000000).toStringAsFixed(1)}M',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Final Fair Value
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: dcf.isUndervalued ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              'DCF Fair Value: ${dcf.formattedFairValue}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDcfValuationComparison(
    ThemeData theme,
    DcfAnalysis dcf,
    double currentPrice,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dcf.isUndervalued
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
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
                    dcf.isUndervalued ? Icons.trending_up : Icons.trending_down,
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
        ],
      ),
    );
  }

  Widget _buildDcfAssumptionsSection(ThemeData theme, DcfAnalysis dcf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Assumptions & Inputs',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),

        // Key Metrics Grid
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
                'Beta',
                dcf.beta?.toStringAsFixed(2) ?? 'N/A',
                Icons.show_chart,
                theme,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

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
                'Risk-Free Rate',
                dcf.riskFreeRate != null
                    ? '${dcf.riskFreeRate!.toStringAsFixed(1)}%'
                    : 'N/A',
                Icons.account_balance,
                theme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDcfMetricItem(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.all(4),
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
        _fetchCompanyProfile(),
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

  Future<void> _fetchCompanyProfile() async {
    if (_stockSymbol == null) return;

    try {
      final apiService = ApiService();
      _companyProfile = await apiService.getCompanyProfileDetails(
        _stockSymbol!,
      );
    } catch (e) {
      debugPrint('Error fetching company profile: $e');
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

  String _getFirstSentence(String text) {
    // Find the first sentence by looking for the first period followed by a space or end of string
    final firstPeriodIndex = text.indexOf('.');
    if (firstPeriodIndex != -1) {
      // Check if there's more content after the period
      if (firstPeriodIndex < text.length - 1) {
        return text.substring(0, firstPeriodIndex + 1);
      }
    }
    // If no period found or it's at the end, return the whole text
    return text;
  }

  bool _hasMoreThanOneSentence(String text) {
    // Check if there's a period followed by more content
    final firstPeriodIndex = text.indexOf('.');
    if (firstPeriodIndex != -1 && firstPeriodIndex < text.length - 1) {
      // Check if there's non-whitespace content after the period
      final remainingText = text.substring(firstPeriodIndex + 1).trim();
      return remainingText.isNotEmpty;
    }
    return false;
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
