import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/enhanced_stock_card.dart';
import '../models/market_hours.dart';

/// Favorites screen for StockDrop app
/// Displays user's favorited stocks with real-time updates from Supabase
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteStock> _favoriteStocks = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _favoritesSubscription;
  Timer? _priceUpdateTimer;

  // Market hours data
  List<MarketHours> _marketHours = [];
  bool _isLoadingMarketHours = true;

  @override
  void initState() {
    super.initState();
    _setupFavoritesStream();
    _startPriceUpdateTimer();
    _fetchMarketHours();
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    _priceUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget(theme);
    }

    if (_favoriteStocks.isEmpty) {
      return _buildEmptyWidget(theme);
    }

    return _buildFavoritesList(theme);
  }

  Widget _buildFavoritesList(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _refreshStockPrices,
      child: ListView.builder(
        itemCount: _favoriteStocks.length,
        padding: const EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        itemBuilder: (context, index) {
          final stock = _favoriteStocks[index];

          return Stack(
            children: [
              EnhancedStockCard(
                stock: stock,
                marketHours: _marketHours,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/detail',
                    arguments: {'symbol': stock.symbol},
                  );
                },
              ),
              Positioned(
                bottom: 2,
                right: 32,
                child: IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  color: theme.colorScheme.error,
                  onPressed: () => _showDeleteConfirmation(stock),
                ),
              ),
            ],
          );
        },
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
              'Failed to Load Favorites',
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
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
                _setupFavoritesStream();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
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
            Icon(
              Icons.favorite_border,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Favorites Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for stocks and add them to your favorites to see them here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/search'),
              icon: const Icon(Icons.search),
              label: const Text('Search Stocks'),
            ),
          ],
        ),
      ),
    );
  }

  void _setupFavoritesStream() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'User not authenticated';
        _isLoading = false;
      });
      return;
    }

    _favoritesSubscription = Supabase.instance.client
        .from('st_favorites')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('added_at', ascending: false)
        .listen(
          (List<Map<String, dynamic>> data) {
            _handleFavoritesUpdate(data);
          },
          onError: (error) {
            setState(() {
              _error = 'Failed to load favorites: $error';
              _isLoading = false;
            });
          },
        );
  }

  Future<void> _handleFavoritesUpdate(
    List<Map<String, dynamic>> favoritesData,
  ) async {
    if (favoritesData.isEmpty) {
      setState(() {
        _favoriteStocks = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final symbols = favoritesData
          .map((item) => item['symbol'] as String)
          .toList();

      final stockDetails = await _fetchStockDetails(symbols);

      setState(() {
        _favoriteStocks = stockDetails;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch stock details: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<FavoriteStock>> _fetchStockDetails(List<String> symbols) async {
    if (symbols.isEmpty) return [];

    final apiKey = dotenv.env['FMP_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('FMP API key not found in environment variables');
    }

    final symbolString = symbols.join(',');

    // Get detailed quotes for price and change data
    final quotesUrl =
        'https://financialmodelingprep.com/api/v3/quote/$symbolString?apikey=$apiKey';
    final quotesResponse = await http.get(Uri.parse(quotesUrl));

    if (quotesResponse.statusCode == 200) {
      final List<dynamic> quotesData = json.decode(quotesResponse.body);

      // Get profile data individually for each stock (stable/profile uses query params)
      final profileFutures = symbols.map((symbol) async {
        final profileUrl =
            'https://financialmodelingprep.com/stable/profile?symbol=$symbol&apikey=$apiKey';
        final response = await http.get(Uri.parse(profileUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data.isNotEmpty ? data[0] : null; // Profile API returns array
        }
        return null;
      });

      final profileResults = await Future.wait(profileFutures);

      // Create maps for easy lookup
      final quotesMap = {for (var quote in quotesData) quote['symbol']: quote};
      final profilesMap = {
        for (int i = 0; i < symbols.length; i++) symbols[i]: profileResults[i],
      };

      // Combine quote and profile data
      return symbols.map((symbol) {
        final quote = quotesMap[symbol];
        final profile = profilesMap[symbol];
        return FavoriteStock.fromJson(quote ?? {}, profile);
      }).toList();
    } else {
      throw Exception(
        'Failed to fetch stock details: ${quotesResponse.statusCode}',
      );
    }
  }

  void _startPriceUpdateTimer() {
    _priceUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_favoriteStocks.isNotEmpty) {
        _refreshStockPrices();
      }
    });
  }

  Future<void> _refreshStockPrices() async {
    if (_favoriteStocks.isEmpty) return;

    try {
      final symbols = _favoriteStocks.map((stock) => stock.symbol).toList();
      final updatedStocks = await _fetchStockDetails(symbols);

      setState(() {
        _favoriteStocks = updatedStocks;
      });
    } catch (e) {
      debugPrint('Error refreshing stock prices: $e');
    }
  }

  void _showDeleteConfirmation(FavoriteStock stock) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Favorite'),
        content: Text(
          'Are you sure you want to remove ${stock.symbol} from your favorites?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFavorite(stock.symbol);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFavorite(String symbol) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('st_favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('symbol', symbol);

      _showMessage('Removed from favorites');
    } catch (e) {
      _showMessage('Failed to remove favorite', isError: true);
      debugPrint('Error deleting favorite: $e');
    }
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
}

/// Model class for favorite stock with market data
class FavoriteStock implements StockData {
  @override
  String get symbol => _symbol;
  @override
  String get name => _name;
  @override
  double get price => _price;
  @override
  double get changePercentValue => _changePercentValue;
  @override
  double? get beta => _beta;
  @override
  String? get sector => _sector;
  @override
  double? get marketCap => _marketCap;
  @override
  String? get exchangeShortName => _exchangeShortName;
  @override
  String? get country => _country;

  @override
  double? get lastAnnualDividend => _lastAnnualDividend;

  @override
  double? get yearHigh => _yearHigh;

  @override
  double? get yearLow => _yearLow;

  final String _symbol;
  final String _name;
  final double _price;
  final double _changePercentValue;
  final double? _beta;
  final String? _sector;
  final double? _marketCap;
  final String? _exchangeShortName;
  final String? _country;
  final double? _lastAnnualDividend;
  final double? _yearHigh;
  final double? _yearLow;

  FavoriteStock({
    required String symbol,
    required String name,
    required double? price,
    double? changesPercentage,
    String? exchangeShortName,
    double? beta,
    String? sector,
    double? marketCap,
    String? country,
    double? lastAnnualDividend,
    double? yearHigh,
    double? yearLow,
  }) : _symbol = symbol,
       _name = name,
       _price = price ?? 0.0,
       _changePercentValue = changesPercentage ?? 0.0,
       _beta = beta,
       _sector = sector,
       _marketCap = marketCap,
       _exchangeShortName = exchangeShortName,
       _country = country,
       _lastAnnualDividend = lastAnnualDividend,
       _yearHigh = yearHigh,
       _yearLow = yearLow;

  factory FavoriteStock.fromJson(
    Map<String, dynamic> quoteJson, [
    Map<String, dynamic>? profileJson,
  ]) {
    // Use profile data for beta/sector/marketCap/country if available
    final beta = profileJson != null
        ? (profileJson['beta'] as num?)?.toDouble()
        : (quoteJson['beta'] as num?)?.toDouble(); // Fallback to quote data

    final sector = profileJson != null
        ? profileJson['sector'] as String?
        : null;

    final marketCap = profileJson != null
        ? (profileJson['mktCap'] as num?)?.toDouble() ??
              (profileJson['marketCap'] as num?)?.toDouble()
        : null;

    final country = profileJson != null
        ? profileJson['country'] as String?
        : quoteJson['country'] as String?; // Fallback to quote data

    final lastAnnualDividend = profileJson != null
        ? (profileJson['lastDividend'] as num?)?.toDouble() ??
              (profileJson['lastAnnualDividend'] as num?)?.toDouble() ??
              (quoteJson['lastAnnualDividend'] as num?)?.toDouble() ??
              (quoteJson['lastDividend'] as num?)?.toDouble()
        : (quoteJson['lastAnnualDividend'] as num?)?.toDouble() ??
              (quoteJson['lastDividend'] as num?)?.toDouble();

    final yearHigh = (quoteJson['yearHigh'] as num?)?.toDouble();
    final yearLow = (quoteJson['yearLow'] as num?)?.toDouble();

    return FavoriteStock(
      symbol: quoteJson['symbol']?.toString() ?? '',
      name: quoteJson['name']?.toString() ?? '',
      price: (quoteJson['price'] as num?)?.toDouble(),
      changesPercentage: (quoteJson['changesPercentage'] as num?)?.toDouble(),
      exchangeShortName: quoteJson['exchange']?.toString(),
      beta: beta,
      country: country,
      sector: sector,
      marketCap: marketCap,
      lastAnnualDividend: lastAnnualDividend,
      yearHigh: yearHigh,
      yearLow: yearLow,
    );
  }
}
