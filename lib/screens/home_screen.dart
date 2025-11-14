import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../widgets/commodity_card.dart';
import '../widgets/enhanced_stock_card.dart';
import '../screens/commodity_screen.dart';
import '../screens/index_screen.dart';
import '../models/commodity.dart';
import '../models/commodity.dart' show Index;
import '../models/market_hours.dart';
import '../services/api_service.dart';

/// Home screen for StockDrop app
/// Displays top stocks with daily losses using Financial Modeling Prep API
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<StockLoss> _stocks = [];
  bool _isLoading = false;
  String? _error;

  // Load more functionality
  bool _isLoadingMore = false;
  int _currentStockCount = 10;
  bool _hasMoreStocks = true;
  List<StockLoss> _allAvailableStocks =
      []; // Store all available stocks for pagination

  // Index data for home screen cards
  Index? _sp500Index;
  Index? _dowJonesIndex;
  Index? _euroStoxxIndex;
  Index? _nasdaqIndex;
  Index? _russell2000Index;
  Index? _ftseIndex;
  Index? _nikkei225Index;
  Index? _hangSengIndex;
  Index? _vixIndex;
  bool _isLoadingIndexes = true;

  // Market hours data
  List<MarketHours> _marketHours = [];
  bool _isLoadingMarketHours = true;

  @override
  void initState() {
    super.initState();
    _fetchStocks();
    _fetchIndexData();
    _fetchMarketHours();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('StockDrop'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStocks,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: CustomScrollView(
            slivers: [
              // Stock List Header
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_down,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Top 10 Worst Performing Stocks',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_stocks.length} stocks',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Stock List or Loading/Error States
              if (_isLoading && _stocks.isEmpty)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_error != null && _stocks.isEmpty)
                SliverToBoxAdapter(child: _buildErrorWidget(theme))
              else if (_stocks.isEmpty && !_isLoading)
                SliverToBoxAdapter(child: _buildEmptyWidget(theme))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    // Last item is the load more button
                    if (index == _stocks.length) {
                      return _buildLoadMoreButton(theme);
                    }

                    final stock = _stocks[index];
                    return EnhancedStockCard(
                      stock: StockLossAdapter(stock),
                      marketHours: _marketHours,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/detail',
                          arguments: {'symbol': stock.symbol},
                        );
                      },
                    );
                  }, childCount: _stocks.length + (_hasMoreStocks ? 1 : 0)),
                ),

              // Commodities Section
              SliverToBoxAdapter(child: _buildCommoditiesSection(theme)),

              // Indexes Section
              SliverToBoxAdapter(child: _buildIndexesSection(theme)),

              // Market Hours Section
              SliverToBoxAdapter(child: _buildMarketHoursSection(theme)),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the market hours section
  Widget _buildMarketHoursSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Market Hours Heading
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(Icons.schedule, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Market Hours',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        // Market Hours Cards
        if (_isLoadingMarketHours)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            height: 100,
            child: const Center(child: CircularProgressIndicator()),
          )
        else if (_marketHours.isEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            height: 100,
            child: Center(
              child: Text(
                'No market hours data available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: _marketHours
                  .map(
                    (market) => Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _buildMarketHoursCard(theme, market),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  /// Calculate time until market opens or closes
  String _getMarketTimeStatus(MarketHours market) {
    // Check if it's a weekend in the market's timezone
    final nowInMarketTimezone = _getCurrentTimeInTimezone(market.timezone);
    final weekday = nowInMarketTimezone.weekday; // 1 = Monday, 7 = Sunday

    // Check if it's Friday after market close or weekend
    if (weekday == 5) {
      // Friday
      // Check if current time is after closing time
      final currentTime = TimeOfDay.fromDateTime(nowInMarketTimezone);
      final closingTime = _parseTimeString(market.closingHour);
      if (_isTimeAfter(currentTime, closingTime)) {
        return 'Closed (Weekend)';
      }
    } else if (weekday == 6 || weekday == 7) {
      // Saturday or Sunday
      return 'Closed (Weekend)';
    }

    // Always prioritize API's isMarketOpen field - it knows about holidays too
    if (!market.isMarketOpen) {
      // Could be holiday - API handles this
      // Show when it opens next using the opening hour
      try {
        final currentTime = TimeOfDay.fromDateTime(nowInMarketTimezone);
        final openingTime = _parseTimeString(market.openingHour);

        final minutesUntilOpen = _calculateMinutesDifference(
          currentTime,
          openingTime,
        );
        if (minutesUntilOpen <= 60) {
          return 'opens in ${minutesUntilOpen}m';
        } else {
          final hoursUntilOpen = (minutesUntilOpen / 60).round();
          return 'opens in ${hoursUntilOpen}h';
        }
      } catch (e) {
        // If we can't parse the opening time, just show closed
        return 'Closed';
      }
    }

    try {
      // Get current time in the market's time zone
      final nowInMarketTimezone = _getCurrentTimeInTimezone(market.timezone);
      final currentTime = TimeOfDay.fromDateTime(nowInMarketTimezone);

      // Parse opening and closing times using the new parser
      final openingTime = _parseTimeString(market.openingHour);
      final closingTime = _parseTimeString(market.closingHour);

      // Determine if market is currently open based on market's local time
      final isOpen = _isMarketOpenInTimezone(
        currentTime,
        openingTime,
        closingTime,
      );

      print(
        'Market: ${market.name}, Timezone: ${market.timezone}, Current time: $currentTime, Opening: $openingTime, Closing: $closingTime, IsOpen: $isOpen',
      );

      if (isOpen) {
        // Market is open, show time until closing
        final minutesUntilClose = _calculateMinutesDifference(
          currentTime,
          closingTime,
        );
        if (minutesUntilClose <= 60) {
          return 'closes in ${minutesUntilClose}m';
        } else {
          final hoursUntilClose = (minutesUntilClose / 60).round();
          return 'closes in ${hoursUntilClose}h';
        }
      } else {
        // Market is closed, show time until opening
        final minutesUntilOpen = _calculateMinutesDifference(
          currentTime,
          openingTime,
        );
        if (minutesUntilOpen <= 60) {
          return 'opens in ${minutesUntilOpen}m';
        } else {
          final hoursUntilOpen = (minutesUntilOpen / 60).round();
          return 'opens in ${hoursUntilOpen}h';
        }
      }
    } catch (e) {
      print('Error calculating market time status: $e');
      // Fallback if parsing fails
    }

    // Fallback to original display
    return market.isMarketOpen ? 'Open' : 'Closed';
  }

  /// Calculate minutes difference between two TimeOfDay objects
  int _calculateMinutesDifference(TimeOfDay from, TimeOfDay to) {
    final fromMinutes = from.hour * 60 + from.minute;
    final toMinutes = to.hour * 60 + to.minute;

    if (toMinutes >= fromMinutes) {
      return toMinutes - fromMinutes;
    } else {
      // Next day
      return (24 * 60) - fromMinutes + toMinutes;
    }
  }

  /// Check if time1 is after time2
  bool _isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
    final minutes1 = time1.hour * 60 + time1.minute;
    final minutes2 = time2.hour * 60 + time2.minute;
    return minutes1 > minutes2;
  }

  /// Get current time in the specified timezone
  DateTime _getCurrentTimeInTimezone(String timezone) {
    final now = DateTime.now().toUtc();
    final offsetHours = _getTimezoneOffset(timezone);
    return now.add(Duration(minutes: (offsetHours * 60).round()));
  }

  /// Get UTC offset for a timezone (in hours, can be fractional)
  double _getTimezoneOffset(String timezone) {
    // Handle simple offset strings like "+8", "-5", "8", etc.
    final simpleOffsetRegex = RegExp(r'^([+-]?)(\d+)$');
    final simpleMatch = simpleOffsetRegex.firstMatch(timezone);
    if (simpleMatch != null) {
      final sign = (simpleMatch.group(1) == '-') ? -1 : 1;
      final hours = int.parse(simpleMatch.group(2)!);
      print(
        'Timezone $timezone -> ${sign * hours} (parsed from simple offset)',
      );
      return sign * hours.toDouble();
    }

    // Handle direct UTC offset strings like "UTC+8", "UTC+5:30", "+08:00", etc.
    final utcOffsetRegex = RegExp(r'UTC([+-])(\d+)(?::(\d+))?');
    final match = utcOffsetRegex.firstMatch(timezone);
    if (match != null) {
      final sign = match.group(1) == '+' ? 1 : -1;
      final hours = int.parse(match.group(2)!);
      final minutes = match.group(3) != null ? int.parse(match.group(3)!) : 0;
      final offset = hours + (minutes / 60.0);
      print('Timezone $timezone -> ${sign * offset} (parsed from UTC string)');
      return sign * offset;
    }

    // Handle offset strings like "+08:00", "-05:30", etc.
    final offsetRegex = RegExp(r'^([+-])(\d+):(\d+)$');
    final offsetMatch = offsetRegex.firstMatch(timezone);
    if (offsetMatch != null) {
      final sign = offsetMatch.group(1) == '+' ? 1 : -1;
      final hours = int.parse(offsetMatch.group(2)!);
      final minutes = int.parse(offsetMatch.group(3)!);
      final offset = hours + (minutes / 60.0);
      print(
        'Timezone $timezone -> ${sign * offset} (parsed from offset string)',
      );
      return sign * offset;
    }

    // Common timezone mappings with DST handling
    switch (timezone.toLowerCase()) {
      case 'america/new_york':
      case 'us/eastern':
        print(
          'Timezone $timezone -> ${_isDST() ? -4 : -5} (${_isDST() ? "EDT" : "EST"})',
        );
        return _isDST() ? -4 : -5; // EST/EDT
      case 'america/chicago':
      case 'us/central':
        print(
          'Timezone $timezone -> ${_isDST() ? -5 : -6} (${_isDST() ? "CDT" : "CST"})',
        );
        return _isDST() ? -5 : -6; // CST/CDT
      case 'america/denver':
      case 'us/mountain':
        print(
          'Timezone $timezone -> ${_isDST() ? -6 : -7} (${_isDST() ? "MDT" : "MST"})',
        );
        return _isDST() ? -6 : -7; // MST/MDT
      case 'america/los_angeles':
      case 'us/pacific':
        print(
          'Timezone $timezone -> ${_isDST() ? -7 : -8} (${_isDST() ? "PDT" : "PST"})',
        );
        return _isDST() ? -7 : -8; // PST/PDT
      case 'europe/london':
      case 'gb':
      case 'gmt':
        print(
          'Timezone $timezone -> ${_isDST() ? 1 : 0} (${_isDST() ? "BST" : "GMT"})',
        );
        return _isDST() ? 1 : 0; // GMT/BST
      case 'europe/berlin':
      case 'europe/paris':
      case 'europe/rome':
      case 'cet':
        print(
          'Timezone $timezone -> ${_isDST() ? 2 : 1} (${_isDST() ? "CEST" : "CET"})',
        );
        return _isDST() ? 2 : 1; // CET/CEST
      case 'asia/tokyo':
      case 'jst':
        print('Timezone $timezone -> 9 (JST)');
        return 9; // JST
      case 'asia/shanghai':
      case 'asia/hong_kong':
      case 'hong_kong':
      case 'hkt':
      case 'hk':
      case 'cst':
      case '8':
        print('Timezone $timezone -> 8 (CST/HKT)');
        return 8; // CST/HKT
      case 'asia/mumbai':
      case 'asia/kolkata':
      case 'ist':
        print('Timezone $timezone -> 5.5 (IST)');
        return 5.5; // IST (UTC+5:30)
      default:
        print('Timezone $timezone -> 0 (default UTC)');
        return 0; // Default to UTC
    }
  }

  /// Check if currently in Daylight Saving Time (simplified for US/Europe)
  bool _isDST() {
    // DST ended in October 2024, so November 2025 is standard time
    return false;
  }

  /// Build the commodities section at the top with gold, silver, and oil
  Widget _buildCommoditiesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Commodities Heading
        Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Icon(
                Icons.trending_up,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Commodities',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        // Vertically Stacked Commodity Cards
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              // Gold Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildCommodityCard(
                  theme: theme,
                  title: 'GOLD',
                  symbol: 'GCUSD',
                  commodityType: 'gold',
                  icon: Icons.toll,
                  colors: [
                    Colors.amber.withOpacity(0.1),
                    Colors.amber.withOpacity(0.05),
                  ],
                  borderColor: Colors.amber.withOpacity(0.3),
                  iconBackgroundColor: Colors.amber.withOpacity(0.2),
                  iconColor: Colors.amber.shade700,
                  titleColor: Colors.amber.shade700,
                  symbolColor: Colors.amber.shade600,
                  arrowColor: Colors.amber.withOpacity(0.6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CommodityScreen(
                          commodityName: 'Gold',
                          commoditySymbol: 'GCUSD',
                          themeColor: Colors.amber,
                          description:
                              'Track gold commodity prices (GCUSD) with real-time data and historical charts.',
                          marketInfo: 'Gold/USD pair\nCommodity tracking',
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Silver Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildCommodityCard(
                  theme: theme,
                  title: 'SILVER',
                  symbol: 'SIUSD',
                  commodityType: 'silver',
                  icon: Icons.circle,
                  colors: [
                    Colors.grey.withOpacity(0.15),
                    Colors.grey.withOpacity(0.08),
                  ],
                  borderColor: Colors.grey.withOpacity(0.3),
                  iconBackgroundColor: Colors.grey.withOpacity(0.2),
                  iconColor: Colors.grey.shade600,
                  titleColor: Colors.grey.shade700,
                  symbolColor: Colors.grey.shade600,
                  arrowColor: Colors.grey.withOpacity(0.6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CommodityScreen(
                          commodityName: 'Silver',
                          commoditySymbol: 'SIUSD',
                          themeColor: Colors.grey,
                          description:
                              'Track silver commodity prices (SIUSD) with real-time data and historical charts.',
                          marketInfo: 'Silver/USD pair\nCommodity tracking',
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Oil Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _buildCommodityCard(
                  theme: theme,
                  title: 'OIL',
                  symbol: 'BZUSD',
                  commodityType: 'oil',
                  icon: Icons.local_gas_station,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.6),
                  ],
                  borderColor: Colors.black.withOpacity(0.2),
                  iconBackgroundColor: Colors.white.withOpacity(0.2),
                  iconColor: Colors.white,
                  titleColor: Colors.white,
                  symbolColor: Colors.white70,
                  arrowColor: Colors.white.withOpacity(0.6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CommodityScreen(
                          commodityName: 'Oil',
                          commoditySymbol: 'BZUSD',
                          themeColor: Colors.black,
                          description:
                              'Track crude oil commodity prices (BZUSD) with real-time data and historical charts.',
                          marketInfo: 'Oil/USD pair\nCommodity tracking',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build the indexes section with S&P 500, Dow Jones, and Euro Stoxx 50
  Widget _buildIndexesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indexes Heading
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(
                Icons.show_chart,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Market Indexes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        // Vertically Stacked Index Cards
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              // S&P 500 Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildIndexCard(
                  theme: theme,
                  title: 'S&P 500',
                  index: _sp500Index,
                  isLoading: _isLoadingIndexes,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IndexScreen(
                          indexName: 'S&P 500',
                          indexSymbol: '^GSPC',
                          themeColor: Colors.blue,
                          description:
                              'Track the S&P 500 index (^GSPC) with real-time data and historical charts.',
                          marketInfo: 'S&P 500 Index\nLarge-cap stocks',
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Dow Jones Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildIndexCard(
                  theme: theme,
                  title: 'Dow Jones',
                  index: _dowJonesIndex,
                  isLoading: _isLoadingIndexes,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IndexScreen(
                          indexName: 'Dow Jones',
                          indexSymbol: '^DJI',
                          themeColor: Colors.green,
                          description:
                              'Track the Dow Jones Industrial Average (^DJI) with real-time data and historical charts.',
                          marketInfo: 'Dow Jones Index\nIndustrial stocks',
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Euro Stoxx 50 Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildIndexCard(
                  theme: theme,
                  title: 'Euro Stoxx 50',
                  index: _euroStoxxIndex,
                  isLoading: _isLoadingIndexes,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IndexScreen(
                          indexName: 'Euro Stoxx 50',
                          indexSymbol: '^STOXX50E',
                          themeColor: Colors.orange,
                          description:
                              'Track the Euro Stoxx 50 index (^STOXX50E) with real-time data and historical charts.',
                          marketInfo:
                              'Euro Stoxx 50 Index\nEuropean blue-chip stocks',
                        ),
                      ),
                    );
                  },
                ),
              ),

              // NASDAQ Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildIndexCard(
                  theme: theme,
                  title: 'NASDAQ',
                  index: _nasdaqIndex,
                  isLoading: _isLoadingIndexes,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IndexScreen(
                          indexName: 'NASDAQ Composite',
                          indexSymbol: '^IXIC',
                          themeColor: Colors.purple,
                          description:
                              'Track the NASDAQ Composite index (^IXIC) with real-time data and historical charts.',
                          marketInfo: 'NASDAQ Composite\nTechnology stocks',
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Russell 2000 Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildIndexCard(
                  theme: theme,
                  title: 'Russell 2000',
                  index: _russell2000Index,
                  isLoading: _isLoadingIndexes,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IndexScreen(
                          indexName: 'Russell 2000',
                          indexSymbol: '^RUT',
                          themeColor: Colors.teal,
                          description:
                              'Track the Russell 2000 index (^RUT) with real-time data and historical charts.',
                          marketInfo: 'Russell 2000\nSmall-cap stocks',
                        ),
                      ),
                    );
                  },
                ),
              ),

              // FTSE 100 Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildIndexCard(
                  theme: theme,
                  title: 'FTSE 100',
                  index: _ftseIndex,
                  isLoading: _isLoadingIndexes,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IndexScreen(
                          indexName: 'FTSE 100',
                          indexSymbol: '^FTSE',
                          themeColor: Colors.indigo,
                          description:
                              'Track the FTSE 100 index (^FTSE) with real-time data and historical charts.',
                          marketInfo: 'FTSE 100\nUK blue-chip stocks',
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Nikkei 225 Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildIndexCard(
                  theme: theme,
                  title: 'Nikkei 225',
                  index: _nikkei225Index,
                  isLoading: _isLoadingIndexes,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IndexScreen(
                          indexName: 'Nikkei 225',
                          indexSymbol: '^N225',
                          themeColor: Colors.red,
                          description:
                              'Track the Nikkei 225 index (^N225) with real-time data and historical charts.',
                          marketInfo: 'Nikkei 225\nJapanese stocks',
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Hang Seng Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildIndexCard(
                  theme: theme,
                  title: 'Hang Seng',
                  index: _hangSengIndex,
                  isLoading: _isLoadingIndexes,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IndexScreen(
                          indexName: 'Hang Seng',
                          indexSymbol: '^HSI',
                          themeColor: Colors.amber,
                          description:
                              'Track the Hang Seng index (^HSI) with real-time data and historical charts.',
                          marketInfo: 'Hang Seng Index\nHong Kong stocks',
                        ),
                      ),
                    );
                  },
                ),
              ),

              // VIX Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _buildIndexCard(
                  theme: theme,
                  title: 'VIX',
                  index: _vixIndex,
                  isLoading: _isLoadingIndexes,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IndexScreen(
                          indexName: 'VIX',
                          indexSymbol: '^VIX',
                          themeColor: Colors.grey,
                          description:
                              'Track the CBOE Volatility Index (^VIX) with real-time data and historical charts.',
                          marketInfo: 'VIX\nMarket volatility',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndexCard({
    required ThemeData theme,
    required String title,
    required Index? index,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    // Determine border color based on change (grey borders)
    Color borderColor = Colors.grey.shade400;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: 1),
      ),
      color: Colors.black,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Index name on the left
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              // Price and changes on the right
              if (isLoading)
                const SizedBox(
                  width: 60,
                  height: 30,
                  child: Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else if (index != null)
                Row(
                  children: [
                    // Price
                    Text(
                      index.formattedPrice,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Change badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Percentage change badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          child: Text(
                            index.formattedChangePercent,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: index.changePercent >= 0
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Absolute change badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          child: Text(
                            index.formattedChange,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: index.change >= 0
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Container(
                  width: 60,
                  height: 30,
                  alignment: Alignment.center,
                  child: Text(
                    'No Data',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommodityCard({
    required ThemeData theme,
    required String title,
    required String symbol,
    required String commodityType,
    required IconData icon,
    required List<Color> colors,
    required Color borderColor,
    required Color iconBackgroundColor,
    required Color iconColor,
    required Color titleColor,
    required Color symbolColor,
    required Color arrowColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: colors,
            ),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      symbol,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: symbolColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                height: 40,
                child: CommodityCard(
                  commodityType: commodityType,
                  isCompact: true,
                  margin: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: arrowColor),
            ],
          ),
        ),
      ),
    );
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
              'Failed to load stocks',
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
              onPressed: _fetchStocks,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_down, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'No Stock Data Available',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load stock market data at this time. Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchStocks,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: _isLoadingMore
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          : ElevatedButton.icon(
              onPressed: _loadMoreStocks,
              icon: const Icon(Icons.expand_more),
              label: const Text('Load More Stocks'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }

  Future<void> _fetchStocks({int limit = 10, int offset = 0}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiKey = dotenv.env['FMP_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('FMP API key not found in environment variables');
      }

      print('DEBUG: Starting to fetch top 10 worst performing stocks...');

      // Step 1: Use screener to get stocks with good volume and reasonable price
      final screenerUrl =
          'https://financialmodelingprep.com/api/v3/stock-screener'
          '?volumeMoreThan=100000'
          '&priceMoreThan=1'
          '&priceLowerThan=1000'
          '&limit=200'
          '&apikey=$apiKey';

      print('DEBUG: Fetching screener data from: $screenerUrl');
      final screenerResponse = await http.get(Uri.parse(screenerUrl));

      print('DEBUG: Screener response status: ${screenerResponse.statusCode}');
      if (screenerResponse.statusCode != 200) {
        print('DEBUG: Screener response body: ${screenerResponse.body}');
        throw Exception(
          'Failed to fetch stock screener data: ${screenerResponse.statusCode}',
        );
      }

      final List<dynamic> screenerData = json.decode(screenerResponse.body);
      print('DEBUG: Screener data length: ${screenerData.length}');

      if (screenerData.isEmpty) {
        throw Exception('No stocks found in screener');
      }

      // Create a map of screener data by symbol for easy lookup
      final Map<String, dynamic> screenerMap = {};
      for (final item in screenerData) {
        final symbol = item['symbol']?.toString();
        if (symbol != null) {
          screenerMap[symbol] = item;
        }
      }

      // Step 2: Get symbols from screener results
      final symbols = screenerData
          .map((item) => item['symbol']?.toString())
          .where((symbol) => symbol != null)
          .take(100) // Limit to avoid URL length issues
          .join(',');

      print(
        'DEBUG: Getting quotes for ${screenerData.take(100).length} symbols...',
      );

      // Step 3: Get detailed quotes for these stocks
      final quotesUrl =
          'https://financialmodelingprep.com/api/v3/quote/$symbols?apikey=$apiKey';
      final quotesResponse = await http.get(Uri.parse(quotesUrl));

      print('DEBUG: Quotes response status: ${quotesResponse.statusCode}');
      if (quotesResponse.statusCode != 200) {
        print('DEBUG: Quotes response body: ${quotesResponse.body}');
        throw Exception(
          'Failed to fetch stock quotes: ${quotesResponse.statusCode}',
        );
      }

      final List<dynamic> quotesData = json.decode(quotesResponse.body);
      print('DEBUG: Quotes data length: ${quotesData.length}');

      // Step 4: Merge screener and quotes data
      final mergedStocks = quotesData.map((quote) {
        final symbol = quote['symbol']?.toString();
        final screenerInfo = symbol != null ? screenerMap[symbol] : null;

        // Merge the data, with quotes taking precedence for price data
        return <String, dynamic>{
          ...?screenerInfo, // Spread screener data first (beta, sector, marketCap, exchange)
          ...quote, // Spread quotes data (price, changesPercentage, volume)
        };
      }).toList();

      // Step 5: Filter for valid stocks and sort by worst performance
      final validStocks = mergedStocks.where((item) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final volume = (item['volume'] as num?)?.toDouble() ?? 0.0;

        // Basic validation to ensure we have good data
        return price > 0 &&
            volume >
                0; // Don't filter by change percentage, just ensure valid data
      }).toList();

      print('DEBUG: Valid stocks with volume: ${validStocks.length}');

      if (validStocks.isEmpty) {
        throw Exception('No valid stocks found with volume data');
      }

      // Step 5: Sort by worst performance (most negative change first)
      validStocks.sort((a, b) {
        final aChange = (a['changesPercentage'] as num?)?.toDouble() ?? 0.0;
        final bChange = (b['changesPercentage'] as num?)?.toDouble() ?? 0.0;
        return aChange.compareTo(
          bChange,
        ); // Ascending order (most negative first)
      });

      // Step 6: Convert all valid stocks to StockLoss objects for pagination
      final allStockLosses = validStocks
          .map((item) => StockLoss.fromJson(item))
          .toList();

      // Store all available stocks for pagination
      _allAvailableStocks = allStockLosses;

      // Take the requested range
      final topLosers = allStockLosses.skip(offset).take(limit).toList();

      print(
        'DEBUG: Successfully loaded ${topLosers.length} top losing stocks (offset: $offset, limit: $limit, total available: ${allStockLosses.length})',
      );

      setState(() {
        if (offset == 0) {
          // Initial load or refresh
          _stocks = topLosers;
          _currentStockCount = topLosers.length;
          _hasMoreStocks = allStockLosses.length > _currentStockCount;
        } else {
          // Load more - append to existing stocks
          _stocks.addAll(topLosers);
          _currentStockCount += topLosers.length;
          _hasMoreStocks = allStockLosses.length > _currentStockCount;
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('DEBUG: Error fetching stocks: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreStocks() async {
    if (_isLoadingMore || !_hasMoreStocks || _allAvailableStocks.isEmpty)
      return;

    setState(() {
      _isLoadingMore = true;
    });

    // Load more stocks from the stored dataset
    final nextStocks = _allAvailableStocks
        .skip(_currentStockCount)
        .take(10)
        .toList();

    // Simulate network delay for consistency
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _stocks.addAll(nextStocks);
      _currentStockCount += nextStocks.length;
      _hasMoreStocks = _allAvailableStocks.length > _currentStockCount;
      _isLoadingMore = false;
    });
  }

  Future<void> _refreshStocks() async {
    _allAvailableStocks.clear(); // Clear stored data on refresh
    await _fetchStocks();
  }

  Future<void> _fetchIndexData() async {
    setState(() {
      _isLoadingIndexes = true;
    });

    try {
      final apiService = ApiService();

      // Fetch all nine indexes concurrently
      final results = await Future.wait([
        apiService.getIndexPrice('^GSPC'), // S&P 500
        apiService.getIndexPrice('^DJI'), // Dow Jones
        apiService.getIndexPrice('^STOXX50E'), // Euro Stoxx 50
        apiService.getIndexPrice('^IXIC'), // NASDAQ
        apiService.getIndexPrice('^RUT'), // Russell 2000
        apiService.getIndexPrice('^FTSE'), // FTSE 100
        apiService.getIndexPrice('^N225'), // Nikkei 225
        apiService.getIndexPrice('^HSI'), // Hang Seng
        apiService.getIndexPrice('^VIX'), // VIX
      ]);

      setState(() {
        _sp500Index = results[0];
        _dowJonesIndex = results[1];
        _euroStoxxIndex = results[2];
        _nasdaqIndex = results[3];
        _russell2000Index = results[4];
        _ftseIndex = results[5];
        _nikkei225Index = results[6];
        _hangSengIndex = results[7];
        _vixIndex = results[8];
        _isLoadingIndexes = false;
      });

      print('DEBUG: Successfully loaded index data');
    } catch (e) {
      print('DEBUG: Error fetching index data: $e');
      setState(() {
        _isLoadingIndexes = false;
      });
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

      // Filter for the specific exchanges: NYSE, NASDAQ, XETRA, NSE, SSE, LSE
      final targetExchanges = ['NYSE', 'NASDAQ', 'XETRA', 'NSE', 'SSE', 'LSE'];
      final filteredMarketHours = allMarketHours
          .where((market) => targetExchanges.contains(market.exchange))
          .toList();

      // Sort by region: Americas, Europe, Asia
      filteredMarketHours.sort((a, b) {
        final regionOrder = {
          // Americas
          'NYSE': 1,
          'NASDAQ': 2,
          // Europe
          'XETRA': 3,
          'LSE': 4,
          // Asia
          'NSE': 5,
          'SSE': 6,
        };

        final aOrder = regionOrder[a.exchange] ?? 99;
        final bOrder = regionOrder[b.exchange] ?? 99;
        return aOrder.compareTo(bOrder);
      });

      setState(() {
        _marketHours = filteredMarketHours;
        _isLoadingMarketHours = false;
      });

      print(
        'DEBUG: Successfully loaded market hours for ${filteredMarketHours.length} exchanges',
      );
    } catch (e) {
      print('DEBUG: Error fetching market hours: $e');
      setState(() {
        _isLoadingMarketHours = false;
      });
    }
  }

  /// Get formatted current time in market timezone
  String _getCurrentTimeInMarket(MarketHours market) {
    try {
      final nowInMarketTimezone = _getCurrentTimeInTimezone(market.timezone);
      final hour = nowInMarketTimezone.hour;
      final minute = nowInMarketTimezone.minute;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  /// Parse time string in various formats: "HH:MM AM/PM +OFFSET", "HH:MM AM/PM -OFFSET", or "HH:MM"
  TimeOfDay _parseTimeString(String timeString) {
    try {
      // Remove any timezone offset part like "+01:00" or "-05:00"
      final cleanTimeString = timeString.split(' ').take(2).join(' ');

      // Handle format like "09:00 AM" or "05:30 PM"
      final parts = cleanTimeString.split(' ');
      if (parts.length >= 2) {
        final timePart = parts[0]; // "09:00" or "05:30"
        final amPm = parts[1]; // "AM" or "PM"

        final timeParts = timePart.split(':');
        if (timeParts.length >= 2) {
          int hour = int.tryParse(timeParts[0]) ?? 9;
          final minute = int.tryParse(timeParts[1]) ?? 0;

          // Convert to 24-hour format
          if (amPm.toUpperCase() == 'PM' && hour != 12) {
            hour += 12;
          } else if (amPm.toUpperCase() == 'AM' && hour == 12) {
            hour = 0;
          }

          return TimeOfDay(hour: hour, minute: minute);
        }
      }

      // Fallback: try to parse as "HH:MM" (24-hour format)
      final timeParts = timeString.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]) ?? 9;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      print('Error parsing time string "$timeString": $e');
    }

    // Default fallback
    return TimeOfDay(hour: 9, minute: 30);
  }

  /// Check if market is currently open based on timezone
  bool _isMarketCurrentlyOpen(MarketHours market) {
    // Check if it's a weekend in the market's timezone
    final nowInMarketTimezone = _getCurrentTimeInTimezone(market.timezone);
    final weekday = nowInMarketTimezone.weekday; // 1 = Monday, 7 = Sunday

    // Check if it's Friday after market close or weekend
    if (weekday == 5) {
      // Friday
      // Check if current time is after closing time
      final currentTime = TimeOfDay.fromDateTime(nowInMarketTimezone);
      final closingTime = _parseTimeString(market.closingHour);
      if (_isTimeAfter(currentTime, closingTime)) {
        return false;
      }
    } else if (weekday == 6 || weekday == 7) {
      // Saturday or Sunday
      return false;
    }

    // Always prioritize API's isMarketOpen field - it knows about holidays too
    if (!market.isMarketOpen) {
      return false;
    }

    try {
      // Get current time in the market's time zone
      final nowInMarketTimezone = _getCurrentTimeInTimezone(market.timezone);
      final currentTime = TimeOfDay.fromDateTime(nowInMarketTimezone);

      // Parse opening and closing times using the new parser
      final openingTime = _parseTimeString(market.openingHour);
      final closingTime = _parseTimeString(market.closingHour);

      return _isMarketOpenInTimezone(currentTime, openingTime, closingTime);
    } catch (e) {
      // If parsing fails, fall back to API data
      return market.isMarketOpen;
    }
  }

  /// Check if market is open based on current time in market's timezone
  bool _isMarketOpenInTimezone(
    TimeOfDay current,
    TimeOfDay open,
    TimeOfDay close,
  ) {
    final currentMinutes = current.hour * 60 + current.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
  }

  Widget _buildMarketHoursCard(ThemeData theme, MarketHours market) {
    final isCurrentlyOpen = _isMarketCurrentlyOpen(market);
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentlyOpen ? Colors.green : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Market status indicator
            Icon(
              isCurrentlyOpen ? Icons.wb_sunny : Icons.nightlight_round,
              size: 16,
              color: isCurrentlyOpen ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),

            // Market info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        market.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getMarketTimeStatus(market),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        market.timezone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getCurrentTimeInMarket(market),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Exchange code
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                market.exchange,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Model class for stock with comprehensive data
class StockLoss {
  final String symbol;
  final String name;
  final double price;
  final double changesPercentage;
  final double volume;
  final double? beta;
  final String? sector;
  final double? marketCap;
  final String? exchange;
  final String? country;
  final double? lastAnnualDividend;
  final double? yearHigh;
  final double? yearLow;

  StockLoss({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changesPercentage,
    required this.volume,
    this.beta,
    this.sector,
    this.marketCap,
    this.exchange,
    this.country,
    this.lastAnnualDividend,
    this.yearHigh,
    this.yearLow,
  });

  factory StockLoss.fromJson(Map<String, dynamic> json) {
    return StockLoss(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      changesPercentage: (json['changesPercentage'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      beta: (json['beta'] as num?)?.toDouble(),
      sector: json['sector']?.toString(),
      marketCap: (json['marketCap'] as num?)?.toDouble(),
      exchange: json['exchange']?.toString(),
      country: json['country']?.toString(),
      lastAnnualDividend: (json['lastAnnualDividend'] as num?)?.toDouble(),
      yearHigh: (json['yearHigh'] as num?)?.toDouble(),
      yearLow: (json['yearLow'] as num?)?.toDouble(),
    );
  }
}
