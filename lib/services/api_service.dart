import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/stock.dart';
import '../models/gold.dart';

/// API service for FMP (Financial Modeling Prep) API integration in StockDrop app
/// Handles all stock market data API calls with comprehensive error handling
class ApiService {
  static const String _baseUrl = 'https://financialmodelingprep.com/api/v3';

  /// Get API key from environment variables
  static String get _apiKey {
    final key = dotenv.env['FMP_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('FMP_API_KEY not found in environment variables');
    }
    return key;
  }

  // ==================== STOCK SCREENER METHODS ====================

  /// Get top losers - stocks with >5% daily losses
  ///
  /// Returns list of stocks with significant daily losses for homepage display
  /// Filters stocks with market cap > 500M and volume > 500K for quality
  Future<List<Stock>> getLosers() async {
    try {
      debugPrint('🔍 Fetching top losing stocks...');

      // Step 1: Get stock screener results with filters
      final screenerUrl = Uri.parse(
        '$_baseUrl/stock-screener'
        '?marketCapMoreThan=500000000'
        '&volumeMoreThan=500000'
        '&limit=50'
        '&apikey=$_apiKey',
      );

      final screenerResponse = await http.get(screenerUrl);

      if (screenerResponse.statusCode != 200) {
        throw ApiException(
          'Stock screener failed',
          screenerResponse.statusCode,
          screenerResponse.body,
        );
      }

      final List<dynamic> screenerData = json.decode(screenerResponse.body);

      if (screenerData.isEmpty) {
        debugPrint('📊 No stocks found in screener');
        return [];
      }

      // Extract symbols for quote lookup
      final symbols = screenerData
          .take(30) // Limit to first 30 for performance
          .map((item) => item['symbol']?.toString())
          .where((symbol) => symbol != null && symbol.isNotEmpty)
          .cast<String>()
          .toList();

      if (symbols.isEmpty) {
        debugPrint('📊 No valid symbols found');
        return [];
      }

      // Step 2: Get real-time quotes for these symbols
      final quotes = await _getMultipleQuotes(symbols);

      // Step 3: Filter for losers (>5% loss) and sort by percentage loss
      final losers =
          quotes.where((stock) => stock.changePercent < -5.0).toList()
            ..sort((a, b) => a.changePercent.compareTo(b.changePercent));

      final result = losers.take(10).toList();
      debugPrint('📉 Found ${result.length} losing stocks');

      return result;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Error in getLosers: $e');
      throw ApiException('Failed to fetch losing stocks', 0, e.toString());
    }
  }

  /// Get top declining stocks (any decline percentage) for widgets
  ///
  /// Returns list of stocks sorted by decline percentage, including any decline
  /// This is useful for widgets that need to show at least one stock
  Future<List<Stock>> getTopDecliningStocks() async {
    try {
      debugPrint('🔍 Fetching top declining stocks for widget...');

      // Step 1: Get stock screener results with filters
      final screenerUrl = Uri.parse(
        '$_baseUrl/stock-screener'
        '?marketCapMoreThan=100000000' // Lower threshold for more results
        '&volumeMoreThan=100000' // Lower threshold for more results
        '&limit=50'
        '&apikey=$_apiKey',
      );

      final screenerResponse = await http.get(screenerUrl);

      if (screenerResponse.statusCode != 200) {
        throw ApiException(
          'Stock screener failed',
          screenerResponse.statusCode,
          screenerResponse.body,
        );
      }

      final List<dynamic> screenerData = json.decode(screenerResponse.body);

      if (screenerData.isEmpty) {
        debugPrint('📊 No stocks found in screener');
        return [];
      }

      // Extract symbols for quote lookup
      final symbols = screenerData
          .take(30) // Limit to first 30 for performance
          .map((item) => item['symbol']?.toString())
          .where((symbol) => symbol != null && symbol.isNotEmpty)
          .cast<String>()
          .toList();

      if (symbols.isEmpty) {
        debugPrint('📊 No valid symbols found');
        return [];
      }

      // Step 2: Get real-time quotes for these symbols
      final quotes = await _getMultipleQuotes(symbols);

      // Step 3: Sort all stocks by percentage change (declining first)
      final allStocks = quotes.toList()
        ..sort((a, b) => a.changePercent.compareTo(b.changePercent));

      final result = allStocks.take(10).toList();
      debugPrint(
        '📉 Found ${result.length} stocks, top decline: ${result.isNotEmpty ? result.first.changePercent.toStringAsFixed(2) : 'none'}%',
      );

      return result;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Error in getTopDecliningStocks: $e');
      throw ApiException('Failed to fetch declining stocks', 0, e.toString());
    }
  }

