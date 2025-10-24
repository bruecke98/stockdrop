import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _setupFavoritesStream();
    _startPriceUpdateTimer();
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
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final stock = _favoriteStocks[index];
          final isPositive = (stock.changesPercentage ?? 0) >= 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  stock.symbol.length >= 2
                      ? stock.symbol.substring(0, 2).toUpperCase()
                      : stock.symbol.toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        stock.price != null
                            ? '\$${stock.price!.toStringAsFixed(2)}'
                            : 'N/A',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (stock.changesPercentage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isPositive ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${isPositive ? '+' : ''}${stock.changesPercentage!.toStringAsFixed(2)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    color: theme.colorScheme.error,
                    onPressed: () => _showDeleteConfirmation(stock),
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
    final url =
        'https://financialmodelingprep.com/api/v3/quote/$symbolString?apikey=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => FavoriteStock.fromJson(item)).toList();
    } else {
      throw Exception('Failed to fetch stock details: ${response.statusCode}');
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
}

/// Model class for favorite stock with market data
class FavoriteStock {
  final String symbol;
  final String name;
  final double? price;
  final double? changesPercentage;

  FavoriteStock({
    required this.symbol,
    required this.name,
    this.price,
    this.changesPercentage,
  });

  factory FavoriteStock.fromJson(Map<String, dynamic> json) {
    return FavoriteStock(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble(),
      changesPercentage: (json['changesPercentage'] as num?)?.toDouble(),
    );
  }
}
