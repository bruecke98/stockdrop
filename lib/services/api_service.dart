import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/stock.dart';
import '../models/gold.dart';
import '../models/commodity.dart';

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

  /// Get stocks by sector
  ///
  /// [sector] - The sector to filter by (e.g., 'Technology', 'Healthcare')
  /// Returns list of stocks in the specified sector
  Future<List<Stock>> getStocksBySector(String sector) async {
    try {
      debugPrint('🏭 Fetching stocks for sector: $sector');

      // Step 1: Get stock screener results filtered by sector
      final screenerUrl = Uri.parse(
        '$_baseUrl/stock-screener'
        '?sector=${Uri.encodeComponent(sector)}'
        '&marketCapMoreThan=500000000'
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
        debugPrint('🏭 No stocks found in sector: $sector');
        return [];
      }

      // Extract symbols for quote lookup
      final symbols = screenerData
          .take(20) // Limit to first 20 for performance
          .map((item) => item['symbol']?.toString())
          .where((symbol) => symbol != null && symbol.isNotEmpty)
          .cast<String>()
          .toList();

      if (symbols.isEmpty) {
        debugPrint('🏭 No valid symbols found in sector: $sector');
        return [];
      }

      // Step 2: Get real-time quotes for these symbols
      final stocks = await _getMultipleQuotes(symbols);

      // Step 3: Sort by market cap (largest first)
      stocks.sort((a, b) => (b.marketCap ?? 0).compareTo(a.marketCap ?? 0));

      final result = stocks.take(10).toList();
      debugPrint('🏭 Found ${result.length} stocks in sector: $sector');

      return result;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Error in getStocksBySector: $e');
      throw ApiException(
        'Failed to fetch stocks for sector $sector',
        0,
        e.toString(),
      );
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
        getPriceTargetConsensus(cleanSymbol),
      ]);

      final quote = results[0] as Stock?;
      final chartData = results[1] as List<Map<String, dynamic>>;
      final newsData = results[2] as List<Map<String, dynamic>>;
      final priceTarget = results[3] as PriceTargetConsensus?;

      if (quote == null) {
        throw ApiException('Stock not found', 404, 'No data for $cleanSymbol');
      }

      return StockDetails(
        stock: quote,
        chartData: chartData,
        news: newsData,
        priceTargetConsensus: priceTarget,
      );
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

  /// Get price target consensus for a stock
  ///
  /// [symbol] - Stock symbol (e.g., 'AAPL')
  /// Returns analyst price target consensus data
  Future<PriceTargetConsensus?> getPriceTargetConsensus(String symbol) async {
    try {
      if (symbol.trim().isEmpty) {
        throw ApiException('Stock symbol cannot be empty', 400, '');
      }

      final cleanSymbol = symbol.trim().toUpperCase();
      debugPrint('🎯 Fetching price target consensus for: $cleanSymbol');

      final url = Uri.parse(
        'https://financialmodelingprep.com/stable/price-target-consensus?symbol=$cleanSymbol&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ Price target consensus not available for $cleanSymbol');
        return null;
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        debugPrint('⚠️ No price target consensus data for $cleanSymbol');
        return null;
      }

      final consensus = PriceTargetConsensus.fromJson(data.first);
      debugPrint(
        '🎯 Loaded price target consensus for $cleanSymbol: ${consensus.targetConsensus}',
      );
      return consensus;
    } catch (e) {
      debugPrint('❌ Error fetching price target consensus for $symbol: $e');
      return null;
    }
  }

  /// Get custom DCF (Discounted Cash Flow) analysis for a stock
  ///
  /// [symbol] - Stock symbol (e.g., 'AAPL')
  /// Returns detailed DCF valuation analysis
  Future<DcfAnalysis?> getCustomDcfAnalysis(String symbol) async {
    try {
      if (symbol.trim().isEmpty) {
        throw ApiException('Stock symbol cannot be empty', 400, '');
      }

      final cleanSymbol = symbol.trim().toUpperCase();
      debugPrint('📊 Fetching custom DCF analysis for: $cleanSymbol');

      final url = Uri.parse(
        'https://financialmodelingprep.com/stable/custom-discounted-cash-flow?symbol=$cleanSymbol&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ DCF analysis not available for $cleanSymbol');
        return null;
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        debugPrint('⚠️ No DCF analysis data for $cleanSymbol');
        return null;
      }

      final dcf = DcfAnalysis.fromJson(data.first);
      debugPrint(
        '📊 Loaded DCF analysis for $cleanSymbol: Fair Value \$${dcf.equityValuePerShare?.toStringAsFixed(2)}',
      );
      return dcf;
    } catch (e) {
      debugPrint('❌ Error fetching DCF analysis for $symbol: $e');
      return null;
    }
  }

  /// Get key financial metrics for a stock
  ///
  /// [symbol] - Stock symbol (e.g., 'AAPL')
  /// [limit] - Number of periods to fetch (default: 5)
  /// [period] - Period type ('annual' or 'quarter', default: 'annual')
  /// Returns comprehensive financial metrics
  Future<List<KeyMetrics>> getKeyMetrics(
    String symbol, {
    int limit = 5,
    String period = 'annual',
  }) async {
    try {
      if (symbol.trim().isEmpty) {
        throw ApiException('Stock symbol cannot be empty', 400, '');
      }

      final cleanSymbol = symbol.trim().toUpperCase();
      debugPrint('📈 Fetching key metrics for: $cleanSymbol');

      final url = Uri.parse(
        'https://financialmodelingprep.com/stable/key-metrics?symbol=$cleanSymbol&limit=$limit&period=$period&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ Key metrics not available for $cleanSymbol');
        return [];
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        debugPrint('⚠️ No key metrics data for $cleanSymbol');
        return [];
      }

      final metrics = data.map((item) => KeyMetrics.fromJson(item)).toList();
      debugPrint(
        '📈 Loaded ${metrics.length} key metrics periods for $cleanSymbol',
      );
      return metrics;
    } catch (e) {
      debugPrint('❌ Error fetching key metrics for $symbol: $e');
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

  // ==================== COMMODITY METHODS ====================

  /// Get current commodity price data
  ///
  /// Fetches real-time commodity price from FMP API
  /// Supports gold (GCUSD), silver (SIUSD), and oil (BZUSD)
  Future<Commodity?> getCommodityPrice(String type) async {
    try {
      final symbol = _getCommoditySymbol(type);
      debugPrint('💰 Fetching current $type price ($symbol)...');

      final url = Uri.parse('$_baseUrl/quote/$symbol?apikey=$_apiKey');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to fetch $type price',
          response.statusCode,
          response.body,
        );
      }

      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        final commodityData = Commodity.fromQuoteJson(data.first, type);

        debugPrint(
          '✅ $type price fetched: ${commodityData.formattedPrice} (${commodityData.formattedChangePercent})',
        );

        return commodityData;
      } else {
        debugPrint('⚠️ No $type price data available');
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error fetching $type price: $e');
      throw ApiException('Failed to fetch $type price', 0, e.toString());
    }
  }

  /// Get all commodity prices (gold, silver, oil)
  Future<Map<String, Commodity?>> getAllCommodityPrices() async {
    final results = <String, Commodity?>{};

    final commodities = ['gold', 'silver', 'oil'];

    for (final commodity in commodities) {
      try {
        results[commodity] = await getCommodityPrice(commodity);
      } catch (e) {
        debugPrint('❌ Failed to fetch $commodity: $e');
        results[commodity] = null;
      }
    }

    return results;
  }

  /// Get commodity symbol for API calls
  String _getCommoditySymbol(String type) {
    switch (type.toLowerCase()) {
      case 'gold':
        return 'GCUSD';
      case 'silver':
        return 'SIUSD';
      case 'oil':
        return 'BZUSD';
      default:
        throw ArgumentError('Unsupported commodity type: $type');
    }
  }

  /// Get historical commodity data for charting
  Future<List<CommodityHistoricalPoint>> getCommodityHistoricalData(
    String type, {
    int days = 30,
  }) async {
    try {
      final symbol = _getCommoditySymbol(type);
      debugPrint('📈 Fetching $type historical data for $days days...');

      final fromDate = DateTime.now().subtract(Duration(days: days + 5));
      final toDate = DateTime.now();

      final fromStr =
          '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
      final toStr =
          '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';

      final url = Uri.parse(
        '$_baseUrl/historical-price-full/$symbol?from=$fromStr&to=$toStr&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to fetch $type historical data',
          response.statusCode,
          response.body,
        );
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> historical = data['historical'] ?? [];

      final points = historical
          .take(days)
          .map((point) => CommodityHistoricalPoint.fromJson(point))
          .toList()
          .reversed
          .toList();

      debugPrint('✅ Fetched ${points.length} $type historical data points');
      return points;
    } catch (e) {
      debugPrint('❌ Error fetching $type historical data: $e');
      throw ApiException(
        'Failed to fetch $type historical data',
        0,
        e.toString(),
      );
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

  /// Get detailed company profile information
  ///
  /// [symbol] - Stock symbol (e.g., 'AAPL')
  /// Returns detailed company profile information as CompanyProfile object
  Future<CompanyProfile?> getCompanyProfileDetails(String symbol) async {
    try {
      if (symbol.trim().isEmpty) {
        throw ApiException('Stock symbol cannot be empty', 400, '');
      }

      final cleanSymbol = symbol.trim().toUpperCase();
      debugPrint('🏢 Fetching company profile for: $cleanSymbol');

      final url = Uri.parse(
        'https://financialmodelingprep.com/stable/profile?symbol=$cleanSymbol&apikey=${ApiService._apiKey}',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('🏢 Company profile not available for $cleanSymbol');
        return null;
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        debugPrint('🏢 No company profile data for $cleanSymbol');
        return null;
      }

      final profile = CompanyProfile.fromJson(data.first);
      debugPrint(
        '✅ Loaded company profile for $cleanSymbol: ${profile.companyName}',
      );
      return profile;
    } catch (e) {
      debugPrint('❌ Error fetching company profile for $symbol: $e');
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
  final PriceTargetConsensus? priceTargetConsensus;

  StockDetails({
    required this.stock,
    required this.chartData,
    required this.news,
    this.priceTargetConsensus,
  });

  @override
  String toString() {
    return 'StockDetails(symbol: ${stock.symbol}, chartPoints: ${chartData.length}, newsItems: ${news.length}, hasTargets: ${priceTargetConsensus != null})';
  }
}

/// Price Target Consensus data from analysts
class PriceTargetConsensus {
  final String symbol;
  final double? targetHigh;
  final double? targetLow;
  final double? targetConsensus;
  final double? targetMedian;
  final int? numberOfAnalysts;

  PriceTargetConsensus({
    required this.symbol,
    this.targetHigh,
    this.targetLow,
    this.targetConsensus,
    this.targetMedian,
    this.numberOfAnalysts,
  });

  factory PriceTargetConsensus.fromJson(Map<String, dynamic> json) {
    return PriceTargetConsensus(
      symbol: json['symbol']?.toString() ?? '',
      targetHigh: _parseDouble(json['targetHigh']),
      targetLow: _parseDouble(json['targetLow']),
      targetConsensus: _parseDouble(json['targetConsensus']),
      targetMedian: _parseDouble(json['targetMedian']),
      numberOfAnalysts: _parseInt(json['numberOfAnalysts']),
    );
  }

  /// Helper method to safely parse double from dynamic value
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Helper method to safely parse int from dynamic value
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Get formatted target high price
  String get formattedTargetHigh {
    if (targetHigh == null) return 'N/A';
    return '\$${targetHigh!.toStringAsFixed(2)}';
  }

  /// Get formatted target low price
  String get formattedTargetLow {
    if (targetLow == null) return 'N/A';
    return '\$${targetLow!.toStringAsFixed(2)}';
  }

  /// Get formatted target consensus price
  String get formattedTargetConsensus {
    if (targetConsensus == null) return 'N/A';
    return '\$${targetConsensus!.toStringAsFixed(2)}';
  }

  /// Get formatted target median price
  String get formattedTargetMedian {
    if (targetMedian == null) return 'N/A';
    return '\$${targetMedian!.toStringAsFixed(2)}';
  }

  /// Get formatted number of analysts
  String get formattedAnalystCount {
    if (numberOfAnalysts == null) return 'N/A';
    return '${numberOfAnalysts!} analysts';
  }

  /// Calculate potential upside/downside based on current price
  String getPotentialReturn(double currentPrice) {
    if (targetConsensus == null) return 'N/A';

    final potential = ((targetConsensus! - currentPrice) / currentPrice) * 100;
    final sign = potential >= 0 ? '+' : '';
    return '$sign${potential.toStringAsFixed(1)}%';
  }

  /// Check if consensus is bullish (consensus target > current price)
  bool isBullish(double currentPrice) {
    if (targetConsensus == null) return false;
    return targetConsensus! > currentPrice;
  }

  @override
  String toString() {
    return 'PriceTargetConsensus(symbol: $symbol, consensus: $targetConsensus, analysts: $numberOfAnalysts)';
  }
}

/// Discounted Cash Flow (DCF) Analysis model
class DcfAnalysis {
  final String symbol;
  final String? year;
  final double? revenue;
  final double? revenuePercentage;
  final double? ebitda;
  final double? ebitdaPercentage;
  final double? ebit;
  final double? ebitPercentage;
  final double? depreciation;
  final double? depreciationPercentage;
  final double? totalCash;
  final double? totalCashPercentage;
  final double? receivables;
  final double? receivablesPercentage;
  final double? inventories;
  final double? inventoriesPercentage;
  final double? payable;
  final double? payablePercentage;
  final double? capitalExpenditure;
  final double? capitalExpenditurePercentage;
  final double? price;
  final double? beta;
  final double? dilutedSharesOutstanding;
  final double? costOfDebt;
  final double? taxRate;
  final double? afterTaxCostOfDebt;
  final double? riskFreeRate;
  final double? marketRiskPremium;
  final double? costOfEquity;
  final double? totalDebt;
  final double? totalEquity;
  final double? totalCapital;
  final double? debtWeighting;
  final double? equityWeighting;
  final double? wacc;
  final double? taxRateCash;
  final double? ebiat;
  final double? ufcf;
  final double? sumPvUfcf;
  final double? longTermGrowthRate;
  final double? terminalValue;
  final double? presentTerminalValue;
  final double? enterpriseValue;
  final double? netDebt;
  final double? equityValue;
  final double? equityValuePerShare;
  final double? freeCashFlowT1;

  DcfAnalysis({
    required this.symbol,
    this.year,
    this.revenue,
    this.revenuePercentage,
    this.ebitda,
    this.ebitdaPercentage,
    this.ebit,
    this.ebitPercentage,
    this.depreciation,
    this.depreciationPercentage,
    this.totalCash,
    this.totalCashPercentage,
    this.receivables,
    this.receivablesPercentage,
    this.inventories,
    this.inventoriesPercentage,
    this.payable,
    this.payablePercentage,
    this.capitalExpenditure,
    this.capitalExpenditurePercentage,
    this.price,
    this.beta,
    this.dilutedSharesOutstanding,
    this.costOfDebt,
    this.taxRate,
    this.afterTaxCostOfDebt,
    this.riskFreeRate,
    this.marketRiskPremium,
    this.costOfEquity,
    this.totalDebt,
    this.totalEquity,
    this.totalCapital,
    this.debtWeighting,
    this.equityWeighting,
    this.wacc,
    this.taxRateCash,
    this.ebiat,
    this.ufcf,
    this.sumPvUfcf,
    this.longTermGrowthRate,
    this.terminalValue,
    this.presentTerminalValue,
    this.enterpriseValue,
    this.netDebt,
    this.equityValue,
    this.equityValuePerShare,
    this.freeCashFlowT1,
  });

  factory DcfAnalysis.fromJson(Map<String, dynamic> json) {
    return DcfAnalysis(
      symbol: json['symbol']?.toString() ?? '',
      year: json['year']?.toString(),
      revenue: _parseDouble(json['revenue']),
      revenuePercentage: _parseDouble(json['revenuePercentage']),
      ebitda: _parseDouble(json['ebitda']),
      ebitdaPercentage: _parseDouble(json['ebitdaPercentage']),
      ebit: _parseDouble(json['ebit']),
      ebitPercentage: _parseDouble(json['ebitPercentage']),
      depreciation: _parseDouble(json['depreciation']),
      depreciationPercentage: _parseDouble(json['depreciationPercentage']),
      totalCash: _parseDouble(json['totalCash']),
      totalCashPercentage: _parseDouble(json['totalCashPercentage']),
      receivables: _parseDouble(json['receivables']),
      receivablesPercentage: _parseDouble(json['receivablesPercentage']),
      inventories: _parseDouble(json['inventories']),
      inventoriesPercentage: _parseDouble(json['inventoriesPercentage']),
      payable: _parseDouble(json['payable']),
      payablePercentage: _parseDouble(json['payablePercentage']),
      capitalExpenditure: _parseDouble(json['capitalExpenditure']),
      capitalExpenditurePercentage: _parseDouble(
        json['capitalExpenditurePercentage'],
      ),
      price: _parseDouble(json['price']),
      beta: _parseDouble(json['beta']),
      dilutedSharesOutstanding: _parseDouble(json['dilutedSharesOutstanding']),
      costOfDebt: _parseDouble(json['costofDebt']),
      taxRate: _parseDouble(json['taxRate']),
      afterTaxCostOfDebt: _parseDouble(json['afterTaxCostOfDebt']),
      riskFreeRate: _parseDouble(json['riskFreeRate']),
      marketRiskPremium: _parseDouble(json['marketRiskPremium']),
      costOfEquity: _parseDouble(json['costOfEquity']),
      totalDebt: _parseDouble(json['totalDebt']),
      totalEquity: _parseDouble(json['totalEquity']),
      totalCapital: _parseDouble(json['totalCapital']),
      debtWeighting: _parseDouble(json['debtWeighting']),
      equityWeighting: _parseDouble(json['equityWeighting']),
      wacc: _parseDouble(json['wacc']),
      taxRateCash: _parseDouble(json['taxRateCash']),
      ebiat: _parseDouble(json['ebiat']),
      ufcf: _parseDouble(json['ufcf']),
      sumPvUfcf: _parseDouble(json['sumPvUfcf']),
      longTermGrowthRate: _parseDouble(json['longTermGrowthRate']),
      terminalValue: _parseDouble(json['terminalValue']),
      presentTerminalValue: _parseDouble(json['presentTerminalValue']),
      enterpriseValue: _parseDouble(json['enterpriseValue']),
      netDebt: _parseDouble(json['netDebt']),
      equityValue: _parseDouble(json['equityValue']),
      equityValuePerShare: _parseDouble(json['equityValuePerShare']),
      freeCashFlowT1: _parseDouble(json['freeCashFlowT1']),
    );
  }

  /// Helper method to safely parse double from dynamic value
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Get formatted equity value per share (DCF fair value)
  String get formattedFairValue {
    if (equityValuePerShare == null) return 'N/A';
    return '\$${equityValuePerShare!.toStringAsFixed(2)}';
  }

  /// Get formatted current price
  String get formattedCurrentPrice {
    if (price == null) return 'N/A';
    return '\$${price!.toStringAsFixed(2)}';
  }

  /// Get formatted WACC (Weighted Average Cost of Capital)
  String get formattedWacc {
    if (wacc == null) return 'N/A';
    return '${wacc!.toStringAsFixed(2)}%';
  }

  /// Get formatted enterprise value
  String get formattedEnterpriseValue {
    if (enterpriseValue == null) return 'N/A';
    final value = enterpriseValue! / 1000000000; // Convert to billions
    return '\$${value.toStringAsFixed(2)}B';
  }

  /// Calculate upside/downside potential
  String getValuationGap() {
    if (equityValuePerShare == null || price == null) return 'N/A';

    final gap = ((equityValuePerShare! - price!) / price!) * 100;
    final sign = gap >= 0 ? '+' : '';
    return '$sign${gap.toStringAsFixed(1)}%';
  }

  /// Check if stock is undervalued according to DCF
  bool get isUndervalued {
    if (equityValuePerShare == null || price == null) return false;
    return equityValuePerShare! > price!;
  }

  /// Get investment recommendation based on DCF
  String get recommendation {
    if (equityValuePerShare == null || price == null) return 'N/A';

    final upside = ((equityValuePerShare! - price!) / price!) * 100;

    if (upside > 20) return 'Strong Buy';
    if (upside > 10) return 'Buy';
    if (upside > -10) return 'Hold';
    if (upside > -20) return 'Sell';
    return 'Strong Sell';
  }

  /// Get color for recommendation
  String get recommendationColor {
    switch (recommendation) {
      case 'Strong Buy':
      case 'Buy':
        return 'green';
      case 'Hold':
        return 'orange';
      case 'Sell':
      case 'Strong Sell':
        return 'red';
      default:
        return 'gray';
    }
  }

  @override
  String toString() {
    return 'DcfAnalysis(symbol: $symbol, fairValue: $equityValuePerShare, currentPrice: $price)';
  }
}

/// Key Financial Metrics model
class KeyMetrics {
  final String symbol;
  final String? date;
  final String? fiscalYear;
  final String? period;
  final String? reportedCurrency;
  final double? marketCap;
  final double? enterpriseValue;
  final double? evToSales;
  final double? evToOperatingCashFlow;
  final double? evToFreeCashFlow;
  final double? evToEBITDA;
  final double? netDebtToEBITDA;
  final double? currentRatio;
  final double? incomeQuality;
  final double? grahamNumber;
  final double? grahamNetNet;
  final double? taxBurden;
  final double? interestBurden;
  final double? workingCapital;
  final double? investedCapital;
  final double? returnOnAssets;
  final double? operatingReturnOnAssets;
  final double? returnOnTangibleAssets;
  final double? returnOnEquity;
  final double? returnOnInvestedCapital;
  final double? returnOnCapitalEmployed;
  final double? earningsYield;
  final double? freeCashFlowYield;
  final double? capexToOperatingCashFlow;
  final double? capexToDepreciation;
  final double? capexToRevenue;
  final double? salesGeneralAndAdministrativeToRevenue;
  final double? researchAndDevelopementToRevenue;
  final double? stockBasedCompensationToRevenue;
  final double? intangiblesToTotalAssets;
  final double? averageReceivables;
  final double? averagePayables;
  final double? averageInventory;
  final double? daysOfSalesOutstanding;
  final double? daysOfPayablesOutstanding;
  final double? daysOfInventoryOutstanding;
  final double? operatingCycle;
  final double? cashConversionCycle;
  final double? freeCashFlowToEquity;
  final double? freeCashFlowToFirm;
  final double? tangibleAssetValue;
  final double? netCurrentAssetValue;

  KeyMetrics({
    required this.symbol,
    this.date,
    this.fiscalYear,
    this.period,
    this.reportedCurrency,
    this.marketCap,
    this.enterpriseValue,
    this.evToSales,
    this.evToOperatingCashFlow,
    this.evToFreeCashFlow,
    this.evToEBITDA,
    this.netDebtToEBITDA,
    this.currentRatio,
    this.incomeQuality,
    this.grahamNumber,
    this.grahamNetNet,
    this.taxBurden,
    this.interestBurden,
    this.workingCapital,
    this.investedCapital,
    this.returnOnAssets,
    this.operatingReturnOnAssets,
    this.returnOnTangibleAssets,
    this.returnOnEquity,
    this.returnOnInvestedCapital,
    this.returnOnCapitalEmployed,
    this.earningsYield,
    this.freeCashFlowYield,
    this.capexToOperatingCashFlow,
    this.capexToDepreciation,
    this.capexToRevenue,
    this.salesGeneralAndAdministrativeToRevenue,
    this.researchAndDevelopementToRevenue,
    this.stockBasedCompensationToRevenue,
    this.intangiblesToTotalAssets,
    this.averageReceivables,
    this.averagePayables,
    this.averageInventory,
    this.daysOfSalesOutstanding,
    this.daysOfPayablesOutstanding,
    this.daysOfInventoryOutstanding,
    this.operatingCycle,
    this.cashConversionCycle,
    this.freeCashFlowToEquity,
    this.freeCashFlowToFirm,
    this.tangibleAssetValue,
    this.netCurrentAssetValue,
  });

  factory KeyMetrics.fromJson(Map<String, dynamic> json) {
    return KeyMetrics(
      symbol: json['symbol']?.toString() ?? '',
      date: json['date']?.toString(),
      fiscalYear: json['fiscalYear']?.toString(),
      period: json['period']?.toString(),
      reportedCurrency: json['reportedCurrency']?.toString(),
      marketCap: _parseDouble(json['marketCap']),
      enterpriseValue: _parseDouble(json['enterpriseValue']),
      evToSales: _parseDouble(json['evToSales']),
      evToOperatingCashFlow: _parseDouble(json['evToOperatingCashFlow']),
      evToFreeCashFlow: _parseDouble(json['evToFreeCashFlow']),
      evToEBITDA: _parseDouble(json['evToEBITDA']),
      netDebtToEBITDA: _parseDouble(json['netDebtToEBITDA']),
      currentRatio: _parseDouble(json['currentRatio']),
      incomeQuality: _parseDouble(json['incomeQuality']),
      grahamNumber: _parseDouble(json['grahamNumber']),
      grahamNetNet: _parseDouble(json['grahamNetNet']),
      taxBurden: _parseDouble(json['taxBurden']),
      interestBurden: _parseDouble(json['interestBurden']),
      workingCapital: _parseDouble(json['workingCapital']),
      investedCapital: _parseDouble(json['investedCapital']),
      returnOnAssets: _parseDouble(json['returnOnAssets']),
      operatingReturnOnAssets: _parseDouble(json['operatingReturnOnAssets']),
      returnOnTangibleAssets: _parseDouble(json['returnOnTangibleAssets']),
      returnOnEquity: _parseDouble(json['returnOnEquity']),
      returnOnInvestedCapital: _parseDouble(json['returnOnInvestedCapital']),
      returnOnCapitalEmployed: _parseDouble(json['returnOnCapitalEmployed']),
      earningsYield: _parseDouble(json['earningsYield']),
      freeCashFlowYield: _parseDouble(json['freeCashFlowYield']),
      capexToOperatingCashFlow: _parseDouble(json['capexToOperatingCashFlow']),
      capexToDepreciation: _parseDouble(json['capexToDepreciation']),
      capexToRevenue: _parseDouble(json['capexToRevenue']),
      salesGeneralAndAdministrativeToRevenue: _parseDouble(
        json['salesGeneralAndAdministrativeToRevenue'],
      ),
      researchAndDevelopementToRevenue: _parseDouble(
        json['researchAndDevelopementToRevenue'],
      ),
      stockBasedCompensationToRevenue: _parseDouble(
        json['stockBasedCompensationToRevenue'],
      ),
      intangiblesToTotalAssets: _parseDouble(json['intangiblesToTotalAssets']),
      averageReceivables: _parseDouble(json['averageReceivables']),
      averagePayables: _parseDouble(json['averagePayables']),
      averageInventory: _parseDouble(json['averageInventory']),
      daysOfSalesOutstanding: _parseDouble(json['daysOfSalesOutstanding']),
      daysOfPayablesOutstanding: _parseDouble(
        json['daysOfPayablesOutstanding'],
      ),
      daysOfInventoryOutstanding: _parseDouble(
        json['daysOfInventoryOutstanding'],
      ),
      operatingCycle: _parseDouble(json['operatingCycle']),
      cashConversionCycle: _parseDouble(json['cashConversionCycle']),
      freeCashFlowToEquity: _parseDouble(json['freeCashFlowToEquity']),
      freeCashFlowToFirm: _parseDouble(json['freeCashFlowToFirm']),
      tangibleAssetValue: _parseDouble(json['tangibleAssetValue']),
      netCurrentAssetValue: _parseDouble(json['netCurrentAssetValue']),
    );
  }

  /// Helper method to safely parse double from dynamic value
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Get formatted market cap
  String get formattedMarketCap {
    if (marketCap == null) return 'N/A';
    final value = marketCap! / 1000000000; // Convert to billions
    return '\$${value.toStringAsFixed(2)}B';
  }

  /// Get formatted enterprise value
  String get formattedEnterpriseValue {
    if (enterpriseValue == null) return 'N/A';
    final value = enterpriseValue! / 1000000000; // Convert to billions
    return '\$${value.toStringAsFixed(2)}B';
  }

  /// Get formatted working capital
  String get formattedWorkingCapital {
    if (workingCapital == null) return 'N/A';
    final value = workingCapital! / 1000000000; // Convert to billions
    final sign = value >= 0 ? '' : '-';
    return '$sign\$${value.abs().toStringAsFixed(2)}B';
  }

  /// Get formatted percentage for ratios
  String formatPercentage(double? value, {int decimals = 2}) {
    if (value == null) return 'N/A';
    final percentage = value * 100;
    return '${percentage.toStringAsFixed(decimals)}%';
  }

  /// Get formatted ratio
  String formatRatio(double? value, {int decimals = 2}) {
    if (value == null) return 'N/A';
    return value.toStringAsFixed(decimals);
  }

  /// Get formatted days
  String formatDays(double? value) {
    if (value == null) return 'N/A';
    return '${value.toStringAsFixed(0)} days';
  }

  /// Get overall financial health score (0-100)
  int get financialHealthScore {
    int score = 50; // Start with neutral score

    // Current Ratio (good: >1.5, ok: >1.0, poor: <1.0)
    if (currentRatio != null) {
      if (currentRatio! > 1.5)
        score += 10;
      else if (currentRatio! > 1.0)
        score += 5;
      else
        score -= 10;
    }

    // Return on Equity (good: >15%, ok: >10%, poor: <5%)
    if (returnOnEquity != null) {
      if (returnOnEquity! > 0.15)
        score += 15;
      else if (returnOnEquity! > 0.10)
        score += 10;
      else if (returnOnEquity! < 0.05)
        score -= 10;
    }

    // Return on Assets (good: >10%, ok: >5%, poor: <2%)
    if (returnOnAssets != null) {
      if (returnOnAssets! > 0.10)
        score += 10;
      else if (returnOnAssets! > 0.05)
        score += 5;
      else if (returnOnAssets! < 0.02)
        score -= 10;
    }

    // Income Quality (good: >1.0, ok: >0.8, poor: <0.5)
    if (incomeQuality != null) {
      if (incomeQuality! > 1.0)
        score += 10;
      else if (incomeQuality! > 0.8)
        score += 5;
      else if (incomeQuality! < 0.5)
        score -= 10;
    }

    // Free Cash Flow Yield (good: >5%, ok: >2%, poor: <0%)
    if (freeCashFlowYield != null) {
      if (freeCashFlowYield! > 0.05)
        score += 10;
      else if (freeCashFlowYield! > 0.02)
        score += 5;
      else if (freeCashFlowYield! < 0)
        score -= 15;
    }

    return score.clamp(0, 100);
  }

  /// Get financial health description
  String get financialHealthDescription {
    final score = financialHealthScore;
    if (score >= 80) return 'Excellent';
    if (score >= 65) return 'Good';
    if (score >= 50) return 'Average';
    if (score >= 35) return 'Below Average';
    return 'Poor';
  }

  @override
  String toString() {
    return 'KeyMetrics(symbol: $symbol, fiscalYear: $fiscalYear, marketCap: $marketCap)';
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
