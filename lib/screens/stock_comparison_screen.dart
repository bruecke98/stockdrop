import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:stockdrop/models/stock.dart';
import 'package:stockdrop/services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';

// Import StockDetail from detail_screen.dart
import 'package:stockdrop/screens/detail_screen.dart';

class StockComparisonScreen extends StatefulWidget {
  final StockDetail initialStockDetail;

  const StockComparisonScreen({super.key, required this.initialStockDetail});

  @override
  State<StockComparisonScreen> createState() => _StockComparisonScreenState();
}

class _StockComparisonScreenState extends State<StockComparisonScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<Stock> _selectedStocks = [];
  List<Stock> _searchResults = [];
  bool _isLoading = false;
  String _searchQuery = '';
  Stock? _winner;
  List<Map<String, dynamic>> _comparisonData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // Unfocus any text fields when switching tabs to prevent keyboard from opening
    FocusScope.of(context).unfocus();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Convert StockDetail to Stock
      final initialStock = Stock(
        symbol: widget.initialStockDetail.symbol,
        name: widget.initialStockDetail.name,
        price: widget.initialStockDetail.price,
        change: widget.initialStockDetail.change ?? 0.0,
        changePercent: widget.initialStockDetail.changesPercentage ?? 0.0,
        currency: null, // StockDetail doesn't have currency
        volume: widget.initialStockDetail.volume,
        marketCap: widget.initialStockDetail.marketCap,
        dayHigh: widget.initialStockDetail.dayHigh,
        dayLow: widget.initialStockDetail.dayLow,
        yearHigh: widget.initialStockDetail.yearHigh,
        yearLow: widget.initialStockDetail.yearLow,
        priceAvg50: widget.initialStockDetail.priceAvg50,
        priceAvg200: widget.initialStockDetail.priceAvg200,
        exchange: widget.initialStockDetail.exchange,
        open: widget.initialStockDetail.open,
        previousClose: widget.initialStockDetail.previousClose,
        lastUpdated: null, // StockDetail doesn't have lastUpdated
        timestamp: widget.initialStockDetail.timestamp,
      );

      // Load peers
      final peers = await _apiService.getStockPeers(
        widget.initialStockDetail.symbol,
      );

      setState(() {
        _selectedStocks = [
          initialStock,
          ...peers.take(3),
        ]; // Initial stock + up to 3 peers
        _searchResults = peers
            .skip(3)
            .toList(); // Remaining peers as search results
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      // Fallback to just initial stock
      final initialStock = Stock(
        symbol: widget.initialStockDetail.symbol,
        name: widget.initialStockDetail.name,
        price: widget.initialStockDetail.price,
        change: widget.initialStockDetail.change ?? 0.0,
        changePercent: widget.initialStockDetail.changesPercentage ?? 0.0,
        currency: null,
        volume: widget.initialStockDetail.volume,
        marketCap: widget.initialStockDetail.marketCap,
        dayHigh: widget.initialStockDetail.dayHigh,
        dayLow: widget.initialStockDetail.dayLow,
        yearHigh: widget.initialStockDetail.yearHigh,
        yearLow: widget.initialStockDetail.yearLow,
        priceAvg50: widget.initialStockDetail.priceAvg50,
        priceAvg200: widget.initialStockDetail.priceAvg200,
        exchange: widget.initialStockDetail.exchange,
        open: widget.initialStockDetail.open,
        previousClose: widget.initialStockDetail.previousClose,
        lastUpdated: null,
        timestamp: widget.initialStockDetail.timestamp,
      );
      setState(() {
        _selectedStocks = [initialStock];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchStocks(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _apiService.searchStocks(query);
      setState(() {
        _searchResults = results
            .where(
              (stock) => !_selectedStocks.any(
                (selected) => selected.symbol == stock.symbol,
              ),
            )
            .toList();
      });
    } catch (e) {
      debugPrint('Error searching stocks: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching stocks: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addStockToComparison(Stock stock) {
    if (_selectedStocks.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 4 stocks can be compared')),
      );
      return;
    }

    setState(() {
      _selectedStocks.add(stock);
      _searchResults.removeWhere((s) => s.symbol == stock.symbol);
      _searchQuery = '';
    });
  }

  void _removeStockFromComparison(Stock stock) {
    setState(() {
      _selectedStocks.removeWhere((s) => s.symbol == stock.symbol);
      _winner = null;
    });
  }

  Future<void> _calculateWinner() async {
    if (_selectedStocks.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 stocks to compare')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch comprehensive data for all selected stocks
      final futures = _selectedStocks.map((stock) async {
        final results = await Future.wait([
          _apiService.getFinancialRatios(stock.symbol, limit: 1),
          _apiService.getKeyMetrics(stock.symbol, limit: 1),
          _apiService.getFinancialScores(stock.symbol),
          _apiService.getPriceTargetConsensus(stock.symbol),
        ]);

        return {
          'stock': stock,
          'ratios': results[0] as List<FinancialRatios>,
          'keyMetrics': results[1] as List<KeyMetrics>,
          'financialScores': results[2] as FinancialScores?,
          'priceTarget': results[3] as PriceTargetConsensus?,
        };
      });

      final results = await Future.wait(futures);

      // Calculate comprehensive scores
      double bestScore = double.negativeInfinity;
      Stock? currentWinner;
      Map<String, dynamic>? winnerDetails;
      final comparisonData = <Map<String, dynamic>>[];

      for (final result in results) {
        final stock = result['stock'] as Stock;
        final ratiosList = result['ratios'] as List<FinancialRatios>;
        final keyMetricsList = result['keyMetrics'] as List<KeyMetrics>;
        final financialScores = result['financialScores'] as FinancialScores?;
        final priceTarget = result['priceTarget'] as PriceTargetConsensus?;

        // Extract latest data
        final ratio = ratiosList.isNotEmpty ? ratiosList.first : null;
        final keyMetrics = keyMetricsList.isNotEmpty
            ? keyMetricsList.first
            : null;

        // Calculate comprehensive score with multiple categories
        double valuationScore = 0.0;
        double growthScore = 0.0;
        double profitabilityScore = 0.0;
        double financialHealthScore = 0.0;
        double analystScore = 0.0;
        int totalMetrics = 0;

        // VALUATION SCORES (25% weight)
        if (ratio?.priceToEarningsRatio != null &&
            ratio!.priceToEarningsRatio! > 0) {
          valuationScore += (100 / ratio.priceToEarningsRatio!).clamp(0, 25);
          totalMetrics++;
        }
        if (ratio?.priceToBookRatio != null && ratio!.priceToBookRatio! > 0) {
          valuationScore += (10 / ratio.priceToBookRatio!).clamp(0, 25);
          totalMetrics++;
        }
        if (ratio?.priceToSalesRatio != null && ratio!.priceToSalesRatio! > 0) {
          valuationScore += (5 / ratio.priceToSalesRatio!).clamp(0, 25);
          totalMetrics++;
        }

        // GROWTH SCORES (20% weight) - Use year-over-year changes if available
        // For now, use available metrics as proxies
        if (keyMetrics?.returnOnEquity != null) {
          growthScore += (keyMetrics!.returnOnEquity! * 10).clamp(0, 10);
          totalMetrics++;
        }
        if (keyMetrics?.returnOnAssets != null) {
          growthScore += (keyMetrics!.returnOnAssets! * 10).clamp(0, 10);
          totalMetrics++;
        }

        // PROFITABILITY SCORES (25% weight)
        if (ratio?.netProfitMargin != null) {
          profitabilityScore += (ratio!.netProfitMargin! * 100).clamp(0, 15);
          totalMetrics++;
        }
        if (keyMetrics?.returnOnEquity != null) {
          profitabilityScore += (keyMetrics!.returnOnEquity! * 25).clamp(0, 15);
          totalMetrics++;
        }
        if (keyMetrics?.returnOnAssets != null) {
          profitabilityScore += (keyMetrics!.returnOnAssets! * 25).clamp(0, 15);
          totalMetrics++;
        }
        if (ratio?.dividendYield != null) {
          profitabilityScore += (ratio!.dividendYield! * 100).clamp(0, 10);
          totalMetrics++;
        }

        // FINANCIAL HEALTH SCORES (20% weight)
        if (ratio?.debtToEquityRatio != null) {
          financialHealthScore += (20 / (ratio!.debtToEquityRatio! + 1)).clamp(
            0,
            10,
          );
          totalMetrics++;
        }
        if (ratio?.currentRatio != null) {
          financialHealthScore += (ratio!.currentRatio! / 2).clamp(0, 10);
          totalMetrics++;
        }
        if (financialScores?.piotroskiScore != null) {
          financialHealthScore += (financialScores!.piotroskiScore! / 9 * 10)
              .clamp(0, 10);
          totalMetrics++;
        }

        // ANALYST SCORES (10% weight)
        if (priceTarget?.targetConsensus != null && stock.price > 0) {
          final upside =
              ((priceTarget!.targetConsensus! - stock.price) /
                      stock.price *
                      100)
                  .clamp(0, 10);
          analystScore += upside;
          totalMetrics++;
        }

        // Calculate final weighted score
        final finalScore =
            (valuationScore * 0.25) +
            (growthScore * 0.20) +
            (profitabilityScore * 0.25) +
            (financialHealthScore * 0.20) +
            (analystScore * 0.10);

        final stockData = {
          'stock': stock,
          'score': finalScore,
          'valuationScore': valuationScore,
          'growthScore': growthScore,
          'profitabilityScore': profitabilityScore,
          'financialHealthScore': financialHealthScore,
          'analystScore': analystScore,
          // Financial Ratios
          'peRatio': ratio?.priceToEarningsRatio,
          'pbRatio': ratio?.priceToBookRatio,
          'psRatio': ratio?.priceToSalesRatio,
          'dividendYield': ratio?.dividendYield,
          'netProfitMargin': ratio?.netProfitMargin,
          'returnOnEquity': keyMetrics?.returnOnEquity,
          'returnOnAssets': keyMetrics?.returnOnAssets,
          'debtToEquity': ratio?.debtToEquityRatio,
          'currentRatio': ratio?.currentRatio,
          'quickRatio': ratio?.quickRatio,
          'beta': stock.beta,
          // Key Metrics
          'roe': keyMetrics?.returnOnEquity,
          'roa': keyMetrics?.returnOnAssets,
          'marketCap': stock.marketCap,
          'volume': stock.volume,
          'price': stock.price,
          'changePercent': stock.changePercent,
          // Analyst Data
          'targetPrice': priceTarget?.targetConsensus,
          'analystRating': null, // Not available in this API
          'piotroskiScore': financialScores?.piotroskiScore,
          'altmanZScore': financialScores?.altmanZScore,
        };

        comparisonData.add(stockData);

        if (finalScore > bestScore) {
          bestScore = finalScore;
          currentWinner = stock;
          winnerDetails = {
            'score': finalScore,
            'valuationScore': valuationScore,
            'growthScore': growthScore,
            'profitabilityScore': profitabilityScore,
            'financialHealthScore': financialHealthScore,
            'analystScore': analystScore,
            'peRatio': ratio?.priceToEarningsRatio,
            'dividendYield': ratio?.dividendYield,
            'netProfitMargin': ratio?.netProfitMargin,
            'returnOnEquity': keyMetrics?.returnOnEquity,
            'debtToEquity': ratio?.debtToEquityRatio,
            'currentRatio': ratio?.currentRatio,
            'returnOnAssets': keyMetrics?.returnOnAssets,
            'targetPrice': priceTarget?.targetConsensus,
            'beta': stock.beta,
            'marketCap': stock.marketCap,
            'metricsCount': totalMetrics,
          };
        }
      }

      setState(() {
        _winner = currentWinner;
        _comparisonData = comparisonData;
      });

      if (_winner != null && winnerDetails != null) {
        _showWinnerDetails(_winner!, winnerDetails);
      }
    } catch (e) {
      debugPrint('Error calculating winner: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error calculating winner: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showWinnerDetails(Stock winner, Map<String, dynamic> details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.white,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${winner.name} Wins!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Score Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      '${details['score'].toStringAsFixed(1)}/100',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Text(
                      'Overall Score',
                      style: TextStyle(fontSize: 14, color: Colors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Score Breakdown
              const Text(
                'Score Breakdown:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildScoreBreakdown('Valuation', details['valuationScore'] ?? 0),
              _buildScoreBreakdown(
                'Profitability',
                details['profitabilityScore'] ?? 0,
              ),
              _buildScoreBreakdown(
                'Financial Health',
                details['financialHealthScore'] ?? 0,
              ),
              _buildScoreBreakdown(
                'Analyst Sentiment',
                details['analystScore'] ?? 0,
              ),

              const SizedBox(height: 20),
              const Text(
                'Key Metrics:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (details['peRatio'] != null)
                _buildMetricRow(
                  'P/E Ratio',
                  details['peRatio'].toStringAsFixed(2),
                ),
              if (details['dividendYield'] != null)
                _buildMetricRow(
                  'Dividend Yield',
                  '${(details['dividendYield'] * 100).toStringAsFixed(2)}%',
                ),
              if (details['netProfitMargin'] != null)
                _buildMetricRow(
                  'Net Profit Margin',
                  '${(details['netProfitMargin'] * 100).toStringAsFixed(2)}%',
                ),
              if (details['debtToEquity'] != null)
                _buildMetricRow(
                  'Debt to Equity',
                  details['debtToEquity'].toStringAsFixed(2),
                ),
              if (details['currentRatio'] != null)
                _buildMetricRow(
                  'Current Ratio',
                  details['currentRatio'].toStringAsFixed(2),
                ),
              if (details['roe'] != null)
                _buildMetricRow(
                  'Return on Equity',
                  '${(details['roe'] * 100).toStringAsFixed(2)}%',
                ),

              const SizedBox(height: 16),
              Text(
                'Based on ${details['metricsCount']} financial metrics',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Switch to comparison tab
              _tabController.animateTo(1);
            },
            icon: const Icon(Icons.compare_arrows),
            label: const Text('View Comparison'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBreakdown(String label, double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: score / 25, // Assuming max score of 25 per category
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                score > 15
                    ? Colors.green
                    : score > 10
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score.toStringAsFixed(1),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketCapBubbleChart() {
    if (_comparisonData.isEmpty) return const SizedBox();

    // Calculate bubble sizes based on market cap (logarithmic scale)
    final maxMarketCap = _comparisonData
        .map((data) => (data['marketCap'] as double?) ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return Stack(
      children: _comparisonData.map((data) {
        final stock = data['stock'] as Stock;
        final marketCap = (data['marketCap'] as double?) ?? 0;
        final index = _comparisonData.indexOf(data);

        // Calculate bubble size (logarithmic scaling)
        final size = marketCap > 0
            ? 40 + (math.log(marketCap) / math.log(maxMarketCap)) * 60
            : 20.0;

        // Position bubbles in a semi-circle
        final angle = (index / (_comparisonData.length - 1)) * math.pi;
        final radius = 100.0;
        final centerX = 150.0;
        final centerY = 120.0;

        final x = centerX + radius * math.cos(angle - math.pi / 2);
        final y = centerY + radius * math.sin(angle - math.pi / 2);

        return Positioned(
          left: x - size / 2,
          top: y - size / 2,
          child: GestureDetector(
            onTap: () => _showStockDetails(stock, data),
            child: Container(
              width: size.toDouble(),
              height: size.toDouble(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _winner?.symbol == stock.symbol
                    ? Colors.green.withOpacity(0.8)
                    : Colors.blue.withOpacity(0.7),
                border: Border.all(
                  color: _winner?.symbol == stock.symbol
                      ? Colors.green.shade800
                      : Colors.blue.shade800,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stock.symbol,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: math.max(8, size / 6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      marketCap > 0
                          ? '\$${(marketCap / 1e9).toStringAsFixed(1)}B'
                          : 'N/A',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: math.max(6, size / 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showStockDetails(Stock stock, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${stock.symbol} - ${stock.name}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Score: ${data['score'].toStringAsFixed(1)}/100'),
              const SizedBox(height: 8),
              Text('Price: \$${stock.price.toStringAsFixed(2)}'),
              if (stock.marketCap != null)
                Text(
                  'Market Cap: \$${(stock.marketCap! / 1e9).toStringAsFixed(1)}B',
                ),
              if (data['peRatio'] != null)
                Text('P/E Ratio: ${data['peRatio'].toStringAsFixed(2)}'),
              if (data['dividendYield'] != null)
                Text(
                  'Dividend Yield: ${(data['dividendYield'] * 100).toStringAsFixed(2)}%',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Stocks'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Select Stocks'),
            Tab(text: 'Comparison'),
          ],
        ),
        actions: [
          if (_selectedStocks.length >= 2)
            TextButton(
              onPressed: _isLoading ? null : _calculateWinner,
              child: Text(
                _isLoading ? 'Calculating...' : 'Find Winner',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSelectionTab(), _buildComparisonTab()],
      ),
    );
  }

  Widget _buildSelectionTab() {
    return Column(
      children: [
        // Selected stocks display
        Container(
          height: 120,
          padding: const EdgeInsets.all(16),
          child: _selectedStocks.isEmpty
              ? const Center(child: Text('No stocks selected'))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedStocks.length,
                  itemBuilder: (context, index) {
                    final stock = _selectedStocks[index];
                    final isWinner = _winner?.symbol == stock.symbol;
                    return Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      child: Card(
                        color: isWinner ? Colors.green.shade100 : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Company Logo
                              Container(
                                width: 32,
                                height: 32,
                                margin: const EdgeInsets.only(bottom: 4),
                                child: Image.network(
                                  'https://images.financialmodelingprep.com/symbol/${stock.symbol}.png',
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.business, size: 24),
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        );
                                      },
                                ),
                              ),
                              Text(
                                stock.symbol,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isWinner
                                      ? Colors.green.shade800
                                      : null,
                                ),
                              ),
                              Text(
                                stock.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isWinner
                                      ? Colors.green.shade600
                                      : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${stock.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isWinner
                                      ? Colors.green.shade600
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, size: 24),
                                onPressed: () =>
                                    _removeStockFromComparison(stock),
                                color: Colors.red.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Prominent Find Winner Button
        if (_selectedStocks.length >= 2)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _calculateWinner,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.emoji_events, color: Colors.white),
              label: Text(
                _isLoading ? 'Analyzing Stocks...' : 'Find Winner',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: Colors.green.shade200,
              ),
            ),
          ),

        // Search section
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search stocks to add',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _searchStocks(value);
            },
          ),
        ),

        // Search results
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty && _searchQuery.isNotEmpty
              ? const Center(child: Text('No stocks found'))
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final stock = _searchResults[index];
                    return ListTile(
                      leading: Container(
                        width: 32,
                        height: 32,
                        child: Image.network(
                          'https://images.financialmodelingprep.com/symbol/${stock.symbol}.png',
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.business, size: 24),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          },
                        ),
                      ),
                      title: Text('${stock.symbol} - ${stock.name}'),
                      subtitle: Text('\$${stock.price.toStringAsFixed(2)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addStockToComparison(stock),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScoreCard(
    Stock stock,
    double score,
    bool isWinner,
    Map<String, dynamic> data,
  ) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWinner ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner ? Colors.green.shade300 : Colors.grey.shade300,
          width: isWinner ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Company Logo and Symbol
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: 8),
            child: Image.network(
              'https://images.financialmodelingprep.com/symbol/${stock.symbol}.png',
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.business, size: 32),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
            ),
          ),

          // Symbol and Name
          Text(
            stock.symbol,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isWinner ? Colors.green.shade800 : Colors.black,
            ),
          ),
          Text(
            stock.name,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // Score Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isWinner ? Colors.green.shade100 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${score.toStringAsFixed(1)}/100',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isWinner ? Colors.green.shade800 : Colors.blue.shade800,
              ),
            ),
          ),

          if (isWinner) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'WINNER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonTab() {
    if (_comparisonData.isEmpty) {
      return const Center(
        child: Text('Calculate winner to see comparison data'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial Metrics Comparison',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Score Cards for Each Company
          const Text(
            'Company Scores',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _comparisonData.map((data) {
              final stock = data['stock'] as Stock;
              final score = data['score'] as double;
              final isWinner = _winner?.symbol == stock.symbol;
              return _buildScoreCard(stock, score, isWinner, data);
            }).toList(),
          ),

          const SizedBox(height: 30),

          // Overall Scores Chart
          const Text(
            'Overall Scores Comparison',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barGroups: _comparisonData.map((data) {
                  final stock = data['stock'] as Stock;
                  final score = data['score'] as double;
                  return BarChartGroupData(
                    x: _comparisonData.indexOf(data),
                    barRods: [
                      BarChartRodData(
                        toY: score,
                        color: _winner?.symbol == stock.symbol
                            ? Colors.green
                            : Colors.blue,
                        width: 20,
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _comparisonData.length) {
                          final stock =
                              _comparisonData[index]['stock'] as Stock;
                          return Text(
                            stock.symbol,
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // P/E Ratio Chart
          const Text(
            'Price to Earnings Ratio',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: _comparisonData.map((data) {
                  final stock = data['stock'] as Stock;
                  final pe = data['peRatio'] as double?;
                  return BarChartGroupData(
                    x: _comparisonData.indexOf(data),
                    barRods: [
                      BarChartRodData(
                        toY: pe ?? 0,
                        color: _winner?.symbol == stock.symbol
                            ? Colors.green
                            : Colors.orange,
                        width: 20,
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _comparisonData.length) {
                          final stock =
                              _comparisonData[index]['stock'] as Stock;
                          return Text(
                            stock.symbol,
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Dividend Yield Chart
          const Text(
            'Dividend Yield (%)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: _comparisonData.map((data) {
                  final stock = data['stock'] as Stock;
                  final dy = data['dividendYield'] as double?;
                  return BarChartGroupData(
                    x: _comparisonData.indexOf(data),
                    barRods: [
                      BarChartRodData(
                        toY: (dy ?? 0) * 100,
                        color: _winner?.symbol == stock.symbol
                            ? Colors.green
                            : Colors.purple,
                        width: 20,
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _comparisonData.length) {
                          final stock =
                              _comparisonData[index]['stock'] as Stock;
                          return Text(
                            stock.symbol,
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Market Cap Bubble Chart
          const Text(
            'Market Capitalization Comparison',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildMarketCapBubbleChart(),
          ),

          const SizedBox(height: 30),

          // Comprehensive Data Table
          const Text(
            'Comprehensive Financial Metrics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Company')),
                DataColumn(label: Text('Score')),
                DataColumn(label: Text('P/E')),
                DataColumn(label: Text('P/B')),
                DataColumn(label: Text('P/S')),
                DataColumn(label: Text('Div Yield %')),
                DataColumn(label: Text('ROE %')),
                DataColumn(label: Text('ROA %')),
                DataColumn(label: Text('Net Margin %')),
                DataColumn(label: Text('Debt/Equity')),
                DataColumn(label: Text('Current Ratio')),
                DataColumn(label: Text('Beta')),
                DataColumn(label: Text('Mkt Cap')),
                DataColumn(label: Text('Target Price')),
              ],
              rows: _comparisonData.map((data) {
                final stock = data['stock'] as Stock;
                return DataRow(
                  color: _winner?.symbol == stock.symbol
                      ? MaterialStateProperty.all(Colors.green.shade50)
                      : null,
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 8),
                            child: Image.network(
                              'https://images.financialmodelingprep.com/symbol/${stock.symbol}.png',
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.business, size: 24),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stock.symbol,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  stock.name,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(data['score'].toStringAsFixed(1))),
                    DataCell(
                      Text(data['peRatio']?.toStringAsFixed(1) ?? 'N/A'),
                    ),
                    DataCell(
                      Text(data['pbRatio']?.toStringAsFixed(1) ?? 'N/A'),
                    ),
                    DataCell(
                      Text(data['psRatio']?.toStringAsFixed(1) ?? 'N/A'),
                    ),
                    DataCell(
                      Text(
                        data['dividendYield'] != null
                            ? '${(data['dividendYield'] * 100).toStringAsFixed(2)}%'
                            : 'N/A',
                      ),
                    ),
                    DataCell(
                      Text(
                        data['returnOnEquity'] != null
                            ? '${(data['returnOnEquity'] * 100).toStringAsFixed(1)}%'
                            : 'N/A',
                      ),
                    ),
                    DataCell(
                      Text(
                        data['returnOnAssets'] != null
                            ? '${(data['returnOnAssets'] * 100).toStringAsFixed(1)}%'
                            : 'N/A',
                      ),
                    ),
                    DataCell(
                      Text(
                        data['netProfitMargin'] != null
                            ? '${(data['netProfitMargin'] * 100).toStringAsFixed(1)}%'
                            : 'N/A',
                      ),
                    ),
                    DataCell(
                      Text(data['debtToEquity']?.toStringAsFixed(1) ?? 'N/A'),
                    ),
                    DataCell(
                      Text(data['currentRatio']?.toStringAsFixed(1) ?? 'N/A'),
                    ),
                    DataCell(Text(data['beta']?.toStringAsFixed(2) ?? 'N/A')),
                    DataCell(
                      Text(
                        stock.marketCap != null
                            ? '\$${(stock.marketCap! / 1e9).toStringAsFixed(1)}B'
                            : 'N/A',
                      ),
                    ),
                    DataCell(
                      Text(
                        data['targetPrice'] != null
                            ? '\$${data['targetPrice'].toStringAsFixed(2)}'
                            : 'N/A',
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
