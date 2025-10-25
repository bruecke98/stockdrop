import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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

  // Additional filter options
  double _minMarketCap = 500; // in millions
  double _minVolume = 500; // in thousands
  double _minPrice = 1.0;
  double _maxPrice = 1000.0;

  final List<double> _thresholdOptions = [
    1.0,
    2.0,
    3.0,
    5.0,
    7.5,
    10.0,
    15.0,
    20.0,
  ];
  final List<double> _marketCapOptions = [
    100,
    500,
    1000,
    5000,
    10000,
  ]; // millions
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
              // Loss Threshold
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Min Loss',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<double>(
                          value: _lossThreshold,
                          isExpanded: true,
                          items: _thresholdOptions.map((double value) {
                            return DropdownMenuItem<double>(
                              value: value,
                              child: Text('${value}%'),
                            );
                          }).toList(),
                          onChanged: (double? newValue) {
                            if (newValue != null &&
                                newValue != _lossThreshold) {
                              setState(() {
                                _lossThreshold = newValue;
                              });
                              _fetchStocks();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Market Cap
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Market Cap',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<double>(
                          value: _minMarketCap,
                          isExpanded: true,
                          items: _marketCapOptions.map((double value) {
                            return DropdownMenuItem<double>(
                              value: value,
                              child: Text('${value.toInt()}M+'),
                            );
                          }).toList(),
                          onChanged: (double? newValue) {
                            if (newValue != null && newValue != _minMarketCap) {
                              setState(() {
                                _minMarketCap = newValue;
                              });
                              _fetchStocks();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Quick Filter Button
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick',
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
                        child: const Icon(Icons.more_horiz, size: 18),
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
                    const SizedBox(width: 12),
                    Text(
                      'MCap: ${_formatMarketCap(stock.marketCap)}',
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
          '?marketCapMoreThan=${(_minMarketCap * 1000000).toInt()}'
          '&volumeMoreThan=${(_minVolume * 1000).toInt()}'
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

  String _formatMarketCap(double marketCap) {
    if (marketCap >= 1000000000) {
      return '${(marketCap / 1000000000).toStringAsFixed(1)}B';
    } else if (marketCap >= 1000000) {
      return '${(marketCap / 1000000).toStringAsFixed(1)}M';
    }
    return '${marketCap.toStringAsFixed(0)}';
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
  final double marketCap;

  StockLoss({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changesPercentage,
    required this.volume,
    required this.marketCap,
  });

  factory StockLoss.fromJson(Map<String, dynamic> json) {
    return StockLoss(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      changesPercentage: (json['changesPercentage'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      marketCap: (json['marketCap'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
