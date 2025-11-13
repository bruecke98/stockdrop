import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';

// Import the new ChartWidget
import '../widgets/chart_widget.dart';
import '../services/api_service.dart';
import '../models/stock.dart';
import '../models/market_hours.dart';
import 'stock_comparison_screen.dart';

/// Data class for ratio chart visualization
class RatioChartData {
  final String label;
  final List<double?> data;
  final Color color;

  const RatioChartData({
    required this.label,
    required this.data,
    required this.color,
  });
}

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
  bool _isKeyMetricsChartView =
      false; // Toggle between table and chart view for key metrics
  List<FinancialRatios> _financialRatios = [];
  bool _isRatiosChartView =
      false; // Toggle between table and chart view for ratios
  FinancialScores? _financialScores;
  List<SectorPerformance> _sectorPerformance = [];
  List<SectorPeData> _sectorPeData = [];
  List<IndustryPeData> _industryPeData = [];
  List<InsiderTrading> _insiderTrading = [];
  List<SenateTrading> _senateTrading = [];
  List<HouseTrading> _houseTrading = [];
  List<AnalystEstimates> _analystEstimates = [];
  bool _isAnalystEstimatesExpanded = false;
  GradesConsensus? _gradesConsensus;
  List<RevenueSegmentation> _revenueSegmentation = [];
  List<RevenueSegmentation> _revenueGeoSegmentation = [];
  bool _showGeographicRevenue = false;
  bool _isRevenueSegmentationLoading = false;
  CompanyProfile? _companyProfile;
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isTogglingFavorite = false;
  bool _isDescriptionExpanded = false;
  bool _isDcfExtendedView = false;
  int _insiderTradesBatchCount =
      0; // Number of 10-trade batches loaded (0 = show 1, 1 = show 11, etc.)
  String _insiderTransactionFilter = 'All'; // All, Buy, Sell
  int _senateTradesBatchCount =
      0; // Number of 10-trade batches loaded (0 = show 1, 1 = show 11, etc.)
  String _senateTransactionFilter = 'All'; // All, Buy, Sell
  int _houseTradesBatchCount =
      0; // Number of 10-trade batches loaded (0 = show 1, 1 = show 11, etc.)
  String _houseTransactionFilter = 'All'; // All, Buy, Sell
  bool _isSenateTradingSelected =
      true; // Toggle between Senate and House trading
  String? _error;
  String? _stockSymbol;
  List<MarketHours> _marketHours = [];
  bool _isLoadingMarketHours = true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  void _initializeScreen() {
    // Get symbol from widget parameter or route arguments
    _stockSymbol = widget.symbol;
    _isRevenueSegmentationLoading = true;

    // Fetch market hours
    _fetchMarketHours();

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
          if (_stockDetail != null) ...[
            IconButton(
              icon: const Icon(Icons.compare_arrows),
              onPressed: () => _navigateToComparison(),
              tooltip: 'Compare Stocks',
            ),
            _buildFavoriteButton(theme),
          ],
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
            _buildFinancialRatiosSection(theme),
            const SizedBox(height: 24),
            _buildFinancialScoresSection(theme),
            const SizedBox(height: 24),
            _buildSectorComparisonSection(theme),
            const SizedBox(height: 24),
            _buildInsiderTradingSection(theme),
            const SizedBox(height: 24),
            _buildSenateTradingSection(theme),
            const SizedBox(height: 24),
            _buildAnalystEstimatesSection(theme),
            const SizedBox(height: 24),
            _buildGradesConsensusSection(theme),
            const SizedBox(height: 24),
            _buildComparisonSection(theme),
            const SizedBox(height: 24),
            _buildRevenueSegmentationSection(theme),
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
            // Replace range indicator with price chart
            if (_stockSymbol != null)
              Container(
                height: 350,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: ChartWidget(
                    symbol: _stockSymbol!,
                    height: 350,
                    lineColor: (stock.changesPercentage ?? 0) >= 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
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

            // Market Cap with categorization
            if (_stockDetail?.marketCap != null) ...[
              Container(
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
                          _formatMarketCap(_stockDetail!.marketCap!),
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
                            color: _getMarketCapCategoryColor(
                              _stockDetail!.marketCap!,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getMarketCapCategoryColor(
                                _stockDetail!.marketCap!,
                              ).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getMarketCapCategory(_stockDetail!.marketCap!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _getMarketCapCategoryColor(
                                _stockDetail!.marketCap!,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.primary,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isMarketOpen(profile.exchange!)
                                    ? Icons.wb_sunny
                                    : Icons.nightlight_round,
                                size: 12,
                                color: _isMarketOpen(profile.exchange!)
                                    ? Colors.lightGreen
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getExchangeAbbreviation(profile.exchange!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildRevenueSegmentationSection(ThemeData theme) {
    // Decide which dataset to show based on the toggle
    if (!_showGeographicRevenue) {
      if (_revenueSegmentation.isEmpty || _isRevenueSegmentationLoading) {
        return _buildRevenueSegmentationLoadingCard(theme);
      }
    } else {
      if (_revenueGeoSegmentation.isEmpty || _isRevenueSegmentationLoading) {
        return _buildRevenueSegmentationLoadingCard(theme);
      }
    }

    // Get the most recent segmentation data based on current mode
    final latestSegmentation = !_showGeographicRevenue
        ? _revenueSegmentation.first
        : _revenueGeoSegmentation.first;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
                Icons.business_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _showGeographicRevenue
                    ? 'Revenue by Geography'
                    : 'Revenue by Product',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Move toggle below header
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (_showGeographicRevenue) {
                        setState(() => _showGeographicRevenue = false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: !_showGeographicRevenue
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Product',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: !_showGeographicRevenue
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      if (!_showGeographicRevenue) {
                        setState(() => _showGeographicRevenue = true);
                        // fetch geographic data if needed
                        if (_revenueGeoSegmentation.isEmpty) {
                          await _fetchRevenueGeographicSegmentation();
                          if (mounted) {
                            setState(() {});
                          }
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _showGeographicRevenue
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Geography',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _showGeographicRevenue
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'FY${latestSegmentation.fiscalYear} ${latestSegmentation.period} - ${RevenueSegmentation.formatRevenue(latestSegmentation.totalRevenue)} total revenue',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _buildRevenueSegmentationChart(theme, latestSegmentation),
          const SizedBox(height: 20),
          _buildRevenueSegmentationList(theme, latestSegmentation),
        ],
      ),
    );
  }

  Widget _buildRevenueSegmentationLoadingCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
                Icons.business_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Revenue by Product',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading revenue data...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueSegmentationChart(
    ThemeData theme,
    RevenueSegmentation segmentation,
  ) {
    final sortedProducts = segmentation.sortedProducts.take(
      6,
    ); // Top 6 products

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: List.generate(sortedProducts.length, (index) {
                  final product = sortedProducts.elementAt(index);
                  final percentage = segmentation.getProductPercentage(
                    product.key,
                  );
                  final colors = [
                    Colors.blue,
                    Colors.green,
                    Colors.orange,
                    Colors.red,
                    Colors.purple,
                    Colors.teal,
                  ];

                  return PieChartSectionData(
                    value: product.value,
                    title: '${percentage.toStringAsFixed(1)}%',
                    radius: 60,
                    titleStyle: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    color: colors[index % colors.length],
                  );
                }),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueSegmentationList(
    ThemeData theme,
    RevenueSegmentation segmentation,
  ) {
    final sortedProducts = segmentation.sortedProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Details',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...sortedProducts.map((product) {
          final percentage = segmentation.getProductPercentage(product.key);
          final colors = [
            Colors.blue,
            Colors.green,
            Colors.orange,
            Colors.red,
            Colors.purple,
            Colors.teal,
          ];
          final colorIndex = sortedProducts.indexOf(product) % colors.length;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[colorIndex],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.key,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}% of total revenue',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  RevenueSegmentation.formatRevenue(product.value),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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
      margin: const EdgeInsets.symmetric(vertical: 8),
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
      margin: const EdgeInsets.symmetric(vertical: 8),
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
            ],
          ),
          const SizedBox(height: 12),
          // Toggle between table and chart view
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isKeyMetricsChartView = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: !_isKeyMetricsChartView
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Table',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: !_isKeyMetricsChartView
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isKeyMetricsChartView = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isKeyMetricsChartView
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Chart',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _isKeyMetricsChartView
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Show either table or chart view
          _isKeyMetricsChartView
              ? _buildKeyMetricsChartView(theme)
              : _buildKeyMetricsTableView(theme),
        ],
      ),
    );
  }

  // Calculate scores for different metric categories
  Map<String, int> _calculateCategoryScores(KeyMetrics metrics) {
    int valuationScore = 50;
    int profitabilityScore = 50;
    int liquidityScore = 50;
    int cashFlowScore = 50;

    // Valuation Score (based on reasonable valuation ratios)
    if (metrics.evToSales != null) {
      if (metrics.evToSales! < 2.0)
        valuationScore += 20;
      else if (metrics.evToSales! < 5.0)
        valuationScore += 10;
      else if (metrics.evToSales! > 10.0)
        valuationScore -= 10;
    }

    if (metrics.evToEBITDA != null) {
      if (metrics.evToEBITDA! < 10.0)
        valuationScore += 15;
      else if (metrics.evToEBITDA! < 15.0)
        valuationScore += 5;
      else if (metrics.evToEBITDA! > 25.0)
        valuationScore -= 15;
    }

    // Profitability Score
    if (metrics.returnOnEquity != null) {
      if (metrics.returnOnEquity! > 0.15)
        profitabilityScore += 25;
      else if (metrics.returnOnEquity! > 0.10)
        profitabilityScore += 15;
      else if (metrics.returnOnEquity! < 0.05)
        profitabilityScore -= 15;
    }

    if (metrics.returnOnAssets != null) {
      if (metrics.returnOnAssets! > 0.08)
        profitabilityScore += 20;
      else if (metrics.returnOnAssets! > 0.05)
        profitabilityScore += 10;
      else if (metrics.returnOnAssets! < 0.02)
        profitabilityScore -= 10;
    }

    // Liquidity Score
    if (metrics.currentRatio != null) {
      if (metrics.currentRatio! > 2.0)
        liquidityScore += 25;
      else if (metrics.currentRatio! > 1.5)
        liquidityScore += 15;
      else if (metrics.currentRatio! < 1.0)
        liquidityScore -= 20;
    }

    // Cash Flow Score
    if (metrics.freeCashFlowYield != null) {
      if (metrics.freeCashFlowYield! > 0.05)
        cashFlowScore += 25;
      else if (metrics.freeCashFlowYield! > 0.02)
        cashFlowScore += 15;
      else if (metrics.freeCashFlowYield! < 0.0)
        cashFlowScore -= 20;
    }

    if (metrics.capexToOperatingCashFlow != null) {
      if (metrics.capexToOperatingCashFlow! < 0.5)
        cashFlowScore += 15;
      else if (metrics.capexToOperatingCashFlow! > 0.8)
        cashFlowScore -= 10;
    }

    return {
      'valuation': valuationScore.clamp(0, 100),
      'profitability': profitabilityScore.clamp(0, 100),
      'liquidity': liquidityScore.clamp(0, 100),
      'cashFlow': cashFlowScore.clamp(0, 100),
    };
  }

  Color _getCategoryScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    if (score >= 20) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildKeyMetricsTableView(ThemeData theme) {
    final selectedMetrics = _keyMetrics.first;
    final categoryScores = _calculateCategoryScores(selectedMetrics);

    return Column(
      children: [
        // Financial Health Score
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getHealthScoreColor(
              selectedMetrics.financialHealthScore,
            ).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getHealthScoreColor(
                selectedMetrics.financialHealthScore,
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
                      selectedMetrics.financialHealthDescription,
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
                    selectedMetrics.financialHealthScore,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${selectedMetrics.financialHealthScore}',
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
        _buildMetricsCategory(
          'Valuation Metrics',
          [
            _buildMetricRow(
              'Market Cap',
              selectedMetrics.formattedMarketCap,
              theme,
            ),
            _buildMetricRow(
              'Enterprise Value',
              selectedMetrics.formattedEnterpriseValue,
              theme,
            ),
            _buildMetricRow(
              'EV/Sales',
              selectedMetrics.formatRatio(selectedMetrics.evToSales),
              theme,
            ),
            _buildMetricRow(
              'EV/EBITDA',
              selectedMetrics.formatRatio(selectedMetrics.evToEBITDA),
              theme,
            ),
            _buildMetricRow(
              'EV/FCF',
              selectedMetrics.formatRatio(selectedMetrics.evToFreeCashFlow),
              theme,
            ),
          ],
          theme,
          score: categoryScores['valuation'],
          scoreColor: _getCategoryScoreColor(categoryScores['valuation']!),
        ),

        const SizedBox(height: 20),

        // Profitability Metrics
        _buildMetricsCategory(
          'Profitability Metrics',
          [
            _buildMetricRow(
              'ROE',
              selectedMetrics.formatRatio(selectedMetrics.returnOnEquity),
              theme,
            ),
            _buildMetricRow(
              'ROA',
              selectedMetrics.formatRatio(selectedMetrics.returnOnAssets),
              theme,
            ),
            _buildMetricRow(
              'ROIC',
              selectedMetrics.formatRatio(
                selectedMetrics.returnOnCapitalEmployed,
              ),
              theme,
            ),
            _buildMetricRow(
              'Operating ROA',
              selectedMetrics.formatRatio(
                selectedMetrics.operatingReturnOnAssets,
              ),
              theme,
            ),
            _buildMetricRow(
              'Earnings Yield',
              selectedMetrics.formatRatio(selectedMetrics.earningsYield),
              theme,
            ),
          ],
          theme,
          score: categoryScores['profitability'],
          scoreColor: _getCategoryScoreColor(categoryScores['profitability']!),
        ),

        const SizedBox(height: 20),

        // Liquidity & Efficiency Metrics
        _buildMetricsCategory(
          'Liquidity & Efficiency',
          [
            _buildMetricRow(
              'Current Ratio',
              selectedMetrics.formatRatio(selectedMetrics.currentRatio),
              theme,
            ),
            _buildMetricRow(
              'Working Capital',
              selectedMetrics.formattedWorkingCapital,
              theme,
            ),
            _buildMetricRow(
              'Cash Conversion Cycle',
              selectedMetrics.formatDays(selectedMetrics.cashConversionCycle),
              theme,
            ),
            _buildMetricRow(
              'Days Sales Outstanding',
              selectedMetrics.formatDays(
                selectedMetrics.daysOfSalesOutstanding,
              ),
              theme,
            ),
            _buildMetricRow(
              'Income Quality',
              selectedMetrics.formatRatio(selectedMetrics.incomeQuality),
              theme,
            ),
          ],
          theme,
          score: categoryScores['liquidity'],
          scoreColor: _getCategoryScoreColor(categoryScores['liquidity']!),
        ),

        const SizedBox(height: 20),

        // Cash Flow Metrics
        _buildMetricsCategory(
          'Cash Flow Metrics',
          [
            _buildMetricRow(
              'Free Cash Flow Yield',
              selectedMetrics.formatRatio(selectedMetrics.freeCashFlowYield),
              theme,
            ),
            _buildMetricRow(
              'CapEx to Operating CF',
              selectedMetrics.formatRatio(
                selectedMetrics.capexToOperatingCashFlow,
              ),
              theme,
            ),
            _buildMetricRow(
              'CapEx to Revenue',
              selectedMetrics.formatRatio(selectedMetrics.capexToRevenue),
              theme,
            ),
            _buildMetricRow(
              'R&D to Revenue',
              selectedMetrics.formatRatio(
                selectedMetrics.researchAndDevelopementToRevenue,
              ),
              theme,
            ),
          ],
          theme,
          score: categoryScores['cashFlow'],
          scoreColor: _getCategoryScoreColor(categoryScores['cashFlow']!),
        ),

        if (_keyMetrics.length > 1) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
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
    );
  }

  Widget _buildKeyMetricsChartView(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Financial Health Score
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
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
                        _keyMetrics.first.financialHealthDescription,
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
                      _keyMetrics.first.financialHealthScore,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${_keyMetrics.first.financialHealthScore}',
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

          // Valuation Metrics Chart
          _buildCategoryChart(
            'Valuation Metrics',
            _getValuationChartData(),
            theme,
            score: _calculateCategoryScores(_keyMetrics.first)['valuation'],
            scoreColor: _getCategoryScoreColor(
              _calculateCategoryScores(_keyMetrics.first)['valuation']!,
            ),
          ),

          const SizedBox(height: 20),

          // Profitability Metrics Chart
          _buildCategoryChart(
            'Profitability Metrics',
            _getProfitabilityChartData(),
            theme,
            score: _calculateCategoryScores(_keyMetrics.first)['profitability'],
            scoreColor: _getCategoryScoreColor(
              _calculateCategoryScores(_keyMetrics.first)['profitability']!,
            ),
          ),

          const SizedBox(height: 20),

          // Liquidity Metrics Chart
          _buildCategoryChart(
            'Liquidity & Efficiency',
            _getLiquidityChartData(),
            theme,
            score: _calculateCategoryScores(_keyMetrics.first)['liquidity'],
            scoreColor: _getCategoryScoreColor(
              _calculateCategoryScores(_keyMetrics.first)['liquidity']!,
            ),
          ),

          const SizedBox(height: 20),

          // Cash Flow Metrics Chart
          _buildCategoryChart(
            'Cash Flow Metrics',
            _getCashFlowChartData(),
            theme,
            score: _calculateCategoryScores(_keyMetrics.first)['cashFlow'],
            scoreColor: _getCategoryScoreColor(
              _calculateCategoryScores(_keyMetrics.first)['cashFlow']!,
            ),
          ),

          if (_keyMetrics.length > 1) ...[
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _buildCategoryChart(
    String title,
    List<List<FlSpot>> dataLines,
    ThemeData theme, {
    int? score,
    Color? scoreColor,
  }) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
    ];

    final labels = title == 'Valuation Metrics'
        ? ['EV/EBITDA', 'EV/Sales', 'EV/FCF', 'EV/Operating CF']
        : title == 'Profitability Metrics'
        ? [
            'ROE (%)',
            'ROA (%)',
            'ROIC (%)',
            'Operating ROA (%)',
            'Earnings Yield (%)',
          ]
        : title == 'Liquidity & Efficiency'
        ? [
            'Current Ratio',
            'Working Capital',
            'Cash Conversion Cycle',
            'Income Quality',
          ]
        : [
            'FCF Yield (%)',
            'CapEx to Operating CF (%)',
            'CapEx to Revenue (%)',
            'R&D to Revenue (%)',
          ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (score != null && scoreColor != null)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scoreColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$score',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child:
                dataLines.isNotEmpty && dataLines.any((line) => line.isNotEmpty)
                ? LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 2.0,
                        verticalInterval: 5.0,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 10,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toStringAsFixed(0),
                                style: theme.textTheme.bodySmall,
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: dataLines.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        return LineChartBarData(
                          spots: data,
                          isCurved: true,
                          color: colors[index % colors.length],
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        );
                      }).toList(),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final lineIndex = touchedSpots.indexOf(spot);
                              return LineTooltipItem(
                                '${labels[lineIndex]}: ${spot.y.toStringAsFixed(2)}',
                                TextStyle(
                                  color: colors[lineIndex % colors.length],
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      'No historical data available',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),

          // Legend
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: List.generate(
              dataLines.length,
              (index) => _buildLegendItem(
                labels[index],
                colors[index % colors.length],
                theme,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  List<List<FlSpot>> _getValuationChartData() {
    return [
      // EV/EBITDA
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(index.toDouble(), metrics.evToEBITDA ?? 0.0);
      }).toList(),
      // EV/Sales
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(index.toDouble(), metrics.evToSales ?? 0.0);
      }).toList(),
      // EV/FCF
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(index.toDouble(), metrics.evToFreeCashFlow ?? 0.0);
      }).toList(),
      // EV/Operating Cash Flow
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(index.toDouble(), metrics.evToOperatingCashFlow ?? 0.0);
      }).toList(),
    ];
  }

  List<List<FlSpot>> _getProfitabilityChartData() {
    return [
      // ROE (%)
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(index.toDouble(), (metrics.returnOnEquity ?? 0.0) * 100);
      }).toList(),
      // ROA (%)
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(index.toDouble(), (metrics.returnOnAssets ?? 0.0) * 100);
      }).toList(),
      // ROIC (%)
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(
          index.toDouble(),
          (metrics.returnOnInvestedCapital ?? 0.0) * 100,
        );
      }).toList(),
      // Operating ROA (%)
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(
          index.toDouble(),
          (metrics.operatingReturnOnAssets ?? 0.0) * 100,
        );
      }).toList(),
      // Earnings Yield (%)
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(index.toDouble(), (metrics.earningsYield ?? 0.0) * 100);
      }).toList(),
    ];
  }

  List<List<FlSpot>> _getLiquidityChartData() {
    return [
      // Current Ratio
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(index.toDouble(), metrics.currentRatio ?? 0.0);
      }).toList(),
      // Working Capital (in millions)
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(
          index.toDouble(),
          (metrics.workingCapital ?? 0.0) / 1000000,
        ); // Convert to millions
      }).toList(),
      // Cash Conversion Cycle (days)
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(index.toDouble(), metrics.cashConversionCycle ?? 0.0);
      }).toList(),
      // Income Quality
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(index.toDouble(), metrics.incomeQuality ?? 0.0);
      }).toList(),
    ];
  }

  List<List<FlSpot>> _getCashFlowChartData() {
    return [
      // Free Cash Flow Yield (%)
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(
          index.toDouble(),
          (metrics.freeCashFlowYield ?? 0.0) * 100,
        );
      }).toList(),
      // CapEx to Operating Cash Flow (%)
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(
          index.toDouble(),
          (metrics.capexToOperatingCashFlow ?? 0.0) * 100,
        );
      }).toList(),
      // CapEx to Revenue (%)
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(index.toDouble(), (metrics.capexToRevenue ?? 0.0) * 100);
      }).toList(),
      // R&D to Revenue (%)
      _keyMetrics.asMap().entries.map((entry) {
        final index = entry.key;
        final metrics = entry.value;
        return FlSpot(
          index.toDouble(),
          (metrics.researchAndDevelopementToRevenue ?? 0.0) * 100,
        );
      }).toList(),
    ];
  }

  Widget _buildMetricsCategory(
    String title,
    List<Widget> metrics,
    ThemeData theme, {
    int? score,
    Color? scoreColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            if (score != null && scoreColor != null)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scoreColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$score',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
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

  Widget _buildMetricRow(
    String label,
    String value,
    ThemeData theme, {
    String? score,
  }) {
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
          if (score != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getRatioScoreColor(score).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getRatioScoreColor(score), width: 1),
              ),
              child: Text(
                score,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _getRatioScoreColor(score),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
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

  /// Get color for ratio score
  Color _getRatioScoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'EXCELLENT':
        return Colors.green.shade700;
      case 'GOOD':
        return Colors.green.shade500;
      case 'AVERAGE':
        return Colors.yellow.shade700;
      case 'POOR':
        return Colors.orange.shade700;
      case 'BAD':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  /// Format market cap value as string
  String _formatMarketCap(double marketCap) {
    if (marketCap >= 1000000000000) {
      // $1T+
      return '\$${(marketCap / 1000000000000).toStringAsFixed(2)}T';
    } else if (marketCap >= 1000000000) {
      // $1B+
      return '\$${(marketCap / 1000000000).toStringAsFixed(2)}B';
    } else if (marketCap >= 1000000) {
      // $1M+
      return '\$${(marketCap / 1000000).toStringAsFixed(2)}M';
    } else {
      return '\$${marketCap.toStringAsFixed(0)}';
    }
  }

  /// Score profitability ratios (higher is better)
  String _scoreProfitabilityRatio(double? value) {
    if (value == null) return 'N/A';
    final percent = value * 100;
    if (percent >= 20) return 'EXCELLENT';
    if (percent >= 15) return 'GOOD';
    if (percent >= 10) return 'AVERAGE';
    if (percent >= 5) return 'POOR';
    return 'BAD';
  }

  /// Score valuation ratios (lower is generally better for most ratios)
  String _scoreValuationRatio(double? value, String ratioType) {
    if (value == null || value <= 0) return 'N/A';

    switch (ratioType) {
      case 'PE': // P/E Ratio
        if (value <= 15) return 'EXCELLENT';
        if (value <= 20) return 'GOOD';
        if (value <= 25) return 'AVERAGE';
        if (value <= 30) return 'POOR';
        return 'BAD';
      case 'PB': // P/B Ratio
        if (value <= 1.5) return 'EXCELLENT';
        if (value <= 2.5) return 'GOOD';
        if (value <= 3.5) return 'AVERAGE';
        if (value <= 4.5) return 'POOR';
        return 'BAD';
      case 'PS': // P/S Ratio
        if (value <= 2) return 'EXCELLENT';
        if (value <= 3) return 'GOOD';
        if (value <= 5) return 'AVERAGE';
        if (value <= 7) return 'POOR';
        return 'BAD';
      case 'EVEBITDA': // EV/EBITDA
        if (value <= 8) return 'EXCELLENT';
        if (value <= 12) return 'GOOD';
        if (value <= 15) return 'AVERAGE';
        if (value <= 20) return 'POOR';
        return 'BAD';
      default:
        return 'N/A';
    }
  }

  /// Score liquidity ratios (higher is generally better)
  String _scoreLiquidityRatio(double? value) {
    if (value == null) return 'N/A';
    if (value >= 2.0) return 'EXCELLENT';
    if (value >= 1.5) return 'GOOD';
    if (value >= 1.0) return 'AVERAGE';
    if (value >= 0.5) return 'POOR';
    return 'BAD';
  }

  /// Score leverage ratios (lower is generally better)
  String _scoreLeverageRatio(double? value) {
    if (value == null) return 'N/A';
    if (value <= 0.5) return 'EXCELLENT';
    if (value <= 1.0) return 'GOOD';
    if (value <= 1.5) return 'AVERAGE';
    if (value <= 2.0) return 'POOR';
    return 'BAD';
  }

  Widget _buildFinancialRatiosSection(ThemeData theme) {
    if (_financialRatios.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
                'Financial Ratios',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Toggle between table and chart view
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isRatiosChartView = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: !_isRatiosChartView
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Table',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: !_isRatiosChartView
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isRatiosChartView = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isRatiosChartView
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Chart',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _isRatiosChartView
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12), // Show either table or chart view
          _isRatiosChartView
              ? _buildRatiosChartView(theme)
              : _buildRatiosTableView(theme),

          if (_financialRatios.length > 1) ...[
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
                    '${_financialRatios.length} years of historical ratios available',
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

  Widget _buildRatiosTableView(ThemeData theme) {
    final selectedRatios = _financialRatios.first;

    return Column(
      children: [
        // Profitability Ratios - Showing progression from Revenue to Net Profit
        _buildRatiosCategory(
          'Profitability Ratios (Revenue → Operating Profit → EBITDA → Net Profit)',
          [
            _buildMetricRow(
              'Gross Profit Margin',
              selectedRatios.formatPercentage(selectedRatios.grossProfitMargin),
              theme,
              score: _scoreProfitabilityRatio(selectedRatios.grossProfitMargin),
            ),
            _buildMetricRow(
              'Operating Profit Margin',
              selectedRatios.formatPercentage(
                selectedRatios.operatingProfitMargin,
              ),
              theme,
              score: _scoreProfitabilityRatio(
                selectedRatios.operatingProfitMargin,
              ),
            ),
            _buildMetricRow(
              'EBITDA Margin',
              selectedRatios.formatPercentage(selectedRatios.ebitdaMargin),
              theme,
              score: _scoreProfitabilityRatio(selectedRatios.ebitdaMargin),
            ),
            _buildMetricRow(
              'Net Profit Margin',
              selectedRatios.formatPercentage(selectedRatios.netProfitMargin),
              theme,
              score: _scoreProfitabilityRatio(selectedRatios.netProfitMargin),
            ),
          ],
          theme,
        ),

        const SizedBox(height: 16),

        // Valuation Ratios
        _buildRatiosCategory('Valuation Ratios', [
          _buildMetricRow(
            'P/E Ratio',
            selectedRatios.formatRatio(selectedRatios.priceToEarningsRatio),
            theme,
            score: _scoreValuationRatio(
              selectedRatios.priceToEarningsRatio,
              'PE',
            ),
          ),
          _buildMetricRow(
            'P/B Ratio',
            selectedRatios.formatRatio(selectedRatios.priceToBookRatio),
            theme,
            score: _scoreValuationRatio(selectedRatios.priceToBookRatio, 'PB'),
          ),
          _buildMetricRow(
            'P/S Ratio',
            selectedRatios.formatRatio(selectedRatios.priceToSalesRatio),
            theme,
            score: _scoreValuationRatio(selectedRatios.priceToSalesRatio, 'PS'),
          ),
          _buildMetricRow(
            'EV/EBITDA',
            selectedRatios.formatRatio(selectedRatios.enterpriseValueMultiple),
            theme,
            score: _scoreValuationRatio(
              selectedRatios.enterpriseValueMultiple,
              'EVEBITDA',
            ),
          ),
        ], theme),

        const SizedBox(height: 16),

        // Liquidity Ratios
        _buildRatiosCategory('Liquidity Ratios', [
          _buildMetricRow(
            'Current Ratio',
            selectedRatios.formatRatio(selectedRatios.currentRatio),
            theme,
            score: _scoreLiquidityRatio(selectedRatios.currentRatio),
          ),
          _buildMetricRow(
            'Quick Ratio',
            selectedRatios.formatRatio(selectedRatios.quickRatio),
            theme,
            score: _scoreLiquidityRatio(selectedRatios.quickRatio),
          ),
          _buildMetricRow(
            'Cash Ratio',
            selectedRatios.formatRatio(selectedRatios.cashRatio),
            theme,
            score: _scoreLiquidityRatio(selectedRatios.cashRatio),
          ),
        ], theme),

        const SizedBox(height: 16),

        // Leverage Ratios
        _buildRatiosCategory('Leverage Ratios', [
          _buildMetricRow(
            'Debt to Equity',
            selectedRatios.formatRatio(selectedRatios.debtToEquityRatio),
            theme,
            score: _scoreLeverageRatio(selectedRatios.debtToEquityRatio),
          ),
          _buildMetricRow(
            'Debt to Assets',
            selectedRatios.formatRatio(selectedRatios.debtToAssetsRatio),
            theme,
            score: _scoreLeverageRatio(selectedRatios.debtToAssetsRatio),
          ),
          _buildMetricRow(
            'Financial Leverage',
            selectedRatios.formatRatio(selectedRatios.financialLeverageRatio),
            theme,
            score: _scoreLeverageRatio(selectedRatios.financialLeverageRatio),
          ),
        ], theme),

        if (_financialRatios.length > 1) ...[
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
                  '${_financialRatios.length} years of historical ratios available',
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
    );
  }

  Widget _buildRatiosChartView(ThemeData theme) {
    // Get the last 5 years of data (or all if less than 5)
    final chartData = _financialRatios.take(5).toList().reversed.toList();

    return Column(
      children: [
        // Profitability Ratios Chart
        _buildRatioChartCategory(
          'Profitability Ratios',
          [
            RatioChartData(
              label: 'Gross Profit Margin',
              data: chartData.map((r) => r.grossProfitMargin).toList(),
              color: Colors.blue,
            ),
            RatioChartData(
              label: 'Operating Profit Margin',
              data: chartData.map((r) => r.operatingProfitMargin).toList(),
              color: Colors.green,
            ),
            RatioChartData(
              label: 'Net Profit Margin',
              data: chartData.map((r) => r.netProfitMargin).toList(),
              color: Colors.orange,
            ),
            RatioChartData(
              label: 'EBITDA Margin',
              data: chartData.map((r) => r.ebitdaMargin).toList(),
              color: Colors.purple,
            ),
          ],
          chartData.map((r) => r.formattedPeriod).toList(),
          theme,
          isPercentage: true,
        ),

        const SizedBox(height: 24),

        // Valuation Ratios Chart
        _buildRatioChartCategory(
          'Valuation Ratios',
          [
            RatioChartData(
              label: 'P/E Ratio',
              data: chartData.map((r) => r.priceToEarningsRatio).toList(),
              color: Colors.red,
            ),
            RatioChartData(
              label: 'P/B Ratio',
              data: chartData.map((r) => r.priceToBookRatio).toList(),
              color: Colors.teal,
            ),
            RatioChartData(
              label: 'P/S Ratio',
              data: chartData.map((r) => r.priceToSalesRatio).toList(),
              color: Colors.indigo,
            ),
            RatioChartData(
              label: 'EV/EBITDA',
              data: chartData.map((r) => r.enterpriseValueMultiple).toList(),
              color: Colors.amber,
            ),
          ],
          chartData.map((r) => r.formattedPeriod).toList(),
          theme,
          isPercentage: false,
        ),

        const SizedBox(height: 24),

        // Liquidity Ratios Chart
        _buildRatioChartCategory(
          'Liquidity Ratios',
          [
            RatioChartData(
              label: 'Current Ratio',
              data: chartData.map((r) => r.currentRatio).toList(),
              color: Colors.cyan,
            ),
            RatioChartData(
              label: 'Quick Ratio',
              data: chartData.map((r) => r.quickRatio).toList(),
              color: Colors.pink,
            ),
            RatioChartData(
              label: 'Cash Ratio',
              data: chartData.map((r) => r.cashRatio).toList(),
              color: Colors.lime,
            ),
          ],
          chartData.map((r) => r.formattedPeriod).toList(),
          theme,
          isPercentage: false,
        ),

        const SizedBox(height: 24),

        // Leverage Ratios Chart
        _buildRatioChartCategory(
          'Leverage Ratios',
          [
            RatioChartData(
              label: 'Debt to Equity',
              data: chartData.map((r) => r.debtToEquityRatio).toList(),
              color: Colors.deepOrange,
            ),
            RatioChartData(
              label: 'Debt to Assets',
              data: chartData.map((r) => r.debtToAssetsRatio).toList(),
              color: Colors.lightBlue,
            ),
            RatioChartData(
              label: 'Financial Leverage',
              data: chartData.map((r) => r.financialLeverageRatio).toList(),
              color: Colors.deepPurple,
            ),
          ],
          chartData.map((r) => r.formattedPeriod).toList(),
          theme,
          isPercentage: false,
        ),
      ],
    );
  }

  Widget _buildRatioChartCategory(
    String title,
    List<RatioChartData> ratios,
    List<String> periods,
    ThemeData theme, {
    required bool isPercentage,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: isPercentage ? 0.1 : 1.0,
                  verticalInterval: 1.0,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < periods.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              periods[index],
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
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
                      interval: isPercentage ? 0.2 : 2.0,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          isPercentage
                              ? '${(value * 100).toStringAsFixed(0)}%'
                              : value.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                minX: 0,
                maxX: (periods.length - 1).toDouble(),
                minY: 0,
                maxY: isPercentage ? 1.0 : null,
                lineBarsData: ratios.map((ratio) {
                  return LineChartBarData(
                    spots: List.generate(
                      ratio.data.length,
                      (index) =>
                          FlSpot(index.toDouble(), ratio.data[index] ?? 0.0),
                    ).where((spot) => spot.y != 0.0).toList(),
                    isCurved: true,
                    color: ratio.color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: ratio.color,
                          strokeWidth: 2,
                          strokeColor: theme.colorScheme.surface,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: ratio.color.withOpacity(0.1),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: ratios.map((ratio) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: ratio.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ratio.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialScoresSection(ThemeData theme) {
    if (_financialScores == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.health_and_safety,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Financial Health',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Piotroski F-Score Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main heading
                Text(
                  'Piotrowski F Score',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                // Subheading
                Text(
                  'Fundamental Strength',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _financialScores!.piotroskiScore?.toString() ??
                                    'N/A',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getScoreColor(
                                    _financialScores!.getPiotroskiScoreColor(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_upward,
                                color: _getScoreColor(
                                  _financialScores!.getPiotroskiScoreColor(),
                                ),
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _financialScores!.getPiotroskiScoreInterpretation(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value:
                                  (_financialScores!.piotroskiScore ?? 0) / 9,
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getScoreColor(
                                  _financialScores!.getPiotroskiScoreColor(),
                                ),
                              ),
                              strokeWidth: 8,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_financialScores!.piotroskiScore ?? 0}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getScoreColor(
                                    _financialScores!.getPiotroskiScoreColor(),
                                  ),
                                ),
                              ),
                              Text(
                                '/9',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Legend
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score Ranges:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildScoreRange(
                        '9',
                        'Excellent',
                        'Strong financial health',
                        Colors.green,
                        theme,
                      ),
                      const SizedBox(height: 4),
                      _buildScoreRange(
                        '7-8',
                        'Good',
                        'Solid fundamentals',
                        Colors.lightGreen,
                        theme,
                      ),
                      const SizedBox(height: 4),
                      _buildScoreRange(
                        '4-6',
                        'Fair',
                        'Mixed signals',
                        Colors.orange,
                        theme,
                      ),
                      const SizedBox(height: 4),
                      _buildScoreRange(
                        '0-3',
                        'Weak',
                        'Concerning fundamentals',
                        Colors.red,
                        theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Altman Z-Score Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main heading
                Text(
                  'Altman Z Score',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                // Subheading
                Text(
                  'Bankruptcy Risk',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _financialScores!.altmanZScore?.toStringAsFixed(
                                      1,
                                    ) ??
                                    'N/A',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getScoreColor(
                                    _financialScores!.getAltmanZScoreColor(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _financialScores!.altmanZScore != null &&
                                        _financialScores!.altmanZScore! >= 3.0
                                    ? Icons.shield
                                    : _financialScores!.altmanZScore != null &&
                                          _financialScores!.altmanZScore! >= 1.8
                                    ? Icons.warning
                                    : Icons.dangerous,
                                color: _getScoreColor(
                                  _financialScores!.getAltmanZScoreColor(),
                                ),
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _financialScores!.getAltmanZScoreInterpretation(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getScoreColor(
                          _financialScores!.getAltmanZScoreColor(),
                        ).withOpacity(0.1),
                        border: Border.all(
                          color: _getScoreColor(
                            _financialScores!.getAltmanZScoreColor(),
                          ).withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _financialScores!.altmanZScore != null
                              ? (_financialScores!.altmanZScore! > 3
                                    ? 'A'
                                    : _financialScores!.altmanZScore! > 1.8
                                    ? 'B'
                                    : 'C')
                              : 'N/A',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(
                              _financialScores!.getAltmanZScoreColor(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Legend
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Risk Zones:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildScoreRange(
                        '> 3.0',
                        'Safe Zone',
                        'Low bankruptcy risk',
                        Colors.green,
                        theme,
                      ),
                      const SizedBox(height: 4),
                      _buildScoreRange(
                        '1.8 - 3.0',
                        'Grey Zone',
                        'Moderate risk',
                        Colors.orange,
                        theme,
                      ),
                      const SizedBox(height: 4),
                      _buildScoreRange(
                        '< 1.8',
                        'Distress Zone',
                        'High bankruptcy risk',
                        Colors.red,
                        theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRange(
    String range,
    String quality,
    String description,
    Color color,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$range: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: '$quality - $description',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectorComparisonSection(ThemeData theme) {
    if (_sectorPerformance.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group sectors by exchange for better organization
    final sectorsByExchange = <String, List<SectorPerformance>>{};
    for (final sector in _sectorPerformance) {
      sectorsByExchange.putIfAbsent(sector.exchange, () => []).add(sector);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
                Icons.business_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Sector Performance',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Real-time sector performance across major exchanges',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          ...sectorsByExchange.entries.map((entry) {
            final exchange = entry.key;
            final sectors = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exchange,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sectors
                      .map(
                        (sector) => _buildSectorPerformanceChip(sector, theme),
                      )
                      .toList(),
                ),
                if (entry.key != sectorsByExchange.keys.last)
                  const SizedBox(height: 24),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectorPerformanceChip(
    SectorPerformance sector,
    ThemeData theme,
  ) {
    final color = sector.getPerformanceColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sector.sector,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            sector.formatPercentage(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonSection(ThemeData theme) {
    debugPrint(
      '🔍 Building comparison section. Sector data length: ${_sectorPeData.length}, Industry data length: ${_industryPeData.length}',
    );
    debugPrint('🔍 Financial ratios available: ${_financialRatios.length}');
    if (_financialRatios.isNotEmpty) {
      debugPrint(
        '🔍 Stock P/E ratio: ${_financialRatios.first.priceToEarningsRatio}',
      );
    }

    // Show section if we have either sector or industry data
    if (_sectorPeData.isEmpty && _industryPeData.isEmpty) {
      debugPrint('⚠️ No sector or industry P/E data available, hiding section');
      return const SizedBox.shrink();
    }

    debugPrint(
      '✅ Showing comparison section with ${_sectorPeData.length} sector and ${_industryPeData.length} industry data points',
    );

    // Get the stock's current P/E ratio from financial ratios
    final stockPeRatio = _financialRatios.isNotEmpty
        ? _financialRatios.first.priceToEarningsRatio
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
                'Comparison',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Price to Earnings Subheading
          Text(
            'Price to Earnings',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          // Company P/E Card
          if (stockPeRatio != null && _stockDetail != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_stockDetail!.name}: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    stockPeRatio.toStringAsFixed(1),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Sector Comparison Card (Full Width)
          if (_sectorPeData.isNotEmpty && stockPeRatio != null) ...[
            _buildFullWidthComparisonCard(
              title: _sectorPeData.first.sector,
              value: _sectorPeData.first.pe.toStringAsFixed(1),
              valueType: 'Sector P/E',
              stockValue: stockPeRatio,
              theme: theme,
              isSector: true,
            ),
            const SizedBox(height: 12),
          ],
          // Industry Comparison Card (Full Width)
          if (_industryPeData.isNotEmpty) ...[
            _buildFullWidthComparisonCard(
              title: _industryPeData.first.industry,
              value: _industryPeData.first.pe.toStringAsFixed(1),
              valueType: 'Industry P/E',
              stockValue: stockPeRatio,
              theme: theme,
              isSector: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullWidthComparisonCard({
    required String title,
    required String value,
    required String valueType,
    required double? stockValue,
    required ThemeData theme,
    required bool isSector,
  }) {
    // Calculate percentage difference for P/E comparison
    String? percentageDiff;
    Color? diffColor;
    String? valuationStatus;

    if (stockValue != null) {
      final comparisonValue = double.tryParse(value);
      if (comparisonValue != null) {
        final diff = ((stockValue - comparisonValue) / comparisonValue) * 100;
        percentageDiff = '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%';

        if (diff < 0) {
          diffColor = Colors.green;
          valuationStatus = 'Undervalued';
        } else if (diff > 0) {
          diffColor = Colors.red;
          valuationStatus = 'Overvalued';
        } else {
          diffColor = Colors.grey;
          valuationStatus = 'Fair value';
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Title, Value, ValueType
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  valueType,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Right side: Stock P/E, Percentage, Valuation Status
          if (stockValue != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Stock P/E with symbol
                Text(
                  '${_stockDetail?.symbol ?? 'N/A'}: ${stockValue.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                // Percentage difference
                if (percentageDiff != null && diffColor != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: diffColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      percentageDiff,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: diffColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Valuation status
                  Text(
                    valuationStatus ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: diffColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionBreakdownBars(
    ThemeData theme,
    List<dynamic> trades,
    bool isSenate,
  ) {
    if (trades.isEmpty) return const SizedBox.shrink();

    int buyCount = 0;
    int sellCount = 0;

    for (var trade in trades) {
      if (isSenate ? trade.isBuy : trade.isBuy) {
        buyCount++;
      } else if (isSenate ? trade.isSell : trade.isSell) {
        sellCount++;
      }
    }

    int totalTransactions = buyCount + sellCount;
    if (totalTransactions == 0) return const SizedBox.shrink();

    double buyPercentage = (buyCount / totalTransactions) * 100;
    double sellPercentage = (sellCount / totalTransactions) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Breakdown',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Sales bar (red, left side)
              Expanded(
                flex: sellCount,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${sellPercentage.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              // Buys bar (green, right side)
              Expanded(
                flex: buyCount,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${buyPercentage.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sales ($sellCount)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Buys ($buyCount)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
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

  Widget _buildInsiderTradingSection(ThemeData theme) {
    if (_insiderTrading.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
                Icons.people_alt_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Insider Trading Activity',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Recent executive and director transactions (Form 4 filings)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _buildInsiderTradingChart(theme),
          const SizedBox(height: 20),
          _buildTransactionBreakdownBars(theme, _insiderTrading, false),
          _buildInsiderTradingFilters(theme),
          const SizedBox(height: 16),
          _buildInsiderTradingList(theme),
        ],
      ),
    );
  }

  Widget _buildSenateTradingSection(ThemeData theme) {
    final hasSenateData = _senateTrading.isNotEmpty;
    final hasHouseData = _houseTrading.isNotEmpty;

    if (!hasSenateData && !hasHouseData) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
                _isSenateTradingSelected
                    ? Icons.account_balance_outlined
                    : Icons.home_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _isSenateTradingSelected
                    ? 'Senate Trading Activity'
                    : 'House Trading Activity',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isSenateTradingSelected
                ? 'Congressional stock trading disclosures (Senate Office of Public Records)'
                : 'Congressional stock trading disclosures (House Committee on Ethics)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Toggle Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Senate',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _isSenateTradingSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: _isSenateTradingSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: !_isSenateTradingSelected,
                  onChanged: (value) {
                    setState(() {
                      _isSenateTradingSelected = !value;
                      // Reset batch counts when switching
                      _senateTradesBatchCount = 0;
                      _houseTradesBatchCount = 0;
                    });
                  },
                  activeColor: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Text(
                  'House',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: !_isSenateTradingSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: !_isSenateTradingSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _isSenateTradingSelected
              ? _buildSenateTradingContent(theme)
              : _buildHouseTradingContent(theme),
        ],
      ),
    );
  }

  Widget _buildSenateTradingContent(ThemeData theme) {
    return Column(
      children: [
        _buildSenateTradingChart(theme),
        const SizedBox(height: 20),
        _buildTransactionBreakdownBars(theme, _senateTrading, true),
        _buildSenateTradingFilters(theme),
        const SizedBox(height: 16),
        _buildSenateTradingList(theme),
      ],
    );
  }

  Widget _buildAnalystEstimatesSection(ThemeData theme) {
    if (_analystEstimates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
                'Analyst Estimates',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Wall Street analyst financial projections and consensus estimates',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _buildAnalystEstimatesContent(theme),
        ],
      ),
    );
  }

  Widget _buildGradesConsensusSection(ThemeData theme) {
    if (_gradesConsensus == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
                Icons.thumbs_up_down_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Analyst Recommendations',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Wall Street analyst consensus ratings and recommendations',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _buildGradesConsensusContent(theme),
        ],
      ),
    );
  }

  Widget _buildGradesConsensusContent(ThemeData theme) {
    final consensus = _gradesConsensus!;
    final grades = [
      {
        'label': 'Strong Sell',
        'count': consensus.strongSell,
        'percentage': consensus.strongSellPercentage,
        'color': GradesConsensus.getStrongSellColor(),
      },
      {
        'label': 'Sell',
        'count': consensus.sell,
        'percentage': consensus.sellPercentage,
        'color': GradesConsensus.getSellColor(),
      },
      {
        'label': 'Hold',
        'count': consensus.hold,
        'percentage': consensus.holdPercentage,
        'color': GradesConsensus.getHoldColor(),
      },
      {
        'label': 'Buy',
        'count': consensus.buy,
        'percentage': consensus.buyPercentage,
        'color': GradesConsensus.getBuyColor(),
      },
      {
        'label': 'Strong Buy',
        'count': consensus.strongBuy,
        'percentage': consensus.strongBuyPercentage,
        'color': GradesConsensus.getStrongBuyColor(),
      },
    ];

    return Column(
      children: [
        // Consensus Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Consensus: ',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: consensus.consensusColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  consensus.consensus.toUpperCase(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${consensus.total} analysts)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Vertical Bar Chart
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommendation Breakdown',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: grades.map((grade) {
                      final percentage = grade['percentage'] as double;
                      final count = grade['count'] as int;
                      final color = grade['color'] as Color;
                      final label = grade['label'] as String;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Percentage text
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Count text
                          Text(
                            '$count',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Bar
                          Container(
                            width: 35,
                            height:
                                (percentage / 100) * 180, // Scale to max height
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Label
                          SizedBox(
                            width: 50,
                            child: Text(
                              label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalystEstimatesContent(ThemeData theme) {
    return Column(
      children: [
        // Revenue Estimates Chart
        _buildRevenueEstimatesChart(theme),
        const SizedBox(height: 24),
        // EPS Estimates Chart
        _buildEPSEstimatesChart(theme),
        const SizedBox(height: 24),
        // Estimates Table
        _buildAnalystEstimatesTable(theme),
      ],
    );
  }

  Widget _buildRevenueEstimatesChart(ThemeData theme) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Estimates',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Annual revenue projections with analyst consensus',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        if (value >= 1000000000) {
                          return Text(
                            '\$${(value / 1000000000).toStringAsFixed(1)}B',
                            style: theme.textTheme.bodySmall,
                          );
                        } else if (value >= 1000000) {
                          return Text(
                            '\$${(value / 1000000).toStringAsFixed(1)}M',
                            style: theme.textTheme.bodySmall,
                          );
                        }
                        return Text(
                          '\$${value.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        final reversedEstimates = _analystEstimates.reversed
                            .toList();
                        if (index >= 0 && index < reversedEstimates.length) {
                          return Text(
                            reversedEstimates[index].formattedDate,
                            style: theme.textTheme.bodySmall,
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Average revenue line
                  LineChartBarData(
                    spots: _analystEstimates.reversed
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.revenueAvg,
                          );
                        })
                        .toList(),
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                  ),
                  // High revenue line
                  LineChartBarData(
                    spots: _analystEstimates.reversed
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.revenueHigh,
                          );
                        })
                        .toList(),
                    isCurved: true,
                    color: Colors.green.withOpacity(0.7),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                  // Low revenue line
                  LineChartBarData(
                    spots: _analystEstimates.reversed
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.revenueLow,
                          );
                        })
                        .toList(),
                    isCurved: true,
                    color: Colors.red.withOpacity(0.7),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEPSEstimatesChart(ThemeData theme) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EPS Estimates',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Earnings per share projections with analyst consensus',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toStringAsFixed(1)}',
                          style: theme.textTheme.bodySmall,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        final reversedEstimates = _analystEstimates.reversed
                            .toList();
                        if (index >= 0 && index < reversedEstimates.length) {
                          return Text(
                            reversedEstimates[index].formattedDate,
                            style: theme.textTheme.bodySmall,
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Average EPS line
                  LineChartBarData(
                    spots: _analystEstimates.reversed
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.epsAvg,
                          );
                        })
                        .toList(),
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                  ),
                  // High EPS line
                  LineChartBarData(
                    spots: _analystEstimates.reversed
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.epsHigh,
                          );
                        })
                        .toList(),
                    isCurved: true,
                    color: Colors.green.withOpacity(0.7),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                  // Low EPS line
                  LineChartBarData(
                    spots: _analystEstimates.reversed
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.epsLow,
                          );
                        })
                        .toList(),
                    isCurved: true,
                    color: Colors.red.withOpacity(0.7),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalystEstimatesTable(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expandable Header
          InkWell(
            onTap: () {
              setState(() {
                _isAnalystEstimatesExpanded = !_isAnalystEstimatesExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Detailed Estimates',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isAnalystEstimatesExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(
                    label: Text(
                      'Year',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Revenue',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'EPS',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Analysts',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                rows: _analystEstimates.map((estimate) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          estimate.formattedDate,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AnalystEstimates.formatCurrency(
                                estimate.revenueAvg,
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              estimate.revenueRange,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${estimate.epsAvg.toStringAsFixed(2)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              estimate.epsRange,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${estimate.numAnalystsRevenue}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'revenue',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isAnalystEstimatesExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseTradingContent(ThemeData theme) {
    return Column(
      children: [
        _buildHouseTradingChart(theme),
        const SizedBox(height: 20),
        _buildTransactionBreakdownBars(theme, _houseTrading, true),
        _buildHouseTradingFilters(theme),
        const SizedBox(height: 16),
        _buildHouseTradingList(theme),
      ],
    );
  }

  Widget _buildInsiderTradingChart(ThemeData theme) {
    return Container(
      height: 400, // Increased height to accommodate both charts
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Price & Volume with Insider Trading',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<ChartDataPoint>>(
              future: _fetchStockPriceData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(child: Text('Unable to load price data'));
                }

                final priceData = snapshot.data!;
                final filteredTrades = _getFilteredInsiderTrades();

                return Column(
                  children: [
                    // Price chart (top half)
                    Expanded(
                      flex: 3,
                      child: _buildPriceChartWithInsiderDots(theme, priceData),
                    ),
                    const SizedBox(height: 8),
                    // Volume chart (bottom half)
                    Expanded(
                      flex: 2,
                      child: _buildVolumeChartWithInsiderTrades(
                        theme,
                        priceData,
                        filteredTrades,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Buy',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Sell',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<ChartDataPoint>> _fetchStockPriceData() async {
    if (_stockSymbol == null) return [];

    try {
      final apiKey = dotenv.env['FMP_API_KEY'];
      if (apiKey == null) return [];

      // Fetch 1 year of daily data for better chart visibility
      final url =
          'https://financialmodelingprep.com/api/v3/historical-price-full/$_stockSymbol?from=${DateTime.now().subtract(const Duration(days: 365)).toIso8601String().split('T')[0]}&to=${DateTime.now().toIso8601String().split('T')[0]}&apikey=$apiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('historical')) {
          final historicalData = data['historical'] as List;
          return historicalData
              .map((item) => ChartDataPoint.fromJson(item))
              .toList()
            ..sort(
              (a, b) => a.date.compareTo(b.date),
            ); // Sort by date ascending
        }
      }
    } catch (e) {
      debugPrint('Error fetching stock price data: $e');
    }

    return [];
  }

  Widget _buildPriceChartWithInsiderDots(
    ThemeData theme,
    List<ChartDataPoint> priceData,
  ) {
    if (priceData.isEmpty) {
      return const Center(child: Text('No price data available'));
    }

    // Get filtered insider trading data
    final filteredTrades = _getFilteredInsiderTrades();

    // Convert price data to FlSpot
    final spots = priceData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.price);
    }).toList();

    // Calculate min/max prices
    final prices = priceData.map((p) => p.price);
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.1;

    // Create additional spots for insider trading dots
    final insiderSpots = <FlSpot>[];
    for (final trade in filteredTrades) {
      try {
        final tradeDate = DateTime.parse(trade.transactionDate);
        final dateKey = tradeDate.toIso8601String().split('T')[0];

        // Find the closest price data point
        final pricePoint = priceData.firstWhere(
          (point) => point.date.toIso8601String().split('T')[0] == dateKey,
          orElse: () => priceData
              .last, // Use last available price if exact date not found
        );

        // Find the x position in the chart
        final xIndex = priceData.indexOf(pricePoint);
        if (xIndex >= 0) {
          insiderSpots.add(FlSpot(xIndex.toDouble(), pricePoint.price));
        }
      } catch (e) {
        // Skip trades with invalid dates
        continue;
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: priceRange / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.colorScheme.outline.withOpacity(0.1),
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
              interval: (priceData.length / 4).ceil().toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < priceData.length) {
                  final date = priceData[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
              interval: priceRange / 4,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (priceData.length - 1).toDouble(),
        minY: minPrice - padding,
        maxY: maxPrice + padding,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
          ),
          // Add insider trading dots as a separate line with dots only
          LineChartBarData(
            spots: insiderSpots,
            isCurved: false,
            color: Colors.transparent, // Make line invisible
            barWidth: 0,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final trade =
                    filteredTrades[index %
                        filteredTrades.length]; // Get corresponding trade
                return FlDotCirclePainter(
                  radius: 4,
                  color: trade.isBuy ? Colors.green : Colors.red,
                  strokeWidth: 1,
                  strokeColor: theme.colorScheme.surface,
                );
              },
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots
                  .map((spot) {
                    final index = spot.x.toInt();
                    if (index >= 0 && index < priceData.length) {
                      final point = priceData[index];
                      return LineTooltipItem(
                        '${point.date.month}/${point.date.day}: \$${point.price.toStringAsFixed(2)}',
                        TextStyle(color: theme.colorScheme.onSurface),
                      );
                    }
                    return null;
                  })
                  .whereType<LineTooltipItem>()
                  .toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeChartWithInsiderTrades(
    ThemeData theme,
    List<ChartDataPoint> priceData,
    List<InsiderTrading> filteredTrades,
  ) {
    if (filteredTrades.isEmpty) {
      return const Center(child: Text('No trading volume data'));
    }

    // Use price range for scaling instead of volume normalization
    final prices = priceData.map((point) => point.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    // Create volume data points for bar chart
    final volumeData = <BarChartGroupData>[];
    final maxVolume = filteredTrades.isNotEmpty
        ? filteredTrades
              .map((trade) => trade.securitiesTransacted)
              .reduce((a, b) => a > b ? a : b)
        : 0;

    for (int i = 0; i < filteredTrades.length; i++) {
      final trade = filteredTrades[i];
      final volume = trade.securitiesTransacted.toDouble();

      // Scale volume based on price range for height, with safety checks
      double scaledHeight;
      if (maxVolume > 0 && priceRange > 0) {
        scaledHeight = ((volume / maxVolume) * priceRange * 0.8) + minPrice;
      } else if (maxVolume > 0) {
        // If price range is 0, use a fixed scale
        scaledHeight = (volume / maxVolume) * 100.0;
      } else {
        // If no volume data, use minimum price
        scaledHeight = minPrice;
      }

      volumeData.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: scaledHeight.isFinite ? scaledHeight : minPrice,
              color: trade.isBuy ? Colors.green : Colors.red,
              width: 6,
              borderRadius: trade.isBuy
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(2),
                    )
                  : const BorderRadius.only(
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: priceRange > 0 ? maxPrice + (priceRange * 0.2) : maxPrice + 20,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final trade = filteredTrades[group.x.toInt()];
              final volume = trade.securitiesTransacted;
              return BarTooltipItem(
                '${trade.reportingName}\n${DateTime.parse(trade.transactionDate).month}/${DateTime.parse(trade.transactionDate).day}\nVolume: ${_formatNumber(volume)}\n${trade.isBuy ? 'Buy' : 'Sell'}',
                TextStyle(color: theme.colorScheme.onSurface),
              );
            },
          ),
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
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 &&
                    index < filteredTrades.length &&
                    index % 5 == 0) {
                  // Show every 5th trade date
                  try {
                    final trade = filteredTrades[index];
                    final date = DateTime.parse(trade.transactionDate);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${date.month}/${date.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                    );
                  } catch (e) {
                    return const SizedBox.shrink();
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                // Show price values on left axis
                if (value >= minPrice && value <= maxPrice && value.isFinite) {
                  return Text(
                    '\$${value.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 8,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: priceRange > 0
              ? priceRange / 5
              : 10, // Show 5 grid lines in price range or fallback
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.colorScheme.outline.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: volumeData,
      ),
    );
  }

  List<InsiderTrading> _getFilteredInsiderTrades() {
    return _insiderTrading.where((trade) {
      // Transaction type filter
      if (_insiderTransactionFilter != 'All') {
        if (_insiderTransactionFilter == 'Buy' && !trade.isBuy) return false;
        if (_insiderTransactionFilter == 'Sell' && !trade.isSell) return false;
      }

      return true;
    }).toList();
  }

  Widget _buildInsiderTradingFilters(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _insiderTransactionFilter,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _insiderTransactionFilter = value;
                });
              }
            },
            decoration: InputDecoration(
              labelText: 'Show Transactions',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: ['All', 'Buy', 'Sell'].map((type) {
              return DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: type == 'Buy'
                            ? Colors.green
                            : type == 'Sell'
                            ? Colors.red
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(type),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${_getFilteredInsiderTrades().length} transactions',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildInsiderTradingList(ThemeData theme) {
    final filteredTrades = _getFilteredInsiderTrades();
    final displayCount = 1 + (_insiderTradesBatchCount * 10);
    final displayTrades = filteredTrades.take(displayCount).toList();
    final hasMoreTrades = displayCount < filteredTrades.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            if (_insiderTradesBatchCount > 0)
              TextButton(
                onPressed: () {
                  setState(() {
                    _insiderTradesBatchCount = 0;
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Show Less',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...displayTrades.map(
          (trade) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: trade.getTransactionColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trade.reportingName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      trade.formattedTransactionDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  trade.typeOfOwner,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${trade.isBuy
                            ? "Bought"
                            : trade.isSell
                            ? "Sold"
                            : "Other"} ${trade.securitiesTransacted.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} shares',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: trade.getTransactionColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Price: ${trade.formatPriceWithType()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: trade.price > 0
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                    ),
                    if (trade.price == 0 &&
                        trade.transactionType.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(
                            0.3,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          trade.getTransactionTypeDescription(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (trade.price > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Total: ${_formatCurrency(trade.price * trade.securitiesTransacted)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else if (trade.price == 0 &&
                    (trade.isBuy || trade.isSell)) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Total: Not calculable (no price)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hasMoreTrades) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _insiderTradesBatchCount++;
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Show More (10)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<SenateTrading> _getFilteredSenateTrades() {
    return _senateTrading.where((trade) {
      // Transaction type filter
      if (_senateTransactionFilter != 'All') {
        if (_senateTransactionFilter == 'Buy' && !trade.isBuy) return false;
        if (_senateTransactionFilter == 'Sell' && !trade.isSell) return false;
      }

      return true;
    }).toList();
  }

  List<HouseTrading> _getFilteredHouseTrades() {
    return _houseTrading.where((trade) {
      // Transaction type filter
      if (_houseTransactionFilter != 'All') {
        if (_houseTransactionFilter == 'Buy' && !trade.isBuy) return false;
        if (_houseTransactionFilter == 'Sell' && !trade.isSell) return false;
      }

      return true;
    }).toList();
  }

  Widget _buildSenateTradingList(ThemeData theme) {
    final filteredTrades = _getFilteredSenateTrades();
    final displayCount = 1 + (_senateTradesBatchCount * 10);
    final displayTrades = filteredTrades.take(displayCount).toList();
    final hasMoreTrades = displayCount < filteredTrades.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Disclosures',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            if (_senateTradesBatchCount > 0)
              TextButton(
                onPressed: () {
                  setState(() {
                    _senateTradesBatchCount = 0;
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Show Less',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...displayTrades.map(
          (trade) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: trade.getTransactionColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trade.fullName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      trade.formattedTransactionDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${trade.office} • ${trade.district}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (trade.owner.isNotEmpty && trade.owner != '--') ...[
                  const SizedBox(height: 2),
                  Text(
                    'Owner: ${trade.owner}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${trade.type} • ${trade.formattedAmount}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: trade.getTransactionColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (trade.comment.isNotEmpty && trade.comment != '--') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Comment: ${trade.comment}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (trade.link.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final url = Uri.parse(trade.link);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Text(
                      'View Disclosure →',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hasMoreTrades) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _senateTradesBatchCount++;
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Show More (10)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSenateTradingChart(ThemeData theme) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Price with Senate Trading',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<ChartDataPoint>>(
              future: _fetchStockPriceData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(child: Text('Unable to load price data'));
                }

                return _buildPriceChartWithSenateDots(theme, snapshot.data!);
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Purchase',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Sale',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChartWithSenateDots(
    ThemeData theme,
    List<ChartDataPoint> priceData,
  ) {
    if (priceData.isEmpty) {
      return const Center(child: Text('No price data available'));
    }

    // Get filtered Senate trading data
    final filteredTrades = _getFilteredSenateTrades();

    // Convert price data to FlSpot
    final spots = priceData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.price);
    }).toList();

    // Calculate min/max prices
    final prices = priceData.map((p) => p.price);
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.1;

    // Create additional spots for Senate trading dots
    final senateSpots = <FlSpot>[];
    for (final trade in filteredTrades) {
      try {
        final tradeDate = DateTime.parse(trade.transactionDate);
        final dateKey = tradeDate.toIso8601String().split('T')[0];

        // Find the closest price data point
        final pricePoint = priceData.firstWhere(
          (point) => point.date.toIso8601String().split('T')[0] == dateKey,
          orElse: () => priceData
              .last, // Use last available price if exact date not found
        );

        // Find the x position in the chart
        final xIndex = priceData.indexOf(pricePoint);
        if (xIndex >= 0) {
          senateSpots.add(FlSpot(xIndex.toDouble(), pricePoint.price));
        }
      } catch (e) {
        // Skip trades with invalid dates
        continue;
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: priceRange / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.colorScheme.outline.withOpacity(0.1),
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
              interval: (priceData.length / 4).ceil().toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < priceData.length) {
                  final date = priceData[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
              interval: priceRange / 4,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (priceData.length - 1).toDouble(),
        minY: minPrice - padding,
        maxY: maxPrice + padding,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
          ),
          // Add Senate trading dots as a separate line with dots only
          LineChartBarData(
            spots: senateSpots,
            isCurved: false,
            color: Colors.transparent, // Make line invisible
            barWidth: 0,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final trade =
                    filteredTrades[index %
                        filteredTrades.length]; // Get corresponding trade
                return FlDotCirclePainter(
                  radius: 4,
                  color: trade.isBuy ? Colors.green : Colors.red,
                  strokeWidth: 1,
                  strokeColor: theme.colorScheme.surface,
                );
              },
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots
                  .map((spot) {
                    final index = spot.x.toInt();
                    if (index >= 0 && index < priceData.length) {
                      final point = priceData[index];
                      return LineTooltipItem(
                        '${point.date.month}/${point.date.day}: \$${point.price.toStringAsFixed(2)}',
                        TextStyle(color: theme.colorScheme.onSurface),
                      );
                    }
                    return null;
                  })
                  .whereType<LineTooltipItem>()
                  .toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPriceChartWithHouseDots(
    ThemeData theme,
    List<ChartDataPoint> priceData,
  ) {
    if (priceData.isEmpty) {
      return const Center(child: Text('No price data available'));
    }

    // Get filtered House trading data
    final filteredTrades = _getFilteredHouseTrades();

    // Convert price data to FlSpot
    final spots = priceData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.price);
    }).toList();

    // Calculate min/max prices
    final prices = priceData.map((p) => p.price);
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.1;

    // Create additional spots for House trading dots
    final houseSpots = <FlSpot>[];
    for (final trade in filteredTrades) {
      try {
        final tradeDate = DateTime.parse(trade.transactionDate);
        final dateKey = tradeDate.toIso8601String().split('T')[0];

        // Find the closest price data point
        final pricePoint = priceData.firstWhere(
          (point) => point.date.toIso8601String().split('T')[0] == dateKey,
          orElse: () => priceData
              .last, // Use last available price if exact date not found
        );

        // Find the x position in the chart
        final xIndex = priceData.indexOf(pricePoint);
        if (xIndex >= 0) {
          houseSpots.add(FlSpot(xIndex.toDouble(), pricePoint.price));
        }
      } catch (e) {
        // Skip trades with invalid dates
        continue;
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: priceRange / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.colorScheme.outline.withOpacity(0.1),
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
              interval: (priceData.length / 4).ceil().toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < priceData.length) {
                  final date = priceData[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
              interval: priceRange / 4,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (priceData.length - 1).toDouble(),
        minY: minPrice - padding,
        maxY: maxPrice + padding,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
          ),
          // Add House trading dots as a separate line with dots only
          LineChartBarData(
            spots: houseSpots,
            isCurved: false,
            color: Colors.transparent, // Make line invisible
            barWidth: 0,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final trade =
                    filteredTrades[index %
                        filteredTrades.length]; // Get corresponding trade
                return FlDotCirclePainter(
                  radius: 4,
                  color: trade.isBuy ? Colors.green : Colors.red,
                  strokeWidth: 1,
                  strokeColor: theme.colorScheme.surface,
                );
              },
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots
                  .map((spot) {
                    final index = spot.x.toInt();
                    if (index >= 0 && index < priceData.length) {
                      final point = priceData[index];
                      return LineTooltipItem(
                        '${point.date.month}/${point.date.day}: \$${point.price.toStringAsFixed(2)}',
                        TextStyle(color: theme.colorScheme.onSurface),
                      );
                    }
                    return null;
                  })
                  .whereType<LineTooltipItem>()
                  .toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeChartWithHouseTrades(
    ThemeData theme,
    List<ChartDataPoint> priceData,
    List<HouseTrading> filteredTrades,
  ) {
    if (filteredTrades.isEmpty) {
      return const Center(child: Text('No trading volume data'));
    }

    // Use price range for scaling instead of volume normalization
    final prices = priceData.map((point) => point.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    // Create volume data points for bar chart
    final volumeData = <BarChartGroupData>[];
    final maxVolume = filteredTrades.isNotEmpty
        ? filteredTrades
              .map((trade) => trade.approximateAmount)
              .reduce((a, b) => a > b ? a : b)
        : 0;

    for (int i = 0; i < filteredTrades.length; i++) {
      final trade = filteredTrades[i];
      final volume = trade.approximateAmount;

      // Scale volume based on price range for height, with safety checks
      double scaledHeight;
      if (maxVolume > 0 && priceRange > 0) {
        scaledHeight = ((volume / maxVolume) * priceRange * 0.8) + minPrice;
      } else if (maxVolume > 0) {
        // If price range is 0, use a fixed scale
        scaledHeight = (volume / maxVolume) * 100.0;
      } else {
        // If no volume data, use minimum price
        scaledHeight = minPrice;
      }

      volumeData.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: scaledHeight.isFinite ? scaledHeight : minPrice,
              color: trade.isBuy ? Colors.green : Colors.red,
              width: 6,
              borderRadius: trade.isBuy
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(2),
                    )
                  : const BorderRadius.only(
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxPrice + (priceRange * 0.2),
        minY: minPrice - (priceRange * 0.1),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final trade = filteredTrades[groupIndex];
              return BarTooltipItem(
                '${trade.fullName}\n${trade.formattedAmount}',
                TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < filteredTrades.length) {
                  final trade = filteredTrades[index];
                  try {
                    final date = DateTime.parse(trade.transactionDate);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${date.month}/${date.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                    );
                  } catch (e) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        trade.transactionDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: volumeData,
      ),
    );
  }

  Widget _buildSenateTradingFilters(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _senateTransactionFilter,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _senateTransactionFilter = value;
                });
              }
            },
            decoration: InputDecoration(
              labelText: 'Show Transactions',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: ['All', 'Buy', 'Sell'].map((type) {
              return DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: type == 'Buy'
                            ? Colors.green
                            : type == 'Sell'
                            ? Colors.red
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type == 'Buy'
                          ? 'Purchase'
                          : type == 'Sell'
                          ? 'Sale'
                          : type,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${_getFilteredSenateTrades().length} disclosures',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildHouseTradingChart(ThemeData theme) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Price with House Trading',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<ChartDataPoint>>(
              future: _fetchStockPriceData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(child: Text('Unable to load price data'));
                }

                final priceData = snapshot.data!;
                final filteredTrades = _getFilteredHouseTrades();

                return Column(
                  children: [
                    // Price chart (top half)
                    Expanded(
                      flex: 3,
                      child: _buildPriceChartWithHouseDots(theme, priceData),
                    ),
                    const SizedBox(height: 8),
                    // Volume chart (bottom half)
                    Expanded(
                      flex: 2,
                      child: _buildVolumeChartWithHouseTrades(
                        theme,
                        priceData,
                        filteredTrades,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Buy',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Sell',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHouseTradingFilters(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _houseTransactionFilter,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _houseTransactionFilter = value;
                });
              }
            },
            decoration: InputDecoration(
              labelText: 'Show Transactions',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: ['All', 'Buy', 'Sell'].map((type) {
              return DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: type == 'Buy'
                            ? Colors.green
                            : type == 'Sell'
                            ? Colors.red
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type == 'Buy'
                          ? 'Purchase'
                          : type == 'Sell'
                          ? 'Sale'
                          : type,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${_getFilteredHouseTrades().length} disclosures',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildHouseTradingList(ThemeData theme) {
    final filteredTrades = _getFilteredHouseTrades();
    final displayCount = 1 + (_houseTradesBatchCount * 10);
    final displayTrades = filteredTrades.take(displayCount).toList();
    final hasMoreTrades = displayCount < filteredTrades.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Disclosures',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            if (_houseTradesBatchCount > 0)
              TextButton(
                onPressed: () {
                  setState(() {
                    _houseTradesBatchCount = 0;
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Show Less',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...displayTrades.map(
          (trade) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: trade.getTransactionColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trade.fullName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      trade.formattedTransactionDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${trade.office} • ${trade.district}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (trade.owner.isNotEmpty && trade.owner != '--') ...[
                  const SizedBox(height: 2),
                  Text(
                    'Owner: ${trade.owner}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${trade.type} • ${trade.formattedAmount}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: trade.getTransactionColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (trade.comment.isNotEmpty && trade.comment != '--') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Comment: ${trade.comment}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (trade.link.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final url = Uri.parse(trade.link);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Text(
                      'View Disclosure →',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hasMoreTrades) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _houseTradesBatchCount++;
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Show More (10)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000000) {
      return '\$${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return '\$${amount.toStringAsFixed(0)}';
    }
  }

  String _formatNumber(int amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toString();
    }
  }

  Color _getScoreColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRatiosCategory(
    String title,
    List<Widget> ratios,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: ratios),
        ),
      ],
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
        _fetchCompanyProfile(), // Load company profile first
        _fetchPriceTarget(),
        _fetchDcfAnalysis(),
        _fetchKeyMetrics(),
        _fetchFinancialRatios(),
        _fetchFinancialScores(),
        _fetchSectorPerformance(),
        _fetchInsiderTrading(),
        _fetchSenateTrading(),
        _fetchHouseTrading(),
        _fetchAnalystEstimates(),
        _fetchGradesConsensus(),
        _fetchRevenueSegmentation(),
      ]);

      // Now fetch sector P/E data after company profile is loaded
      await _fetchSectorPeData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  Future<void> _fetchFinancialRatios() async {
    if (_stockSymbol == null) return;

    try {
      final apiService = ApiService();
      _financialRatios = await apiService.getFinancialRatios(
        _stockSymbol!,
        limit: 5,
      );
    } catch (e) {
      debugPrint('Error fetching financial ratios: $e');
    }
  }

  Future<void> _fetchFinancialScores() async {
    if (_stockSymbol == null) return;

    try {
      final apiService = ApiService();
      _financialScores = await apiService.getFinancialScores(_stockSymbol!);
    } catch (e) {
      debugPrint('Error fetching financial scores: $e');
    }
  }

  Future<void> _fetchSectorPerformance() async {
    try {
      final apiService = ApiService();
      _sectorPerformance = await apiService.getSectorPerformance();
    } catch (e) {
      debugPrint('Error fetching sector performance: $e');
    }
  }

  Future<void> _fetchSectorPeData() async {
    debugPrint(
      '📊 _fetchSectorPeData called. Company profile: ${_companyProfile?.sector}',
    );

    // Wait for company profile if not loaded yet
    if (_companyProfile?.sector == null) {
      debugPrint('📊 Company profile not loaded yet, waiting...');
      int retries = 0;
      while (_companyProfile?.sector == null && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
        debugPrint(
          '📊 Retry $retries: Company profile sector: ${_companyProfile?.sector}',
        );
      }

      if (_companyProfile?.sector == null) {
        debugPrint(
          '⚠️ Company profile still not loaded after waiting, cannot fetch sector P/E data',
        );
        return;
      }
    }

    debugPrint('📊 Fetching P/E data for sector: ${_companyProfile!.sector!}');

    try {
      final apiService = ApiService();

      // Get the appropriate date for API call (weekdays only)
      final now = DateTime.now();
      DateTime apiDate = now;

      // If weekend, use last Friday
      if (now.weekday == DateTime.saturday) {
        // Saturday: go back 1 day to Friday
        apiDate = now.subtract(const Duration(days: 1));
      } else if (now.weekday == DateTime.sunday) {
        // Sunday: go back 2 days to Friday
        apiDate = now.subtract(const Duration(days: 2));
      }

      final dateString =
          '${apiDate.year}-${apiDate.month.toString().padLeft(2, '0')}-${apiDate.day.toString().padLeft(2, '0')}';
      debugPrint(
        '📊 Using date for API: $dateString (weekday: ${apiDate.weekday})',
      );

      var allSectorData = await apiService.getSectorPeSnapshot(
        date: dateString,
      );

      // If no data with the calculated date, try without date (latest available)
      if (allSectorData.isEmpty) {
        debugPrint('📊 No data for $dateString, trying without date parameter');
        allSectorData = await apiService.getSectorPeSnapshot();
      }

      // If API returns data, use it
      if (allSectorData.isNotEmpty) {
        debugPrint(
          '📊 Available sectors from API: ${allSectorData.map((d) => d.sector).toSet().toList()}',
        );
        debugPrint(
          '📊 Company sector from profile: "${_companyProfile!.sector!}"',
        );

        _sectorPeData = allSectorData
            .where((data) => data.sector == _companyProfile!.sector!)
            .toList();
        debugPrint('📊 Exact match found ${_sectorPeData.length} records');

        // If no exact match, try case-insensitive match
        if (_sectorPeData.isEmpty) {
          debugPrint('📊 No exact match, trying case-insensitive search');
          _sectorPeData = allSectorData
              .where(
                (data) =>
                    data.sector.toLowerCase() ==
                    _companyProfile!.sector!.toLowerCase(),
              )
              .toList();
          debugPrint(
            '📊 Case-insensitive search found ${_sectorPeData.length} matches',
          );

          // If still no match, try partial match
          if (_sectorPeData.isEmpty) {
            debugPrint('📊 No case-insensitive match, trying partial match');
            _sectorPeData = allSectorData
                .where(
                  (data) =>
                      data.sector.toLowerCase().contains(
                        _companyProfile!.sector!.toLowerCase(),
                      ) ||
                      _companyProfile!.sector!.toLowerCase().contains(
                        data.sector.toLowerCase(),
                      ),
                )
                .toList();
            debugPrint(
              '📊 Partial match found ${_sectorPeData.length} matches',
            );
          }
        }
      } else {
        // Fallback: Use estimated sector P/E ratios
        debugPrint(
          '⚠️ API returned no data, using estimated sector P/E ratios',
        );
        _sectorPeData = _getEstimatedSectorPeData(_companyProfile!.sector!);
      }

      debugPrint('📊 Final _sectorPeData length: ${_sectorPeData.length}');

      if (_sectorPeData.isNotEmpty) {
        debugPrint(
          '📊 Sample P/E data: ${_sectorPeData.first.sector} - ${_sectorPeData.first.pe}',
        );
      } else {
        debugPrint(
          '⚠️ No matching sector data found. Available sectors: ${allSectorData.map((d) => d.sector).toList()}',
        );
      }

      // Fetch industry P/E data if industry is available
      if (_companyProfile!.industry != null) {
        debugPrint(
          '📊 Fetching P/E data for industry: ${_companyProfile!.industry!}',
        );

        var allIndustryData = await apiService.getIndustryPeSnapshot(
          date: dateString,
        );

        // If no data with the calculated date, try without date (latest available)
        if (allIndustryData.isEmpty) {
          debugPrint(
            '📊 No industry data for $dateString, trying without date parameter',
          );
          allIndustryData = await apiService.getIndustryPeSnapshot();
        }

        if (allIndustryData.isNotEmpty) {
          debugPrint(
            '📊 Available industries from API: ${allIndustryData.map((d) => d.industry).toSet().toList()}',
          );
          debugPrint(
            '📊 Company industry from profile: "${_companyProfile!.industry!}"',
          );

          _industryPeData = allIndustryData
              .where((data) => data.industry == _companyProfile!.industry!)
              .toList();
          debugPrint(
            '📊 Exact industry match found ${_industryPeData.length} records',
          );

          // If no exact match, try case-insensitive match
          if (_industryPeData.isEmpty) {
            debugPrint(
              '📊 No exact industry match, trying case-insensitive search',
            );
            _industryPeData = allIndustryData
                .where(
                  (data) =>
                      data.industry.toLowerCase() ==
                      _companyProfile!.industry!.toLowerCase(),
                )
                .toList();
            debugPrint(
              '📊 Case-insensitive industry search found ${_industryPeData.length} matches',
            );

            // If still no match, try partial match
            if (_industryPeData.isEmpty) {
              debugPrint(
                '📊 No case-insensitive industry match, trying partial match',
              );
              _industryPeData = allIndustryData
                  .where(
                    (data) =>
                        data.industry.toLowerCase().contains(
                          _companyProfile!.industry!.toLowerCase(),
                        ) ||
                        _companyProfile!.industry!.toLowerCase().contains(
                          data.industry.toLowerCase(),
                        ),
                  )
                  .toList();
              debugPrint(
                '📊 Partial industry match found ${_industryPeData.length} matches',
              );
            }
          }
        }

        debugPrint(
          '📊 Final _industryPeData length: ${_industryPeData.length}',
        );

        if (_industryPeData.isNotEmpty) {
          debugPrint(
            '📊 Sample industry P/E data: ${_industryPeData.first.industry} - ${_industryPeData.first.pe}',
          );
        } else {
          debugPrint(
            '⚠️ No matching industry data found. Available industries: ${allIndustryData.map((d) => d.industry).toList()}',
          );
        }
      } else {
        debugPrint('📊 No industry data available in company profile');
      }
    } catch (e) {
      debugPrint('❌ Error fetching sector P/E data: $e');
      // Fallback to estimated data
      _sectorPeData = _getEstimatedSectorPeData(_companyProfile!.sector!);
      debugPrint(
        '📊 Using fallback data. Final _sectorPeData length: ${_sectorPeData.length}',
      );
    }
  }

  List<SectorPeData> _getEstimatedSectorPeData(String sector) {
    debugPrint('📊 Getting estimated data for sector: "$sector"');

    // Estimated P/E ratios for common sectors (as of 2024)
    final sectorPeMap = {
      'Technology': 25.0,
      'Healthcare': 20.0,
      'Financial Services': 15.0,
      'Consumer Cyclical': 22.0,
      'Communication Services': 18.0,
      'Industrials': 19.0,
      'Consumer Defensive': 21.0,
      'Energy': 12.0,
      'Utilities': 16.0,
      'Real Estate': 17.0,
      'Materials': 14.0,
      'Basic Materials': 14.0,
    };

    // Try exact match first
    var pe = sectorPeMap[sector];

    // If no exact match, try case-insensitive match
    if (pe == null) {
      final lowerSector = sector.toLowerCase();
      for (final entry in sectorPeMap.entries) {
        if (entry.key.toLowerCase() == lowerSector) {
          pe = entry.value;
          break;
        }
      }
    }

    // If still no match, try partial match
    if (pe == null) {
      final lowerSector = sector.toLowerCase();
      for (final entry in sectorPeMap.entries) {
        if (entry.key.toLowerCase().contains(lowerSector) ||
            lowerSector.contains(entry.key.toLowerCase())) {
          pe = entry.value;
          break;
        }
      }
    }

    // Default P/E ratio if no match found
    pe ??= 18.0;

    debugPrint('📊 Using estimated P/E ratio: $pe for sector: $sector');

    return [
      SectorPeData(
        date: DateTime.now().toIso8601String().split('T')[0],
        sector: sector, // Use the original sector name from company profile
        exchange: 'NYSE',
        pe: pe,
      ),
    ];
  }

  Future<void> _fetchInsiderTrading() async {
    if (_stockSymbol == null) return;

    try {
      final apiService = ApiService();
      _insiderTrading = await apiService.getInsiderTrading(
        _stockSymbol!,
        limit: 100,
      );
    } catch (e) {
      debugPrint('Error fetching insider trading: $e');
    }
  }

  Future<void> _fetchSenateTrading() async {
    if (_stockSymbol == null) return;

    try {
      final apiService = ApiService();
      _senateTrading = await apiService.getSenateTrading(_stockSymbol!);
    } catch (e) {
      debugPrint('Error fetching senate trading: $e');
    }
  }

  Future<void> _fetchHouseTrading() async {
    if (_stockSymbol == null) return;

    try {
      final apiService = ApiService();
      _houseTrading = await apiService.getHouseTrading(_stockSymbol!);
    } catch (e) {
      debugPrint('Error fetching house trading: $e');
    }
  }

  Future<void> _fetchAnalystEstimates() async {
    if (_stockSymbol == null) return;

    try {
      final apiService = ApiService();
      _analystEstimates = await apiService.getAnalystEstimates(_stockSymbol!);
    } catch (e) {
      debugPrint('Error fetching analyst estimates: $e');
    }
  }

  Future<void> _fetchGradesConsensus() async {
    if (_stockSymbol == null) return;

    try {
      final apiService = ApiService();
      _gradesConsensus = await apiService.getGradesConsensus(_stockSymbol!);
    } catch (e) {
      debugPrint('Error fetching grades consensus: $e');
    }
  }

  Future<void> _fetchRevenueSegmentation() async {
    if (_stockSymbol == null) return;

    setState(() => _isRevenueSegmentationLoading = true);

    try {
      final apiService = ApiService();
      _revenueSegmentation = await apiService.getRevenueProductSegmentation(
        _stockSymbol!,
      );
    } catch (e) {
      debugPrint('Error fetching revenue segmentation: $e');
    } finally {
      if (mounted) {
        setState(() => _isRevenueSegmentationLoading = false);
      }
    }
  }

  Future<void> _fetchRevenueGeographicSegmentation() async {
    if (_stockSymbol == null) return;

    setState(() => _isRevenueSegmentationLoading = true);

    try {
      final apiService = ApiService();
      _revenueGeoSegmentation = await apiService
          .getRevenueGeographicSegmentation(_stockSymbol!);
    } catch (e) {
      debugPrint('Error fetching revenue geographic segmentation: $e');
    } finally {
      if (mounted) {
        setState(() => _isRevenueSegmentationLoading = false);
      }
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

        if (mounted) {
          setState(() {
            _isFavorite = false;
          });
        }

        _showMessage('Removed from favorites');
      } else {
        await Supabase.instance.client.from('st_favorites').insert({
          'user_id': user.id,
          'symbol': _stockSymbol!,
        });

        if (mounted) {
          setState(() {
            _isFavorite = true;
          });
        }

        _showMessage('Added to favorites');
      }
    } catch (e) {
      _showMessage('Failed to update favorites', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingFavorite = false;
        });
      }
    }
  }

  void _navigateToComparison() {
    if (_stockDetail == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            StockComparisonScreen(initialStockDetail: _stockDetail!),
      ),
    );
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
    // Split text into words
    final words = text.split(RegExp(r'\s+'));

    // If there are 10 or fewer words, return the whole text
    if (words.length <= 10) {
      return text;
    }

    // Find the first sentence that contains at least 10 words
    final sentences = text.split(RegExp(r'(?<=\.)\s+'));
    String result = '';

    for (final sentence in sentences) {
      result += (result.isEmpty ? '' : ' ') + sentence;
      final wordCount = result.split(RegExp(r'\s+')).length;
      if (wordCount >= 10) {
        return result.trim();
      }
    }

    // If no sentence has 10 words, return the first 10 words
    return words.take(10).join(' ') + (words.length > 10 ? '...' : '');
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

  String _getMarketCapCategory(double marketCap) {
    if (marketCap >= 200000000000) {
      return 'Mega Cap';
    } else if (marketCap >= 10000000000) {
      return 'Large Cap';
    } else if (marketCap >= 2000000000) {
      return 'Mid Cap';
    } else if (marketCap >= 300000000) {
      return 'Small Cap';
    } else if (marketCap >= 50000000) {
      return 'Micro Cap';
    } else {
      return 'Nano Cap';
    }
  }

  Color _getMarketCapCategoryColor(double marketCap) {
    if (marketCap >= 200000000000) {
      return Colors.purple;
    } else if (marketCap >= 10000000000) {
      return Colors.blue;
    } else if (marketCap >= 2000000000) {
      return Colors.green;
    } else if (marketCap >= 300000000) {
      return Colors.orange;
    } else if (marketCap >= 50000000) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  /// Check if the market is currently open
  bool _isMarketOpen(String exchangeName) {
    if (_marketHours.isEmpty) return false;

    // Map exchange names to the ones used in market hours API
    String mappedExchange = exchangeName.toUpperCase();
    switch (mappedExchange) {
      case 'NYSE':
        mappedExchange = 'NYSE';
        break;
      case 'NASDAQ':
        mappedExchange = 'NASDAQ';
        break;
      case 'AMEX':
        mappedExchange = 'AMEX';
        break;
      default:
        // For other exchanges, try to find a match
        break;
    }

    final marketHour = _marketHours.firstWhere(
      (mh) => mh.exchange.toUpperCase() == mappedExchange,
      orElse: () => MarketHours(
        exchange: '',
        name: '',
        openingHour: '',
        closingHour: '',
        timezone: '',
        isMarketOpen: false,
      ),
    );

    return marketHour.isMarketOpen;
  }

  /// Get abbreviated exchange name
  String _getExchangeAbbreviation(String exchangeName) {
    // Handle common exchange names
    switch (exchangeName.toUpperCase()) {
      case 'NEW YORK STOCK EXCHANGE':
        return 'NYSE';
      case 'NASDAQ STOCK MARKET':
        return 'NASDAQ';
      case 'AMERICAN STOCK EXCHANGE':
        return 'AMEX';
      case 'TORONTO STOCK EXCHANGE':
        return 'TSX';
      case 'LONDON STOCK EXCHANGE':
        return 'LSE';
      case 'SHANGHAI STOCK EXCHANGE':
        return 'SSE';
      case 'HONG KONG EXCHANGES AND CLEARING':
        return 'HKEX';
      case 'TOKYO STOCK EXCHANGE':
        return 'TSE';
      default:
        // For unknown exchanges, take first 3-4 characters or split by space
        if (exchangeName.length <= 4) {
          return exchangeName.toUpperCase();
        }
        // Try to take meaningful abbreviation
        final words = exchangeName.split(' ');
        if (words.length >= 2) {
          return '${words[0].substring(0, min(2, words[0].length))}${words[1].substring(0, min(2, words[1].length))}'
              .toUpperCase();
        }
        return exchangeName
            .substring(0, min(4, exchangeName.length))
            .toUpperCase();
    }
  }

  Future<void> _fetchMarketHours() async {
    setState(() {
      _isLoadingMarketHours = true;
    });

    try {
      final apiKey = dotenv.env['FMP_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('FMP API key not found in environment variables');
      }

      final url =
          'https://financialmodelingprep.com/stable/all-exchange-market-hours?apikey=$apiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch market hours: ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(response.body);
      final allMarketHours = data
          .map((item) => MarketHours.fromJson(item))
          .toList();

      // Filter for the specific exchanges: NYSE, NASDAQ, XETRA, NSE, HKSE
      final targetExchanges = ['NYSE', 'NASDAQ', 'XETRA', 'NSE', 'HKSE'];
      final filteredMarketHours = allMarketHours
          .where((market) => targetExchanges.contains(market.exchange))
          .toList();

      setState(() {
        _marketHours = filteredMarketHours;
        _isLoadingMarketHours = false;
      });

      debugPrint(
        'Successfully loaded market hours for ${filteredMarketHours.length} exchanges',
      );
    } catch (e) {
      debugPrint('Error fetching market hours: $e');
      setState(() {
        _isLoadingMarketHours = false;
      });
    }
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
