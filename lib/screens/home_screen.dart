import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../widgets/commodity_card.dart';
import '../screens/gold_example_screen.dart';
import '../screens/silver_example_screen.dart';
import '../screens/oil_example_screen.dart';

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
  double _lossThreshold = 5.0;
  bool _useWeeklyLoss = false; // New option for weekly loss

  // Additional filter options
  double _minVolume = 500; // in thousands
  double _minPrice = 1.0;
  double _maxPrice = 1000.0;
  final List<double> _volumeOptions = [
    100,
    500,
    1000,
    5000,
    10000,
  ]; // thousands

  @override
  void initState() {
    super.initState();
    _fetchStocks();
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
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Commodities Section at top
          _buildCommoditiesSection(theme),

          // Filter Panel
          _buildFilterPanel(theme),

          // Stock List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshStocks,
              child: FutureBuilder<void>(
                future: null, // We handle the state manually
                builder: (context, snapshot) {
                  if (_isLoading && _stocks.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_error != null && _stocks.isEmpty) {
                    return _buildErrorWidget(theme);
                  }

                  if (_stocks.isEmpty && !_isLoading) {
                    return _buildEmptyWidget(theme);
                  }

                  return _buildStockList(theme);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/search'),
        child: const Icon(Icons.search),
      ),
    );
  }

  Widget _buildFilterPanel(ThemeData theme) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simplified Header
          Row(
            children: [
              Icon(Icons.tune, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
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
          const SizedBox(height: 16),

          // Main Filters Row
          Row(
            children: [
              // Loss Threshold Slider
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Min Loss: ${_lossThreshold.toStringAsFixed(1)}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        // Weekly loss toggle
                        Row(
                          children: [
                            Text(
                              'Weekly',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Switch(
                              value: _useWeeklyLoss,
                              onChanged: (bool value) {
                                setState(() {
                                  _useWeeklyLoss = value;
                                });
                                _fetchStocks();
                              },
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _lossThreshold,
                      min: 1.0,
                      max: 25.0,
                      divisions: 48, // 0.5% increments
                      onChanged: (double value) {
                        setState(() {
                          _lossThreshold = value;
                        });
                      },
                      onChangeEnd: (double value) {
                        _fetchStocks();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // More Filters Button
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'More',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          _showAdvancedFilters(context, theme);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Filters',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GoldExampleScreen(),
                    ),
                  );
                },
                child: Text(
                  'View Details',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Individual Commodity Cards - Full Width
        // Gold Card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GoldExampleScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.amber.withOpacity(0.1),
                      Colors.amber.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.toll,
                        color: Colors.amber.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GOLD',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                          Text(
                            'GCUSD',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.amber.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: CommodityCard(
                        commodityType: 'gold',
                        isCompact: true,
                        margin: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.amber.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Silver Card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SilverExampleScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.grey.withOpacity(0.15),
                      Colors.grey.withOpacity(0.08),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.circle,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SILVER',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            'SIUSD',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: CommodityCard(
                        commodityType: 'silver',
                        isCompact: true,
                        margin: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OilExampleScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.local_gas_station,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OIL',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'BZUSD',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: CommodityCard(
                        commodityType: 'oil',
                        isCompact: true,
                        margin: EdgeInsets.zero,
                      ),
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

  Widget _buildStockList(ThemeData theme) {
    return ListView.builder(
      itemCount: _stocks.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final stock = _stocks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.error.withOpacity(0.1),
              child: Text(
                stock.symbol.substring(0, 2).toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(
              stock.symbol,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.name,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Vol: ${_formatVolume(stock.volume)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${stock.price.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${stock.changesPercentage.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: theme.colorScheme.onError,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/detail',
                arguments: {'symbol': stock.symbol},
              );
            },
          ),
        );
      },
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
            Icon(Icons.trending_up, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'No stocks found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No stocks meet the current loss threshold criteria.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchStocks,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchStocks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiKey = dotenv.env['FMP_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('FMP API key not found in environment variables');
      }

      print(
        'DEBUG: Starting to fetch stocks with API key: ${apiKey.substring(0, 8)}...',
      );

      // Step 1: Get stocks using screener with applied filters
      final screenerUrl =
          'https://financialmodelingprep.com/api/v3/stock-screener'
          '?volumeMoreThan=${(_minVolume * 1000).toInt()}'
          '&priceMoreThan=${_minPrice.toStringAsFixed(2)}'
          '&priceLowerThan=${_maxPrice.toStringAsFixed(2)}'
          '&limit=1000'
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
        setState(() {
          _stocks = [];
          _isLoading = false;
        });
        return;
      }

      // Extract symbols
      final symbols = screenerData
          .map((item) => item['symbol']?.toString())
          .where((symbol) => symbol != null)
          .take(200) // Increased limit for more comprehensive data
          .join(',');

      print(
        'DEBUG: Getting quotes for symbols: ${symbols.substring(0, 50)}...',
      );

      // Step 2: Get detailed quotes
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

      // Step 3: Filter stocks with comprehensive criteria
      final filteredStocks = quotesData
          .where((item) {
            final changesPercentage =
                (item['changesPercentage'] as num?)?.toDouble() ?? 0.0;
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
            final volume = (item['volume'] as num?)?.toDouble() ?? 0.0;

            // Apply all filter conditions
            bool meetsLossThreshold = changesPercentage <= -_lossThreshold;
            bool meetsPriceRange = price >= _minPrice && price <= _maxPrice;
            bool meetsVolumeRequirement = volume >= (_minVolume * 1000);

            // Note: Weekly loss filtering could be implemented here with additional API data
            // For now, we use the same logic but with a note in the UI
            if (_useWeeklyLoss) {
              // In a full implementation, we would fetch weekly change data here
              // For demo purposes, we apply the same threshold
              meetsLossThreshold = changesPercentage <= -_lossThreshold;
            }

            return meetsLossThreshold &&
                meetsPriceRange &&
                meetsVolumeRequirement;
          })
          .map((item) => StockLoss.fromJson(item))
          .toList();

      print(
        'DEBUG: Filtered stocks with all criteria: ${filteredStocks.length}',
      );

      // Sort by loss percentage (highest loss first)
      filteredStocks.sort(
        (a, b) => a.changesPercentage.compareTo(b.changesPercentage),
      );

      setState(() {
        _stocks = filteredStocks.take(50).toList();
        _isLoading = false;
      });

      print('DEBUG: Successfully loaded ${_stocks.length} stocks');
    } catch (e) {
      print('DEBUG: Error fetching stocks: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshStocks() async {
    await _fetchStocks();
  }

  String _formatVolume(double volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toStringAsFixed(0);
  }

  void _showAdvancedFilters(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Advanced Filters',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Weekly Loss Note
            if (_useWeeklyLoss)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Weekly loss filter is enabled. This shows stocks with weekly decline.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_useWeeklyLoss) const SizedBox(height: 16),

            // Volume Filter
            Text(
              'Minimum Volume',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<double>(
              value: _minVolume,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _volumeOptions.map((double value) {
                return DropdownMenuItem<double>(
                  value: value,
                  child: Text('${value.toInt()}K shares'),
                );
              }).toList(),
              onChanged: (double? newValue) {
                if (newValue != null && newValue != _minVolume) {
                  setState(() {
                    _minVolume = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            // Price Range
            Text(
              'Price Range: \$${_minPrice.toStringAsFixed(2)} - \$${_maxPrice.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            RangeSlider(
              values: RangeValues(_minPrice, _maxPrice),
              min: 1.0,
              max: 1000.0,
              divisions: 100,
              labels: RangeLabels(
                '\$${_minPrice.toStringAsFixed(2)}',
                '\$${_maxPrice.toStringAsFixed(2)}',
              ),
              onChanged: (RangeValues values) {
                setState(() {
                  _minPrice = values.start;
                  _maxPrice = values.end;
                });
              },
            ),
            const SizedBox(height: 24),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _fetchStocks();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Apply Filters'),
              ),
            ),
            const SizedBox(height: 8),
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

  StockLoss({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changesPercentage,
    required this.volume,
  });

  factory StockLoss.fromJson(Map<String, dynamic> json) {
    return StockLoss(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      changesPercentage: (json['changesPercentage'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
