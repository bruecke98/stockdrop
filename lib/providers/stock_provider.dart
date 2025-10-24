import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import models
import '../models/stock.dart';
import '../services/api_service.dart';

/// Stock provider for managing stock-related state
/// Handles favorites, stock data, and API interactions
class StockProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<String> _favoriteSymbols = [];
  List<Stock> _favoriteStocks = [];
  List<Stock> _searchResults = [];
  final Map<String, Stock> _stockCache = {};

  bool _isLoading = false;
  bool _isFavoritesLoading = false;
  String? _error;

  // Getters
  List<String> get favoriteSymbols => _favoriteSymbols;
  List<Stock> get favoriteStocks => _favoriteStocks;
  List<Stock> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isFavoritesLoading => _isFavoritesLoading;
  String? get error => _error;

  /// Initialize provider and load user favorites
  Future<void> initialize() async {
    await loadFavorites();
  }

  /// Load user's favorite stocks from Supabase
  Future<void> loadFavorites() async {
    try {
      _setFavoritesLoading(true);
      _clearError();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _favoriteSymbols = [];
        _favoriteStocks = [];
        notifyListeners();
        return;
      }

      // Fetch favorite symbols from Supabase
      final response = await Supabase.instance.client
          .from('st_favorites')
          .select('symbol')
          .eq('user_id', user.id)
          .order('added_at', ascending: false);

      _favoriteSymbols = (response as List)
          .map((item) => item['symbol'] as String)
          .toList();

      // Fetch stock data for favorites
      if (_favoriteSymbols.isNotEmpty) {
        _favoriteStocks = await _apiService.getMultipleStocks(_favoriteSymbols);
      } else {
        _favoriteStocks = [];
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load favorites: $e');
      debugPrint('Error loading favorites: $e');
    } finally {
      _setFavoritesLoading(false);
    }
  }

  /// Add stock to favorites
  Future<bool> addToFavorites(String symbol) async {
    try {
      _setLoading(true);
      _clearError();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Add to Supabase
      await Supabase.instance.client.from('st_favorites').insert({
        'user_id': user.id,
        'symbol': symbol.toUpperCase(),
      });

      // Update local state
      if (!_favoriteSymbols.contains(symbol.toUpperCase())) {
        _favoriteSymbols.insert(0, symbol.toUpperCase());

        // Fetch and add stock data
        final stock = await _apiService.getStock(symbol);
        if (stock != null) {
          _favoriteStocks.insert(0, stock);
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to add to favorites: $e');
      debugPrint('Error adding to favorites: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Remove stock from favorites
  Future<bool> removeFromFavorites(String symbol) async {
    try {
      _setLoading(true);
      _clearError();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Remove from Supabase
      await Supabase.instance.client
          .from('st_favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('symbol', symbol.toUpperCase());

      // Update local state
      _favoriteSymbols.remove(symbol.toUpperCase());
      _favoriteStocks.removeWhere(
        (stock) => stock.symbol == symbol.toUpperCase(),
      );

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to remove from favorites: $e');
      debugPrint('Error removing from favorites: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if a stock is in favorites
  bool isFavorite(String symbol) {
    return _favoriteSymbols.contains(symbol.toUpperCase());
  }

  /// Search for stocks
  Future<void> searchStocks(String query) async {
    try {
      _setLoading(true);
      _clearError();

      if (query.trim().isEmpty) {
        _searchResults = [];
        notifyListeners();
        return;
      }

      _searchResults = await _apiService.searchStocks(query);
      notifyListeners();
    } catch (e) {
      _setError('Failed to search stocks: $e');
      debugPrint('Error searching stocks: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Get stock details (with caching)
  Future<Stock?> getStockDetails(String symbol) async {
    try {
      _setLoading(true);
      _clearError();

      // Check cache first
      if (_stockCache.containsKey(symbol.toUpperCase())) {
        return _stockCache[symbol.toUpperCase()];
      }

      // Fetch from API
      final stock = await _apiService.getStock(symbol);
      if (stock != null) {
        _stockCache[symbol.toUpperCase()] = stock;
      }

      return stock;
    } catch (e) {
      _setError('Failed to get stock details: $e');
      debugPrint('Error getting stock details: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Clear search results
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  /// Clear cache
  void clearCache() {
    _stockCache.clear();
  }

  /// Refresh favorites data
  Future<void> refreshFavorites() async {
    await loadFavorites();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setFavoritesLoading(bool loading) {
    _isFavoritesLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