  /// Get multiple stock quotes efficiently
  Future<List<Stock>> _getMultipleQuotes(List<String> symbols) async {
    try {
      // FMP allows up to 10 symbols per request for bulk quotes
      const batchSize = 10;
      final List<Stock> allStocks = [];

      for (int i = 0; i < symbols.length; i += batchSize) {
        final batch = symbols.skip(i).take(batchSize).toList();
        final symbolString = batch.join(',');

        final url = Uri.parse('$_baseUrl/quote/$symbolString?apikey=$_apiKey');
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final stocks = data
              .map((json) => Stock.fromJson(json))
              .where((stock) => stock.symbol.isNotEmpty)
              .toList();
          allStocks.addAll(stocks);
        }

        // Small delay between batch requests to respect rate limits
        if (i + batchSize < symbols.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      return allStocks;
    } catch (e) {
      debugPrint('❌ Error fetching multiple quotes: $e');
      throw ApiException('Failed to fetch stock quotes', 0, e.toString());
    }
  }

  // ==================== SEARCH METHODS ====================

  /// Search for stocks by query string
  ///
  /// [query] - Search term (company name, symbol, etc.)
  /// Returns list of matching stocks limited to 10 results
  Future<List<Stock>> searchStocks(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      debugPrint('🔍 Searching stocks for: "$query"');

      final url = Uri.parse(
        '$_baseUrl/search'
        '?query=${Uri.encodeComponent(query.trim())}'
        '&limit=10'
        '&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw ApiException(
          'Stock search failed',
          response.statusCode,
          response.body,
        );
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        debugPrint('🔍 No search results for "$query"');
        return [];
      }

      // Convert search results to Stock objects
      // Note: Search endpoint returns limited data, so we may need to enrich
      final stocks = data
          .map((json) => _parseSearchResult(json))
          .where((stock) => stock != null)
          .cast<Stock>()
          .toList();

      debugPrint('🔍 Found ${stocks.length} search results');
      return stocks;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Error searching stocks: $e');
      throw ApiException('Failed to search stocks', 0, e.toString());
    }
  }

  /// Parse search result JSON to Stock object
  Stock? _parseSearchResult(Map<String, dynamic> json) {
    try {
      return Stock(
        symbol: json['symbol']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        price: 0.0, // Search doesn't include price, will be fetched separately
        change: 0.0,
        changePercent: 0.0,
        currency: json['currency']?.toString(),
      );
    } catch (e) {
      debugPrint('❌ Error parsing search result: $e');
      return null;
    }
  }

  // ==================== STOCK DETAILS METHODS ====================

  /// Get comprehensive stock details
  ///
  /// [symbol] - Stock symbol (e.g., 'AAPL')
  /// Returns detailed stock information including quote, chart, and news
  Future<StockDetails> getStockDetails(String symbol) async {
    try {
      if (symbol.trim().isEmpty) {
        throw ApiException('Stock symbol cannot be empty', 400, '');
      }

      final cleanSymbol = symbol.trim().toUpperCase();
      debugPrint('📊 Fetching details for: $cleanSymbol');

      // Fetch all data concurrently for better performance
      final results = await Future.wait([
        _getStockQuote(cleanSymbol),
        _getStockChart(cleanSymbol),
        _getStockNews(cleanSymbol),
      ]);

      final quote = results[0] as Stock?;
      final chartData = results[1] as List<Map<String, dynamic>>;
      final newsData = results[2] as List<Map<String, dynamic>>;

      if (quote == null) {
        throw ApiException('Stock not found', 404, 'No data for $cleanSymbol');
      }

      return StockDetails(stock: quote, chartData: chartData, news: newsData);
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Error getting stock details: $e');
      throw ApiException('Failed to fetch stock details', 0, e.toString());
    }
  }

  /// Get single stock quote
  Future<Stock?> _getStockQuote(String symbol) async {
    try {
      final url = Uri.parse('$_baseUrl/quote/$symbol?apikey=$_apiKey');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw ApiException(
          'Quote fetch failed',
          response.statusCode,
          response.body,
        );
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        return null;
      }

      return Stock.fromJson(data.first);
    } catch (e) {
      debugPrint('❌ Error fetching quote for $symbol: $e');
      return null;
    }
  }

  /// Get 5-minute historical chart data
  Future<List<Map<String, dynamic>>> _getStockChart(String symbol) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/historical-chart/5min/$symbol?apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ Chart data not available for $symbol');
        return [];
      }

      final List<dynamic> data = json.decode(response.body);

      // Return last 50 data points for performance
      final chartData = data
          .take(50)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      debugPrint('📈 Loaded ${chartData.length} chart points for $symbol');
      return chartData;
    } catch (e) {
      debugPrint('❌ Error fetching chart for $symbol: $e');
      return [];
    }
  }

  /// Get stock-specific news (limit 2)
  Future<List<Map<String, dynamic>>> _getStockNews(String symbol) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/stock_news?tickers=$symbol&limit=2&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ News not available for $symbol');
        return [];
      }

      final List<dynamic> data = json.decode(response.body);
      final newsItems = data
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      debugPrint('📰 Loaded ${newsItems.length} news items for $symbol');
      return newsItems;
    } catch (e) {
      debugPrint('❌ Error fetching news for $symbol: $e');
      return [];
    }
  }

  // ==================== LEGACY METHODS (MAINTAINED FOR COMPATIBILITY) ====================

  /// Get single stock data (legacy method)
  Future<Stock?> getStock(String symbol) async {
    try {
      return await _getStockQuote(symbol);
    } catch (e) {
      debugPrint('❌ Error in getStock: $e');
      return null;
    }
  }

  /// Get multiple stocks data (legacy method)
  Future<List<Stock>> getMultipleStocks(List<String> symbols) async {
    try {
      if (symbols.isEmpty) return [];
      return await _getMultipleQuotes(symbols);
    } catch (e) {
      debugPrint('❌ Error in getMultipleStocks: $e');
      return [];
    }
  }

  /// Get stock price history (legacy method)
  Future<List<Map<String, dynamic>>> getStockHistory(
    String symbol, {
    String period = '1D',
  }) async {
    try {
      String endpoint;
      switch (period) {
        case '1D':
          endpoint = 'historical-chart/1min/$symbol';
          break;
        case '5D':
          endpoint = 'historical-chart/5min/$symbol';
          break;
        case '1M':
          endpoint = 'historical-price-full/$symbol';
          break;
        default:
          endpoint = 'historical-price-full/$symbol';
      }

      final url = Uri.parse('$_baseUrl/$endpoint?apikey=$_apiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        // Handle different response formats
        if (responseData is List) {
          return responseData.cast<Map<String, dynamic>>();
        } else if (responseData is Map &&
            responseData.containsKey('historical')) {
          return List<Map<String, dynamic>>.from(responseData['historical']);
        }
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error fetching stock history: $e');
      return [];
    }
  }

  /// Get market news (legacy method)
  Future<List<Map<String, dynamic>>> getMarketNews({int limit = 20}) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/stock_news?limit=$limit&apikey=$_apiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error fetching market news: $e');
      return [];
    }
  }

  /// Get company profile (legacy method)
  Future<Map<String, dynamic>?> getCompanyProfile(String symbol) async {
    try {
      final url = Uri.parse('$_baseUrl/profile/$symbol?apikey=$_apiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return data.first;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error fetching company profile: $e');
      return null;
    }
  }

  // ==================== GOLD COMMODITY METHODS ====================

  /// Get current gold price data
  ///
  /// Fetches real-time gold price (GCUSD) from FMP API
  /// Returns Gold object with current price, change, and percentage change
  Future<Gold?> getGoldPrice() async {
    try {
      debugPrint('🥇 Fetching current gold price...');

      final url = Uri.parse('$_baseUrl/quote/GCUSD?apikey=$_apiKey');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to fetch gold price',
          response.statusCode,
          response.body,
        );
      }

      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        final goldData = Gold.fromQuoteJson(data.first);
        debugPrint(
          '✅ Gold price fetched: ${goldData.formattedPrice} (${goldData.formattedChangePercent})',
        );
        return goldData;
      }

      debugPrint('⚠️ No gold price data available');
      return null;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Error fetching gold price: $e');
      throw ApiException('Failed to fetch gold price', 0, e.toString());
    }
  }

  /// Get historical gold price data for charting
  ///
  /// [period] - Time period ('1day', '5day', '1month', '3month', '6month', '1year', '5year')
  /// Returns list of historical gold price points
  Future<List<GoldHistoricalPoint>> getGoldHistoricalData({
    String period = '1month',
  }) async {
    try {
      debugPrint('📈 Fetching gold historical data for period: $period');

      // Convert period to from/to dates
      final now = DateTime.now();
      DateTime fromDate;

      switch (period) {
        case '1day':
          fromDate = now.subtract(const Duration(days: 1));
          break;
        case '5day':
          fromDate = now.subtract(const Duration(days: 5));
          break;
        case '1month':
          fromDate = now.subtract(const Duration(days: 30));
          break;
        case '3month':
          fromDate = now.subtract(const Duration(days: 90));
          break;
        case '6month':
          fromDate = now.subtract(const Duration(days: 180));
          break;
        case '1year':
          fromDate = now.subtract(const Duration(days: 365));
          break;
        case '5year':
          fromDate = now.subtract(const Duration(days: 365 * 5));
          break;
        default:
          fromDate = now.subtract(const Duration(days: 30));
      }

      final fromDateStr =
          '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
      final toDateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final url = Uri.parse(
        'https://financialmodelingprep.com/api/v3/historical-price-full/GCUSD'
        '?from=$fromDateStr&to=$toDateStr&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to fetch gold historical data',
          response.statusCode,
          response.body,
        );
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> historical = data['historical'] ?? [];

      final points =
          historical.map((json) => GoldHistoricalPoint.fromJson(json)).toList()
            ..sort(
              (a, b) => a.date.compareTo(b.date),
            ); // Sort by date ascending

      debugPrint(
        '✅ Gold historical data fetched: ${points.length} data points',
      );
      return points;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Error fetching gold historical data: $e');
      throw ApiException(
        'Failed to fetch gold historical data',
        0,
        e.toString(),
      );
    }
  }

  /// Get gold price with simple historical endpoint (lighter version)
  ///
  /// Uses the /historical-price-eod/light endpoint for basic historical data
  /// Good for simple price tracking without full historical details
  Future<Gold?> getGoldPriceLight() async {
    try {
      debugPrint('🥇 Fetching gold price (light endpoint)...');

      final url = Uri.parse(
        'https://financialmodelingprep.com/api/v3/historical-price-eod/light'
        '?symbol=GCUSD&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to fetch gold price (light)',
          response.statusCode,
          response.body,
        );
      }

      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        final goldData = Gold.fromHistoricalJson(data.first);
        debugPrint('✅ Gold price (light) fetched: ${goldData.formattedPrice}');
        return goldData;
      }

      debugPrint('⚠️ No gold price data available (light endpoint)');
      return null;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Error fetching gold price (light): $e');
      throw ApiException('Failed to fetch gold price (light)', 0, e.toString());
    }
  }

  /// Get comprehensive gold data combining both endpoints
  ///
  /// Combines real-time quote data with light historical data
  /// Returns the most up-to-date and comprehensive gold information
  Future<Gold?> getComprehensiveGoldData() async {
    try {
      debugPrint('🥇 Fetching comprehensive gold data...');

      // Try to get real-time quote first
      final quoteGold = await getGoldPrice();
      if (quoteGold != null) {
        return quoteGold;
      }

      // Fallback to light endpoint if quote fails
      debugPrint('⚠️ Quote endpoint failed, trying light endpoint...');
      return await getGoldPriceLight();
    } catch (e) {
      debugPrint('❌ Error fetching comprehensive gold data: $e');
      throw ApiException('Failed to fetch gold data', 0, e.toString());
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Check API health and connectivity
  Future<bool> checkApiHealth() async {
    try {
      final url = Uri.parse('$_baseUrl/quote/AAPL?apikey=$_apiKey');
      final response = await http.get(url);
      final isHealthy = response.statusCode == 200;

      debugPrint('🏥 API Health Check: ${isHealthy ? 'HEALTHY' : 'UNHEALTHY'}');
      return isHealthy;
    } catch (e) {
      debugPrint('❌ API health check failed: $e');
      return false;
    }
  }

  /// Get API usage info (if available)
  Future<Map<String, dynamic>?> getApiUsage() async {
    try {
      // Some API providers offer usage endpoints
      // This is a placeholder for potential usage tracking
      debugPrint('📊 API usage tracking not implemented');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting API usage: $e');
      return null;
    }
  }
}

// ==================== MODELS AND EXCEPTIONS ====================

/// Comprehensive stock details including quote, chart, and news
class StockDetails {
  final Stock stock;
  final List<Map<String, dynamic>> chartData;
  final List<Map<String, dynamic>> news;

  StockDetails({
    required this.stock,
    required this.chartData,
    required this.news,
  });

  @override
  String toString() {
    return 'StockDetails(symbol: ${stock.symbol}, chartPoints: ${chartData.length}, newsItems: ${news.length})';
  }
}

/// Custom exception for API-related errors
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String details;

  ApiException(this.message, this.statusCode, this.details);

  @override
  String toString() {
    return 'ApiException: $message (Status: $statusCode) - $details';
  }

  /// Check if error is due to rate limiting
  bool get isRateLimited => statusCode == 429;

  /// Check if error is due to authentication
  bool get isAuthError => statusCode == 401 || statusCode == 403;

  /// Check if error is due to not found
  bool get isNotFound => statusCode == 404;

  /// Check if error is a server error
  bool get isServerError => statusCode >= 500;
}
