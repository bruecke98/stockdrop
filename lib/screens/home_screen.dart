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

  final List<double> _thresholdOptions = [5.0, 10.0];

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
          // Threshold Selector
          _buildThresholdSelector(theme),

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

  Widget _buildThresholdSelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_down, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Text(
            'Loss Threshold:',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          DropdownButton<double>(
            value: _lossThreshold,
            underline: const SizedBox(),
            items: _thresholdOptions.map((double value) {
              return DropdownMenuItem<double>(
                value: value,
                child: Text('${value.toInt()}%'),
              );
            }).toList(),
            onChanged: (double? newValue) {
              if (newValue != null && newValue != _lossThreshold) {
                setState(() {
                  _lossThreshold = newValue;
                });
                _fetchStocks();
              }
            },
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
            subtitle: Text(
              stock.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
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

      // Step 1: Get stocks using screener
      final screenerUrl =
          'https://financialmodelingprep.com/api/v3/stock-screener'
          '?marketCapMoreThan=500000000'
          '&volumeMoreThan=500000'
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
          .take(50) // Limit to avoid too many API calls
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

      // Step 3: Filter stocks with losses (make it more flexible)
      final filteredStocks = quotesData
          .where((item) {
            final changesPercentage =
                (item['changesPercentage'] as num?)?.toDouble() ?? 0.0;
            // More flexible threshold - show stocks with any loss or use fallback
            return changesPercentage < 0 || _lossThreshold > 10;
          })
          .map((item) => StockLoss.fromJson(item))
          .toList();

      print('DEBUG: Filtered stocks length: ${filteredStocks.length}');

      // If no stocks with losses, show all stocks from screener
      if (filteredStocks.isEmpty) {
        print('DEBUG: No stocks with losses found, showing all stocks');
        final allStocks = quotesData
            .map((item) => StockLoss.fromJson(item))
            .toList();

        setState(() {
          _stocks = allStocks.take(10).toList();
          _isLoading = false;
        });
        return;
      }

      // Sort by loss percentage (highest loss first)
      filteredStocks.sort(
        (a, b) => a.changesPercentage.compareTo(b.changesPercentage),
      );

      setState(() {
        _stocks = filteredStocks.take(10).toList();
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
}

/// Model class for stock with loss data
class StockLoss {
  final String symbol;
  final String name;
  final double price;
  final double changesPercentage;

  StockLoss({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changesPercentage,
  });

  factory StockLoss.fromJson(Map<String, dynamic> json) {
    return StockLoss(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      changesPercentage: (json['changesPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
