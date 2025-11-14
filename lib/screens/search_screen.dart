import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/enhanced_stock_card.dart';
import '../models/market_hours.dart';

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

  // Market hours data
  List<MarketHours> _marketHours = [];
  bool _isLoadingMarketHours = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadUserFavorites();
    _fetchMarketHours();
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

        return Stack(
          children: [
            EnhancedStockCard(
              stock: StockSearchResultAdapter(stock),
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
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: isFavorite
                      ? Colors.red
                      : theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => _toggleFavorite(stock.symbol, isFavorite),
              ),
            ),
          ],
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

        // Filter to only include stocks (not ETFs or funds)
        final stockData = data
            .where((item) {
              final type = item['type']?.toString().toLowerCase() ?? '';
              return type == 'stock' || type == 'common stock' || type.isEmpty;
            })
            .take(10)
            .toList();

        debugPrint(
          '🔍 Filtered ${stockData.length} stocks from ${data.length} search results',
        );

        if (stockData.isNotEmpty) {
          // Get symbols from filtered stock results
          final symbols = stockData.map((item) => item['symbol']).toList();

          // Get detailed quotes for price and change data (supports comma-separated)
          final quotesUrl =
              'https://financialmodelingprep.com/api/v3/quote/${symbols.join(',')}?apikey=$apiKey';
          final quotesResponse = await http.get(Uri.parse(quotesUrl));

          // Get profile data individually for each stock (stable/profile uses query params)
          final profileFutures = symbols.map((symbol) async {
            final profileUrl =
                'https://financialmodelingprep.com/stable/profile?symbol=$symbol&apikey=$apiKey';
            final response = await http.get(Uri.parse(profileUrl));
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              return data.isNotEmpty
                  ? data[0]
                  : null; // Profile API returns array
            }
            return null;
          });

          final profileResults = await Future.wait(profileFutures);

          debugPrint('🔍 Search API calls:');
          debugPrint('  Search results: ${data.length} items');
          debugPrint('  Filtered stocks: ${stockData.length} items');
          debugPrint('  Quotes status: ${quotesResponse.statusCode}');

          if (quotesResponse.statusCode == 200) {
            final List<dynamic> quotesData = json.decode(quotesResponse.body);

            debugPrint('  Quotes data: ${quotesData.length} items');
            debugPrint('  Profile calls completed: ${profileResults.length}');

            // Create maps for easy lookup
            final quotesMap = {
              for (var quote in quotesData) quote['symbol']: quote,
            };
            final profilesMap = {
              for (int i = 0; i < symbols.length; i++)
                symbols[i]: profileResults[i],
            };

            // Combine search, quote, and profile data
            final searchResults = stockData.map((searchItem) {
              final symbol = searchItem['symbol'];
              final quote = quotesMap[symbol];
              final profile = profilesMap[symbol];

              debugPrint('  Processing $symbol:');
              debugPrint('    Quote: ${quote != null}');
              debugPrint('    Profile: ${profile != null}');
              if (profile != null) {
                debugPrint('    Beta: ${profile['beta']}');
                debugPrint('    Sector: ${profile['sector']}');
                debugPrint(
                  '    Market Cap: ${profile['mktCap'] ?? profile['marketCap']}',
                );
                debugPrint('    Country: ${profile['country']}');
              }

              return StockSearchResult.fromJson(searchItem, quote, profile);
            }).toList();

            setState(() {
              _searchResults = searchResults;
              _isLoading = false;
            });
          } else {
            // Fallback to search data only if quotes fail
            final searchResults = stockData.map((item) {
              return StockSearchResult.fromJson(item, null, null);
            }).toList();

            setState(() {
              _searchResults = searchResults;
              _isLoading = false;
            });
          }
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

/// Model class for stock search results
class StockSearchResult {
  final String symbol;
  final String name;
  final String? exchangeShortName;
  final double? price;
  final double? changePercent;
  final double? beta;
  final String? sector;
  final double? marketCap;
  final String? country;
  final double? yearHigh;
  final double? yearLow;

  StockSearchResult({
    required this.symbol,
    required this.name,
    this.exchangeShortName,
    this.price,
    this.changePercent,
    this.beta,
    this.sector,
    this.marketCap,
    this.country,
    this.yearHigh,
    this.yearLow,
  });

  factory StockSearchResult.fromJson(
    Map<String, dynamic> searchJson, [
    Map<String, dynamic>? quoteJson,
    Map<String, dynamic>? profileJson,
  ]) {
    // Use quote data for price/change if available, otherwise search data
    final price = quoteJson != null
        ? (quoteJson['price'] as num?)?.toDouble()
        : (searchJson['price'] as num?)?.toDouble();

    final changePercent = quoteJson != null
        ? (quoteJson['changesPercentage'] as num?)?.toDouble()
        : (searchJson['changesPercentage'] as num?)?.toDouble();

    // Use profile data for beta/sector/country/marketCap if available
    final beta = profileJson != null
        ? (profileJson['beta'] as num?)?.toDouble()
        : null;

    final sector = profileJson != null
        ? profileJson['sector'] as String?
        : null;

    final marketCap = profileJson != null
        ? (profileJson['mktCap'] as num?)?.toDouble() ??
              (profileJson['marketCap'] as num?)?.toDouble()
        : null;

    final country = profileJson != null
        ? profileJson['country'] as String?
        : null;

    final yearHigh = quoteJson != null
        ? (quoteJson['yearHigh'] as num?)?.toDouble()
        : null;

    final yearLow = quoteJson != null
        ? (quoteJson['yearLow'] as num?)?.toDouble()
        : null;

    return StockSearchResult(
      symbol: searchJson['symbol']?.toString() ?? '',
      name: searchJson['name']?.toString() ?? '',
      exchangeShortName: searchJson['exchangeShortName']?.toString(),
      price: price,
      changePercent: changePercent,
      beta: beta,
      sector: sector,
      marketCap: marketCap,
      country: country,
      yearHigh: yearHigh,
      yearLow: yearLow,
    );
  }
}
