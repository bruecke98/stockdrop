import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../widgets/stock_card.dart';
import '../services/supabase_service.dart';

/// Example usage of StockCard widget with StockDrop services
///
/// This demonstrates how to integrate the StockCard with:
/// - Navigation callbacks
/// - Favorites functionality using SupabaseService
/// - Loading states with skeleton cards
/// - Different card variants
class StockCardExample extends StatefulWidget {
  const StockCardExample({super.key});

  @override
  State<StockCardExample> createState() => _StockCardExampleState();
}

class _StockCardExampleState extends State<StockCardExample> {
  final SupabaseService _supabaseService = SupabaseService();
  final List<String> _favoriteSymbols = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      setState(() => _isLoading = true);

      // Get user's favorite stocks from Supabase
      final favoritesStream = _supabaseService.getFavoritesStream();
      favoritesStream.listen((favorites) {
        setState(() {
          _favoriteSymbols.clear();
          _favoriteSymbols.addAll(favorites);
        });
      });
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(String symbol) async {
    try {
      await _supabaseService.toggleFavorite(symbol);

      // Show feedback to user
      if (mounted) {
        final isFavorited = _favoriteSymbols.contains(symbol);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFavorited
                  ? '$symbol removed from favorites'
                  : '$symbol added to favorites',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorites: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _navigateToStockDetail(Stock stock) {
    // Navigate to stock detail screen
    Navigator.pushNamed(context, '/stock-detail', arguments: stock);
  }

  @override
  Widget build(BuildContext context) {
    // Example stock data (in real app, this would come from your API service)
    final exampleStocks = [
      Stock(
        symbol: 'AAPL',
        name: 'Apple Inc.',
        price: 175.43,
        change: 2.15,
        changePercent: 1.24,
      ),
      Stock(
        symbol: 'GOOGL',
        name: 'Alphabet Inc.',
        price: 142.56,
        change: -1.23,
        changePercent: -0.85,
      ),
      Stock(
        symbol: 'MSFT',
        name: 'Microsoft Corporation',
        price: 378.85,
        change: 5.67,
        changePercent: 1.52,
      ),
      Stock(
        symbol: 'TSLA',
        name: 'Tesla, Inc.',
        price: 219.16,
        change: -8.45,
        changePercent: -3.71,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('StockCard Examples')),
      body: ListView(
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Regular Stock Cards',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),

          // Regular stock cards
          if (_isLoading)
            // Show skeleton loading cards
            ...List.generate(4, (index) => const StockCardSkeleton())
          else
            // Show actual stock cards
            ...exampleStocks.map(
              (stock) => StockCard(
                stock: stock,
                isFavorited: _favoriteSymbols.contains(stock.symbol),
                onTap: () => _navigateToStockDetail(stock),
                onFavoritePressed: () => _toggleFavorite(stock.symbol),
              ),
            ),

          const SizedBox(height: 24),

          // Section header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Compact Stock Cards',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),

          // Compact stock cards
          ...exampleStocks.map(
            (stock) => CompactStockCard(
              stock: stock,
              isFavorited: _favoriteSymbols.contains(stock.symbol),
              onTap: () => _navigateToStockDetail(stock),
              onFavoritePressed: () => _toggleFavorite(stock.symbol),
            ),
          ),

          const SizedBox(height: 24),

          // Section header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Cards without Favorite Button',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),

          // Stock cards without favorite button
          ...exampleStocks
              .take(2)
              .map(
                (stock) => StockCard(
                  stock: stock,
                  showFavoriteButton: false,
                  onTap: () => _navigateToStockDetail(stock),
                ),
              ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Example of using StockCard in a search results list
class SearchResultsList extends StatelessWidget {
  final List<Stock> searchResults;
  final List<String> favoriteSymbols;
  final Function(String) onToggleFavorite;
  final Function(Stock) onStockTap;

  const SearchResultsList({
    super.key,
    required this.searchResults,
    required this.favoriteSymbols,
    required this.onToggleFavorite,
    required this.onStockTap,
  });

  @override
  Widget build(BuildContext context) {
    if (searchResults.isEmpty) {
      return const Center(child: Text('No stocks found'));
    }

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final stock = searchResults[index];
        return StockCard(
          stock: stock,
          isFavorited: favoriteSymbols.contains(stock.symbol),
          onTap: () => onStockTap(stock),
          onFavoritePressed: () => onToggleFavorite(stock.symbol),
        );
      },
    );
  }
}

/// Example of using StockCard in a favorites screen
class FavoritesStockList extends StatelessWidget {
  final List<Stock> favoriteStocks;
  final Function(String) onRemoveFavorite;
  final Function(Stock) onStockTap;

  const FavoritesStockList({
    super.key,
    required this.favoriteStocks,
    required this.onRemoveFavorite,
    required this.onStockTap,
  });

  @override
  Widget build(BuildContext context) {
    if (favoriteStocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No favorite stocks yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add stocks to your favorites to see them here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: favoriteStocks.length,
      itemBuilder: (context, index) {
        final stock = favoriteStocks[index];
        return StockCard(
          stock: stock,
          isFavorited: true, // All stocks in this list are favorited
          onTap: () => onStockTap(stock),
          onFavoritePressed: () => onRemoveFavorite(stock.symbol),
        );
      },
    );
  }
}
