import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  /// Get financial ratios for a stock
  ///
  /// [symbol] - Stock symbol (e.g., 'AAPL')
  /// [limit] - Number of periods to fetch (default: 5)
  /// [period] - Period type ('annual' or 'quarter', default: 'annual')
  /// Returns comprehensive financial ratios
  Future<List<FinancialRatios>> getFinancialRatios(
    String symbol, {
    int limit = 5,
    String period = 'annual',
  }) async {
    try {
      if (symbol.trim().isEmpty) {
        throw ApiException('Stock symbol cannot be empty', 400, '');
      }

      final cleanSymbol = symbol.trim().toUpperCase();
      debugPrint('📊 Fetching financial ratios for: $cleanSymbol');

      final url = Uri.parse(
        'https://financialmodelingprep.com/stable/ratios?symbol=$cleanSymbol&limit=$limit&period=$period&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ Financial ratios not available for $cleanSymbol');
        return [];
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        debugPrint('⚠️ No financial ratios data for $cleanSymbol');
        return [];
      }

      final ratios = data
          .map((item) => FinancialRatios.fromJson(item))
          .toList();
      debugPrint(
        '📊 Loaded ${ratios.length} financial ratios periods for $cleanSymbol',
      );
      return ratios;
    } catch (e) {
      debugPrint('❌ Error fetching financial ratios for $symbol: $e');
      return [];
    }
  }

  /// Get financial scores (Altman Z-Score and Piotroski Score) for a stock
  ///
  /// Returns financial health scores for bankruptcy prediction and company analysis
  /// Includes Altman Z-Score for bankruptcy risk and Piotroski Score for financial health
  Future<FinancialScores?> getFinancialScores(String symbol) async {
    try {
      if (symbol.trim().isEmpty) {
        throw ApiException('Stock symbol cannot be empty', 400, '');
      }

      final cleanSymbol = symbol.trim().toUpperCase();
      debugPrint('📊 Fetching financial scores for: $cleanSymbol');

      final url = Uri.parse(
        'https://financialmodelingprep.com/stable/financial-scores?symbol=$cleanSymbol&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ Financial scores not available for $cleanSymbol');
        return null;
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        debugPrint('⚠️ No financial scores data for $cleanSymbol');
        return null;
      }

      final scores = FinancialScores.fromJson(data.first);
      debugPrint('📊 Loaded financial scores for $cleanSymbol');
      return scores;
    } catch (e) {
      debugPrint('❌ Error fetching financial scores for $symbol: $e');
      return null;
    }
  }

  /// Get sector performance snapshot for a specific date
  ///
  /// Returns sector performance data including average change percentages
  /// for different sectors and exchanges
  Future<List<SectorPerformance>> getSectorPerformance({String? date}) async {
    try {
      debugPrint(
        '📊 Fetching sector performance snapshot${date != null ? ' for $date' : ''}',
      );

      final queryParams = date != null
          ? '?date=$date&apikey=$_apiKey'
          : '?apikey=$_apiKey';
      final url = Uri.parse(
        'https://financialmodelingprep.com/stable/sector-performance-snapshot$queryParams',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ Sector performance data not available');
        return [];
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        debugPrint('⚠️ No sector performance data available');
        return [];
      }

      final sectors = data
          .map((item) => SectorPerformance.fromJson(item))
          .toList();
      debugPrint('📊 Loaded ${sectors.length} sector performance records');
      return sectors;
    } catch (e) {
      debugPrint('❌ Error fetching sector performance: $e');
      return [];
    }
  }

  /// Get insider trading data for a specific stock symbol
  ///
  /// Returns list of recent insider transactions (Form 4 filings)
  /// Shows executive and director buying/selling activity
  Future<List<InsiderTrading>> getInsiderTrading(
    String symbol, {
    int limit = 50,
  }) async {
    try {
      debugPrint('📈 Fetching insider trading data for $symbol...');

      final url = Uri.parse(
        'https://financialmodelingprep.com/stable/insider-trading/search'
        '?page=0&limit=$limit&symbol=$symbol&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ Insider trading data not available for $symbol');
        return [];
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        debugPrint('⚠️ No insider trading data available for $symbol');
        return [];
      }

      final insiderTrades = data
          .map((item) => InsiderTrading.fromJson(item))
          .toList();

      // Sort by transaction date (most recent first)
      insiderTrades.sort(
        (a, b) => b.transactionDate.compareTo(a.transactionDate),
      );

      debugPrint(
        '📈 Loaded ${insiderTrades.length} insider trading records for $symbol',
      );
      return insiderTrades;
    } catch (e) {
      debugPrint('❌ Error fetching insider trading data: $e');
      return [];
    }
  }

  /// Get revenue product segmentation data
  /// Returns revenue breakdown by product categories for the specified symbol
  Future<List<RevenueSegmentation>> getRevenueProductSegmentation(
    String symbol,
  ) async {
    try {
      debugPrint('📊 Fetching revenue product segmentation for $symbol...');

      final url = Uri.parse(
        'https://financialmodelingprep.com/stable/revenue-product-segmentation'
        '?symbol=$symbol&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ Revenue segmentation data not available for $symbol');
        return [];
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        debugPrint('⚠️ No revenue segmentation data available for $symbol');
        return [];
      }

      final segmentation = data
          .map((item) => RevenueSegmentation.fromJson(item))
          .toList();

      debugPrint(
        '📊 Loaded ${segmentation.length} revenue segmentation records for $symbol',
      );
      return segmentation;
    } catch (e) {
      debugPrint('❌ Error fetching revenue segmentation data: $e');
      return [];
    }
  }

  /// Get revenue geographic segmentation data
  /// Returns revenue breakdown by geography/region for the specified symbol
  Future<List<RevenueSegmentation>> getRevenueGeographicSegmentation(
    String symbol,
  ) async {
    try {
      debugPrint('📊 Fetching revenue geographic segmentation for $symbol...');

      final url = Uri.parse(
        'https://financialmodelingprep.com/stable/revenue-geographic-segmentation'
        '?symbol=$symbol&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint(
          '⚠️ Revenue geographic segmentation data not available for $symbol',
        );
        return [];
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        debugPrint(
          '⚠️ No revenue geographic segmentation data available for $symbol',
        );
        return [];
      }

      final segmentation = data
          .map((item) => RevenueSegmentation.fromJson(item))
          .toList();

      debugPrint(
        '📊 Loaded ${segmentation.length} revenue geographic segmentation records for $symbol',
      );
      return segmentation;
    } catch (e) {
      debugPrint('❌ Error fetching revenue geographic segmentation data: $e');
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
        final quoteData = data.first as Map<String, dynamic>;

        // Try to fetch profile data for yearHigh/yearLow
        double? yearHigh;
        double? yearLow;
        try {
          final profileUrl = Uri.parse(
            '$_baseUrl/profile/$symbol?apikey=$_apiKey',
          );
          debugPrint('📊 Fetching profile data for $symbol...');
          final profileResponse = await http.get(profileUrl);

          debugPrint(
            '📊 Profile response status: ${profileResponse.statusCode}',
          );
          if (profileResponse.statusCode == 200) {
            final List<dynamic> profileData = json.decode(profileResponse.body);
            debugPrint('📊 Profile data received: ${profileData.length} items');
            if (profileData.isNotEmpty) {
              final profile = profileData.first as Map<String, dynamic>;
              yearHigh = profile['yearHigh']?.toDouble();
              yearLow = profile['yearLow']?.toDouble();
              debugPrint('📊 Year data: high=$yearHigh, low=$yearLow');
            } else {
              debugPrint('📊 Profile data is empty');
            }
          } else {
            debugPrint('📊 Profile request failed: ${profileResponse.body}');
          }
        } catch (e) {
          debugPrint('⚠️ Could not fetch profile data for $symbol: $e');
        }

        // If profile data didn't work, try to calculate from historical data
        if (yearHigh == null || yearLow == null) {
          try {
            debugPrint('📈 Calculating 52-week range from historical data...');
            final historicalData = await getCommodityHistoricalData(
              type,
              days: 365,
            );
            if (historicalData.isNotEmpty) {
              yearHigh = historicalData
                  .map((point) => point.high)
                  .reduce((a, b) => a > b ? a : b);
              yearLow = historicalData
                  .map((point) => point.low)
                  .reduce((a, b) => a < b ? a : b);
              debugPrint(
                '📈 Year data from historical: high=$yearHigh, low=$yearLow',
              );
            }
          } catch (e) {
            debugPrint(
              '⚠️ Could not calculate year range from historical data: $e',
            );
          }
        }

        final commodity = Commodity(
          symbol: quoteData['symbol']?.toString() ?? '',
          name:
              quoteData['name']?.toString() ??
              _getCommodityNameFromSymbol(quoteData['symbol'] ?? ''),
          price: (quoteData['price'] ?? 0.0).toDouble(),
          change: (quoteData['change'] ?? 0.0).toDouble(),
          changePercent: (quoteData['changesPercentage'] ?? 0.0).toDouble(),
          type: type,
          currency: 'USD',
          dayHigh: quoteData['dayHigh']?.toDouble(),
          dayLow: quoteData['dayLow']?.toDouble(),
          yearHigh: yearHigh,
          yearLow: yearLow,
          open: quoteData['open']?.toDouble(),
          previousClose: quoteData['previousClose']?.toDouble(),
          lastUpdated: DateTime.now(),
        );

        debugPrint(
          '✅ $type price fetched: ${commodity.formattedPrice} (${commodity.formattedChangePercent})',
        );

        return commodity;
      } else {
        debugPrint('⚠️ No $type price data available');
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error fetching $type price: $e');
      throw ApiException('Failed to fetch $type price', 0, e.toString());
    }
  }

  /// Get index price data using the stable quote endpoint
  Future<Index?> getIndexPrice(String symbol) async {
    try {
      debugPrint('📊 Fetching index $symbol price...');

      final url = Uri.parse('$_baseUrl/quote/$symbol?apikey=$_apiKey');
      debugPrint('📊 URL: $url');

      final response = await http.get(url);
      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📊 Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to fetch $symbol index price',
          response.statusCode,
          response.body,
        );
      }

      final List<dynamic> data = json.decode(response.body);
      debugPrint('📊 Parsed data length: ${data.length}');

      if (data.isNotEmpty) {
        final quoteData = data.first as Map<String, dynamic>;
        debugPrint('📊 Quote data keys: ${quoteData.keys.toList()}');
        debugPrint('📊 Symbol from API: ${quoteData['symbol']}');
        debugPrint('📊 Price from API: ${quoteData['price']}');

        final index = Index(
          symbol: quoteData['symbol']?.toString() ?? '',
          name:
              quoteData['name']?.toString() ??
              _getIndexNameFromSymbol(quoteData['symbol'] ?? ''),
          price: (quoteData['price'] ?? 0.0).toDouble(),
          change: (quoteData['change'] ?? 0.0).toDouble(),
          changePercent: (quoteData['changesPercentage'] ?? 0.0).toDouble(),
          currency: 'USD',
          dayHigh: quoteData['dayHigh']?.toDouble(),
          dayLow: quoteData['dayLow']?.toDouble(),
          yearHigh: quoteData['yearHigh']?.toDouble(),
          yearLow: quoteData['yearLow']?.toDouble(),
          open: quoteData['open']?.toDouble(),
          previousClose: quoteData['previousClose']?.toDouble(),
          lastUpdated: DateTime.now(),
        );

        debugPrint(
          '✅ $symbol index price fetched: ${index.formattedPrice} (${index.formattedChangePercent})',
        );

        return index;
      } else {
        debugPrint('⚠️ No $symbol index price data available');
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error fetching $symbol index price: $e');
      throw ApiException(
        'Failed to fetch $symbol index price',
        0,
        e.toString(),
      );
    }
  }

  /// Get index name from symbol
  String _getIndexNameFromSymbol(String symbol) {
    switch (symbol.toUpperCase()) {
      case '^GSPC':
        return 'S&P 500';
      case '^DJI':
        return 'Dow Jones Industrial Average';
      case '^STOXX50E':
        return 'Euro Stoxx 50';
      case '^IXIC':
        return 'NASDAQ Composite';
      case '^RUT':
        return 'Russell 2000';
      case '^FTSE':
        return 'FTSE 100';
      case '^N225':
        return 'Nikkei 225';
      case '^HSI':
        return 'Hang Seng';
      case '^VIX':
        return 'VIX';
      default:
        return symbol;
    }
  }

  /// Get historical index data for charting
  Future<List<CommodityHistoricalPoint>> getIndexHistoricalData(
    String symbol, {
    int days = 30,
  }) async {
    try {
      debugPrint('📈 Fetching $symbol historical data for $days days...');

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
          'Failed to fetch $symbol historical data',
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

      debugPrint('✅ Fetched ${points.length} $symbol historical data points');
      return points;
    } catch (e) {
      debugPrint('❌ Error fetching $symbol historical data: $e');
      throw ApiException(
        'Failed to fetch $symbol historical data',
        0,
        e.toString(),
      );
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

  String _getCommodityNameFromSymbol(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'GCUSD':
        return 'Gold';
      case 'SIUSD':
        return 'Silver';
      case 'BZUSD':
        return 'Crude Oil';
      default:
        return symbol; // fallback to symbol if unknown
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

/// Financial Ratios model
class FinancialRatios {
  final String symbol;
  final String? date;
  final String? fiscalYear;
  final String? period;
  final String? reportedCurrency;

  // Profitability Ratios
  final double? grossProfitMargin;
  final double? ebitMargin;
  final double? ebitdaMargin;
  final double? operatingProfitMargin;
  final double? pretaxProfitMargin;
  final double? netProfitMargin;

  // Turnover Ratios
  final double? receivablesTurnover;
  final double? payablesTurnover;
  final double? inventoryTurnover;
  final double? fixedAssetTurnover;
  final double? assetTurnover;

  // Liquidity Ratios
  final double? currentRatio;
  final double? quickRatio;
  final double? solvencyRatio;
  final double? cashRatio;

  // Valuation Ratios
  final double? priceToEarningsRatio;
  final double? priceToEarningsGrowthRatio;
  final double? forwardPriceToEarningsGrowthRatio;
  final double? priceToBookRatio;
  final double? priceToSalesRatio;
  final double? priceToFreeCashFlowRatio;
  final double? priceToOperatingCashFlowRatio;

  // Leverage Ratios
  final double? debtToAssetsRatio;
  final double? debtToEquityRatio;
  final double? debtToCapitalRatio;
  final double? longTermDebtToCapitalRatio;
  final double? financialLeverageRatio;

  // Efficiency Ratios
  final double? workingCapitalTurnoverRatio;
  final double? operatingCashFlowRatio;
  final double? operatingCashFlowSalesRatio;
  final double? freeCashFlowOperatingCashFlowRatio;

  // Coverage Ratios
  final double? debtServiceCoverageRatio;
  final double? interestCoverageRatio;
  final double? shortTermOperatingCashFlowCoverageRatio;
  final double? operatingCashFlowCoverageRatio;
  final double? capitalExpenditureCoverageRatio;
  final double? dividendPaidAndCapexCoverageRatio;

  // Dividend Ratios
  final double? dividendPayoutRatio;
  final double? dividendYield;
  final double? dividendYieldPercentage;

  // Per Share Ratios
  final double? revenuePerShare;
  final double? netIncomePerShare;
  final double? interestDebtPerShare;
  final double? cashPerShare;
  final double? bookValuePerShare;
  final double? tangibleBookValuePerShare;
  final double? shareholdersEquityPerShare;
  final double? operatingCashFlowPerShare;
  final double? capexPerShare;
  final double? freeCashFlowPerShare;

  // Other Ratios
  final double? netIncomePerEBT;
  final double? ebtPerEbit;
  final double? priceToFairValue;
  final double? debtToMarketCap;
  final double? effectiveTaxRate;
  final double? enterpriseValueMultiple;
  final double? dividendPerShare;

  FinancialRatios({
    required this.symbol,
    this.date,
    this.fiscalYear,
    this.period,
    this.reportedCurrency,
    this.grossProfitMargin,
    this.ebitMargin,
    this.ebitdaMargin,
    this.operatingProfitMargin,
    this.pretaxProfitMargin,
    this.netProfitMargin,
    this.receivablesTurnover,
    this.payablesTurnover,
    this.inventoryTurnover,
    this.fixedAssetTurnover,
    this.assetTurnover,
    this.currentRatio,
    this.quickRatio,
    this.solvencyRatio,
    this.cashRatio,
    this.priceToEarningsRatio,
    this.priceToEarningsGrowthRatio,
    this.forwardPriceToEarningsGrowthRatio,
    this.priceToBookRatio,
    this.priceToSalesRatio,
    this.priceToFreeCashFlowRatio,
    this.priceToOperatingCashFlowRatio,
    this.debtToAssetsRatio,
    this.debtToEquityRatio,
    this.debtToCapitalRatio,
    this.longTermDebtToCapitalRatio,
    this.financialLeverageRatio,
    this.workingCapitalTurnoverRatio,
    this.operatingCashFlowRatio,
    this.operatingCashFlowSalesRatio,
    this.freeCashFlowOperatingCashFlowRatio,
    this.debtServiceCoverageRatio,
    this.interestCoverageRatio,
    this.shortTermOperatingCashFlowCoverageRatio,
    this.operatingCashFlowCoverageRatio,
    this.capitalExpenditureCoverageRatio,
    this.dividendPaidAndCapexCoverageRatio,
    this.dividendPayoutRatio,
    this.dividendYield,
    this.dividendYieldPercentage,
    this.revenuePerShare,
    this.netIncomePerShare,
    this.interestDebtPerShare,
    this.cashPerShare,
    this.bookValuePerShare,
    this.tangibleBookValuePerShare,
    this.shareholdersEquityPerShare,
    this.operatingCashFlowPerShare,
    this.capexPerShare,
    this.freeCashFlowPerShare,
    this.netIncomePerEBT,
    this.ebtPerEbit,
    this.priceToFairValue,
    this.debtToMarketCap,
    this.effectiveTaxRate,
    this.enterpriseValueMultiple,
    this.dividendPerShare,
  });

  factory FinancialRatios.fromJson(Map<String, dynamic> json) {
    return FinancialRatios(
      symbol: json['symbol']?.toString() ?? '',
      date: json['date']?.toString(),
      fiscalYear: json['fiscalYear']?.toString(),
      period: json['period']?.toString(),
      reportedCurrency: json['reportedCurrency']?.toString(),
      grossProfitMargin: _parseDouble(json['grossProfitMargin']),
      ebitMargin: _parseDouble(json['ebitMargin']),
      ebitdaMargin: _parseDouble(json['ebitdaMargin']),
      operatingProfitMargin: _parseDouble(json['operatingProfitMargin']),
      pretaxProfitMargin: _parseDouble(json['pretaxProfitMargin']),
      netProfitMargin: _parseDouble(json['netProfitMargin']),
      receivablesTurnover: _parseDouble(json['receivablesTurnover']),
      payablesTurnover: _parseDouble(json['payablesTurnover']),
      inventoryTurnover: _parseDouble(json['inventoryTurnover']),
      fixedAssetTurnover: _parseDouble(json['fixedAssetTurnover']),
      assetTurnover: _parseDouble(json['assetTurnover']),
      currentRatio: _parseDouble(json['currentRatio']),
      quickRatio: _parseDouble(json['quickRatio']),
      solvencyRatio: _parseDouble(json['solvencyRatio']),
      cashRatio: _parseDouble(json['cashRatio']),
      priceToEarningsRatio: _parseDouble(json['priceToEarningsRatio']),
      priceToEarningsGrowthRatio: _parseDouble(
        json['priceToEarningsGrowthRatio'],
      ),
      forwardPriceToEarningsGrowthRatio: _parseDouble(
        json['forwardPriceToEarningsGrowthRatio'],
      ),
      priceToBookRatio: _parseDouble(json['priceToBookRatio']),
      priceToSalesRatio: _parseDouble(json['priceToSalesRatio']),
      priceToFreeCashFlowRatio: _parseDouble(json['priceToFreeCashFlowRatio']),
      priceToOperatingCashFlowRatio: _parseDouble(
        json['priceToOperatingCashFlowRatio'],
      ),
      debtToAssetsRatio: _parseDouble(json['debtToAssetsRatio']),
      debtToEquityRatio: _parseDouble(json['debtToEquityRatio']),
      debtToCapitalRatio: _parseDouble(json['debtToCapitalRatio']),
      longTermDebtToCapitalRatio: _parseDouble(
        json['longTermDebtToCapitalRatio'],
      ),
      financialLeverageRatio: _parseDouble(json['financialLeverageRatio']),
      workingCapitalTurnoverRatio: _parseDouble(
        json['workingCapitalTurnoverRatio'],
      ),
      operatingCashFlowRatio: _parseDouble(json['operatingCashFlowRatio']),
      operatingCashFlowSalesRatio: _parseDouble(
        json['operatingCashFlowSalesRatio'],
      ),
      freeCashFlowOperatingCashFlowRatio: _parseDouble(
        json['freeCashFlowOperatingCashFlowRatio'],
      ),
      debtServiceCoverageRatio: _parseDouble(json['debtServiceCoverageRatio']),
      interestCoverageRatio: _parseDouble(json['interestCoverageRatio']),
      shortTermOperatingCashFlowCoverageRatio: _parseDouble(
        json['shortTermOperatingCashFlowCoverageRatio'],
      ),
      operatingCashFlowCoverageRatio: _parseDouble(
        json['operatingCashFlowCoverageRatio'],
      ),
      capitalExpenditureCoverageRatio: _parseDouble(
        json['capitalExpenditureCoverageRatio'],
      ),
      dividendPaidAndCapexCoverageRatio: _parseDouble(
        json['dividendPaidAndCapexCoverageRatio'],
      ),
      dividendPayoutRatio: _parseDouble(json['dividendPayoutRatio']),
      dividendYield: _parseDouble(json['dividendYield']),
      dividendYieldPercentage: _parseDouble(json['dividendYieldPercentage']),
      revenuePerShare: _parseDouble(json['revenuePerShare']),
      netIncomePerShare: _parseDouble(json['netIncomePerShare']),
      interestDebtPerShare: _parseDouble(json['interestDebtPerShare']),
      cashPerShare: _parseDouble(json['cashPerShare']),
      bookValuePerShare: _parseDouble(json['bookValuePerShare']),
      tangibleBookValuePerShare: _parseDouble(
        json['tangibleBookValuePerShare'],
      ),
      shareholdersEquityPerShare: _parseDouble(
        json['shareholdersEquityPerShare'],
      ),
      operatingCashFlowPerShare: _parseDouble(
        json['operatingCashFlowPerShare'],
      ),
      capexPerShare: _parseDouble(json['capexPerShare']),
      freeCashFlowPerShare: _parseDouble(json['freeCashFlowPerShare']),
      netIncomePerEBT: _parseDouble(json['netIncomePerEBT']),
      ebtPerEbit: _parseDouble(json['ebtPerEbit']),
      priceToFairValue: _parseDouble(json['priceToFairValue']),
      debtToMarketCap: _parseDouble(json['debtToMarketCap']),
      effectiveTaxRate: _parseDouble(json['effectiveTaxRate']),
      enterpriseValueMultiple: _parseDouble(json['enterpriseValueMultiple']),
      dividendPerShare: _parseDouble(json['dividendPerShare']),
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

  /// Format ratio as percentage
  String formatPercentage(double? value) {
    if (value == null) return 'N/A';
    return '${(value * 100).toStringAsFixed(2)}%';
  }

  /// Format ratio as decimal
  String formatRatio(double? value) {
    if (value == null) return 'N/A';
    return value.toStringAsFixed(2);
  }

  /// Format currency value
  String formatCurrency(double? value) {
    if (value == null) return 'N/A';
    return '\$${value.toStringAsFixed(2)}';
  }

  /// Get formatted fiscal year period
  String get formattedPeriod {
    if (fiscalYear == null) return 'N/A';
    if (period == null) return 'FY $fiscalYear';
    return '$period $fiscalYear';
  }

  @override
  String toString() {
    return 'FinancialRatios(symbol: $symbol, fiscalYear: $fiscalYear, period: $period)';
  }
}

/// Financial Scores model for Altman Z-Score and Piotroski Score analysis
/// Provides bankruptcy prediction and financial health scoring
class FinancialScores {
  final String symbol;
  final String? reportedCurrency;
  final double? altmanZScore;
  final int? piotroskiScore;
  final double? workingCapital;
  final double? totalAssets;
  final double? retainedEarnings;
  final double? ebit;
  final double? marketCap;
  final double? totalLiabilities;
  final double? revenue;

  FinancialScores({
    required this.symbol,
    this.reportedCurrency,
    this.altmanZScore,
    this.piotroskiScore,
    this.workingCapital,
    this.totalAssets,
    this.retainedEarnings,
    this.ebit,
    this.marketCap,
    this.totalLiabilities,
    this.revenue,
  });

  factory FinancialScores.fromJson(Map<String, dynamic> json) {
    return FinancialScores(
      symbol: json['symbol']?.toString() ?? '',
      reportedCurrency: json['reportedCurrency']?.toString(),
      altmanZScore: _parseDouble(json['altmanZScore']),
      piotroskiScore: json['piotroskiScore'] is int
          ? json['piotroskiScore']
          : int.tryParse(json['piotroskiScore']?.toString() ?? ''),
      workingCapital: _parseDouble(json['workingCapital']),
      totalAssets: _parseDouble(json['totalAssets']),
      retainedEarnings: _parseDouble(json['retainedEarnings']),
      ebit: _parseDouble(json['ebit']),
      marketCap: _parseDouble(json['marketCap']),
      totalLiabilities: _parseDouble(json['totalLiabilities']),
      revenue: _parseDouble(json['revenue']),
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

  /// Format currency value
  String formatCurrency(double? value) {
    if (value == null) return 'N/A';
    return '\$${value.abs().toStringAsFixed(0)}';
  }

  /// Get Altman Z-Score interpretation
  String getAltmanZScoreInterpretation() {
    if (altmanZScore == null) return 'N/A';

    if (altmanZScore! >= 3.0) {
      return 'Safe Zone (Low Bankruptcy Risk)';
    } else if (altmanZScore! >= 1.8) {
      return 'Grey Zone (Moderate Risk)';
    } else {
      return 'Distress Zone (High Bankruptcy Risk)';
    }
  }

  /// Get Altman Z-Score color
  String getAltmanZScoreColor() {
    if (altmanZScore == null) return 'grey';

    if (altmanZScore! >= 3.0) {
      return 'green';
    } else if (altmanZScore! >= 1.8) {
      return 'yellow';
    } else {
      return 'red';
    }
  }

  /// Get Piotroski Score interpretation
  String getPiotroskiScoreInterpretation() {
    if (piotroskiScore == null) return 'N/A';

    if (piotroskiScore! >= 7) {
      return 'Strong Financial Health';
    } else if (piotroskiScore! >= 4) {
      return 'Moderate Financial Health';
    } else {
      return 'Weak Financial Health';
    }
  }

  /// Get Piotroski Score color
  String getPiotroskiScoreColor() {
    if (piotroskiScore == null) return 'grey';

    if (piotroskiScore! >= 7) {
      return 'green';
    } else if (piotroskiScore! >= 4) {
      return 'yellow';
    } else {
      return 'red';
    }
  }

  /// Calculate Altman Z-Score components for display
  Map<String, double?> getAltmanZScoreComponents() {
    if (workingCapital == null ||
        totalAssets == null ||
        retainedEarnings == null ||
        ebit == null ||
        marketCap == null ||
        totalLiabilities == null ||
        revenue == null) {
      return {};
    }

    final wcToTa = workingCapital! / totalAssets!;
    final reToTa = retainedEarnings! / totalAssets!;
    final ebitToTa = ebit! / totalAssets!;
    final mvToTl = marketCap! / totalLiabilities!;
    final salesToTa = revenue! / totalAssets!;

    return {
      'Working Capital / Total Assets': wcToTa,
      'Retained Earnings / Total Assets': reToTa,
      'EBIT / Total Assets': ebitToTa,
      'Market Value of Equity / Total Liabilities': mvToTl,
      'Sales / Total Assets': salesToTa,
    };
  }

  /// Calculate Piotroski Score components for display
  Map<String, bool?> getPiotroskiScoreComponents() {
    // This would require more detailed financial data to calculate properly
    // For now, we'll return empty as we don't have all the required metrics
    return {};
  }

  @override
  String toString() {
    return 'FinancialScores(symbol: $symbol, altmanZScore: $altmanZScore, piotroskiScore: $piotroskiScore)';
  }
}

/// Sector Performance model for sector performance snapshots
/// Provides sector-level performance data and comparisons
class SectorPerformance {
  final String date;
  final String sector;
  final String exchange;
  final double averageChange;

  SectorPerformance({
    required this.date,
    required this.sector,
    required this.exchange,
    required this.averageChange,
  });

  factory SectorPerformance.fromJson(Map<String, dynamic> json) {
    return SectorPerformance(
      date: json['date']?.toString() ?? '',
      sector: json['sector']?.toString() ?? '',
      exchange: json['exchange']?.toString() ?? '',
      averageChange: _parseDouble(json['averageChange']) ?? 0.0,
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

  /// Format percentage change
  String formatPercentage() {
    return '${averageChange >= 0 ? '+' : ''}${averageChange.toStringAsFixed(2)}%';
  }

  /// Get performance color
  Color getPerformanceColor() {
    if (averageChange > 0) return Colors.green;
    if (averageChange < 0) return Colors.red;
    return Colors.grey;
  }

  @override
  String toString() {
    return 'SectorPerformance(sector: $sector, averageChange: $averageChange, date: $date)';
  }
}

/// Insider Trading model for SEC Form 4 filings and executive transactions
/// Provides transparency into company insider buying/selling activity
class InsiderTrading {
  final String symbol;
  final String filingDate;
  final String transactionDate;
  final String reportingCik;
  final String companyCik;
  final String transactionType;
  final int securitiesOwned;
  final String reportingName;
  final String typeOfOwner;
  final String
  acquisitionOrDisposition; // "A" for acquisition (buy), "D" for disposition (sell)
  final String directOrIndirect; // "D" for direct, "I" for indirect
  final String formType;
  final int securitiesTransacted;
  final double price;
  final String securityName;
  final String url;

  InsiderTrading({
    required this.symbol,
    required this.filingDate,
    required this.transactionDate,
    required this.reportingCik,
    required this.companyCik,
    required this.transactionType,
    required this.securitiesOwned,
    required this.reportingName,
    required this.typeOfOwner,
    required this.acquisitionOrDisposition,
    required this.directOrIndirect,
    required this.formType,
    required this.securitiesTransacted,
    required this.price,
    required this.securityName,
    required this.url,
  });

  factory InsiderTrading.fromJson(Map<String, dynamic> json) {
    return InsiderTrading(
      symbol: json['symbol']?.toString() ?? '',
      filingDate: json['filingDate']?.toString() ?? '',
      transactionDate: json['transactionDate']?.toString() ?? '',
      reportingCik: json['reportingCik']?.toString() ?? '',
      companyCik: json['companyCik']?.toString() ?? '',
      transactionType: json['transactionType']?.toString() ?? '',
      securitiesOwned: json['securitiesOwned'] as int? ?? 0,
      reportingName: json['reportingName']?.toString() ?? '',
      typeOfOwner: json['typeOfOwner']?.toString() ?? '',
      acquisitionOrDisposition:
          json['acquisitionOrDisposition']?.toString() ?? '',
      directOrIndirect: json['directOrIndirect']?.toString() ?? '',
      formType: json['formType']?.toString() ?? '',
      securitiesTransacted: json['securitiesTransacted'] as int? ?? 0,
      price: _parseDouble(json['price']) ?? 0.0,
      securityName: json['securityName']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
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

  /// Check if this is a buy transaction
  bool get isBuy => acquisitionOrDisposition == 'A';

  /// Check if this is a sell transaction
  bool get isSell => acquisitionOrDisposition == 'D';

  /// Get transaction color for charts
  Color getTransactionColor() {
    if (isBuy) return Colors.green;
    if (isSell) return Colors.red;
    return Colors.grey;
  }

  /// Format securities transacted with sign
  String formatSecuritiesTransacted() {
    final sign = isBuy ? '+' : '-';
    return '$sign${securitiesTransacted.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  /// Format price with transaction type differentiation
  String formatPriceWithType() {
    if (price > 0) {
      return '\$${price.toStringAsFixed(2)}';
    }

    // Check transaction type for special cases
    final type = transactionType.toLowerCase();
    if (type.contains('award') || type.contains('grant')) {
      return 'Award/Grant';
    } else if (type.contains('exempt') || type.contains('exemption')) {
      return 'Exempt';
    } else if (type.contains('in-kind') || type.contains('inkind')) {
      return 'In-Kind';
    } else if (type.contains('gift') || type.contains('donation')) {
      return 'Gift';
    } else if (type.contains('exercise')) {
      return 'Exercise';
    } else if (type.contains('conversion') || type.contains('convert')) {
      return 'Conversion';
    } else if (price == 0 && (isBuy || isSell)) {
      return 'No Price';
    }

    return 'N/A';
  }

  /// Get transaction type description
  String getTransactionTypeDescription() {
    final type = transactionType.toLowerCase();
    if (type.contains('award') || type.contains('grant')) {
      return 'Stock Award/Grant';
    } else if (type.contains('exempt') || type.contains('exemption')) {
      return 'Exempt Transaction';
    } else if (type.contains('in-kind') || type.contains('inkind')) {
      return 'In-Kind Transfer';
    } else if (type.contains('gift') || type.contains('donation')) {
      return 'Gift/Donation';
    } else if (type.contains('exercise')) {
      return 'Option Exercise';
    } else if (type.contains('conversion') || type.contains('convert')) {
      return 'Security Conversion';
    } else if (price == 0 && isBuy) {
      return 'Purchase (No Price)';
    } else if (price == 0 && isSell) {
      return 'Sale (No Price)';
    }

    return transactionType.isNotEmpty ? transactionType : 'Regular Transaction';
  }

  /// Get formatted transaction date
  String get formattedTransactionDate {
    try {
      final date = DateTime.parse(transactionDate);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return transactionDate;
    }
  }

  /// Get formatted filing date
  String get formattedFilingDate {
    try {
      final date = DateTime.parse(filingDate);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return filingDate;
    }
  }

  @override
  String toString() {
    return 'InsiderTrading(symbol: $symbol, reportingName: $reportingName, transactionType: $acquisitionOrDisposition, securitiesTransacted: $securitiesTransacted)';
  }
}

/// Revenue product segmentation data model
/// Represents revenue breakdown by product categories for a company
class RevenueSegmentation {
  final String symbol;
  final int fiscalYear;
  final String period;
  final String? reportedCurrency;
  final String date;
  final Map<String, double> data;

  RevenueSegmentation({
    required this.symbol,
    required this.fiscalYear,
    required this.period,
    this.reportedCurrency,
    required this.date,
    required this.data,
  });

  factory RevenueSegmentation.fromJson(Map<String, dynamic> json) {
    final dataMap = <String, double>{};
    if (json['data'] is Map<String, dynamic>) {
      (json['data'] as Map<String, dynamic>).forEach((key, value) {
        if (value is num) {
          dataMap[key] = value.toDouble();
        }
      });
    }

    return RevenueSegmentation(
      symbol: json['symbol']?.toString() ?? '',
      fiscalYear: json['fiscalYear'] as int? ?? 0,
      period: json['period']?.toString() ?? '',
      reportedCurrency: json['reportedCurrency']?.toString(),
      date: json['date']?.toString() ?? '',
      data: dataMap,
    );
  }

  /// Get total revenue across all product categories
  double get totalRevenue {
    return data.values.fold(0.0, (sum, value) => sum + value);
  }

  /// Get product categories sorted by revenue (highest first)
  List<MapEntry<String, double>> get sortedProducts {
    final entries = data.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Format revenue value as currency string
  static String formatRevenue(double revenue) {
    if (revenue >= 1000000000) {
      return '\$${(revenue / 1000000000).toStringAsFixed(1)}B';
    } else if (revenue >= 1000000) {
      return '\$${(revenue / 1000000).toStringAsFixed(1)}M';
    } else if (revenue >= 1000) {
      return '\$${(revenue / 1000).toStringAsFixed(1)}K';
    }
    return '\$${revenue.toStringAsFixed(0)}';
  }

  /// Get percentage of total revenue for a product
  double getProductPercentage(String productName) {
    final productRevenue = data[productName];
    if (productRevenue == null || totalRevenue == 0) return 0.0;
    return (productRevenue / totalRevenue) * 100;
  }

  @override
  String toString() {
    return 'RevenueSegmentation(symbol: $symbol, fiscalYear: $fiscalYear, totalRevenue: $totalRevenue, products: ${data.length})';
  }
}
