import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Search screen for StockDrop app
/// Allows users to search for stocks and add them to favorites
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<StockSearchResult> _searchResults = [];
  Set<String> _favoriteSymbols = {};
  bool _isLoading = false;
  String? _error;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadUserFavorites();
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Search Stocks'), centerTitle: true),
      body: Column(
        children: [
          // Search Input
          _buildSearchInput(theme),

          // Search Results
          Expanded(child: _buildSearchResults(theme)),
        ],
      ),
    );
  }

  Widget _buildSearchInput(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search by symbol or company name...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults.clear();
                      _error = null;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        ),
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget(theme);
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return _buildEmptyResultsWidget(theme);
    }

    if (_searchResults.isEmpty) {
      return _buildInitialStateWidget(theme);
    }

    return _buildResultsList(theme);
  }

  Widget _buildResultsList(ThemeData theme) {
    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final stock = _searchResults[index];
        final isFavorite = _favoriteSymbols.contains(stock.symbol);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stock.price != null) ...[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${stock.price!.toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (stock.exchangeShortName != null)
                        Text(
                          stock.exchangeShortName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? Colors.red
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => _toggleFavorite(stock.symbol, isFavorite),
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
              'Search Failed',
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
              onPressed: _performSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResultsWidget(ThemeData theme) {
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
              'No Results Found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with a different symbol or company name.',
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

  Widget _buildInitialStateWidget(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Search for Stocks',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a stock symbol or company name to get started.',
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

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _performSearch();
      } else {
        setState(() {
          _searchResults.clear();
          _error = null;
        });
      }
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiKey = dotenv.env['FMP_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('FMP API key not found in environment variables');
      }

      final url =
          'https://financialmodelingprep.com/api/v3/search'
          '?query=${Uri.encodeComponent(query)}'
          '&limit=10'
          '&apikey=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Get detailed quotes for the search results to include price
        final symbols = data.map((item) => item['symbol']).take(10).join(',');

        if (symbols.isNotEmpty) {
          final quotesUrl =
              'https://financialmodelingprep.com/api/v3/quote/$symbols?apikey=$apiKey';
          final quotesResponse = await http.get(Uri.parse(quotesUrl));

          Map<String, double> priceMap = {};
          if (quotesResponse.statusCode == 200) {
            final List<dynamic> quotesData = json.decode(quotesResponse.body);
            for (var quote in quotesData) {
              priceMap[quote['symbol']] =
                  (quote['price'] as num?)?.toDouble() ?? 0.0;
            }
          }

          final searchResults = data.map((item) {
            final symbol = item['symbol'] as String;
            return StockSearchResult.fromJson(item, priceMap[symbol]);
          }).toList();

          setState(() {
            _searchResults = searchResults;
            _isLoading = false;
          });
        } else {
          setState(() {
            _searchResults = [];
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to search stocks: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserFavorites() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('st_favorites')
            .select('symbol')
            .eq('user_id', user.id);

        final favorites = (response as List)
            .map((item) => item['symbol'] as String)
            .toSet();

        setState(() {
          _favoriteSymbols = favorites;
        });
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(String symbol, bool isCurrentlyFavorite) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showMessage('Please log in to add favorites', isError: true);
      return;
    }

    try {
      if (isCurrentlyFavorite) {
        // Remove from favorites
        await Supabase.instance.client
            .from('st_favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('symbol', symbol);

        setState(() {
          _favoriteSymbols.remove(symbol);
        });

        _showMessage('Removed from favorites');
      } else {
        // Add to favorites
        await Supabase.instance.client.from('st_favorites').insert({
          'user_id': user.id,
          'symbol': symbol,
        });

        setState(() {
          _favoriteSymbols.add(symbol);
        });

        _showMessage('Added to favorites');
      }
    } catch (e) {
      _showMessage('Failed to update favorites', isError: true);
      debugPrint('Error toggling favorite: $e');
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

/// Model class for stock search results
class StockSearchResult {
  final String symbol;
  final String name;
  final String? exchangeShortName;
  final double? price;

  StockSearchResult({
    required this.symbol,
    required this.name,
    this.exchangeShortName,
    this.price,
  });

  factory StockSearchResult.fromJson(
    Map<String, dynamic> json, [
    double? price,
  ]) {
    return StockSearchResult(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      exchangeShortName: json['exchangeShortName']?.toString(),
      price: price,
    );
  }
}
