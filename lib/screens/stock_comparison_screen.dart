import 'package:flutter/material.dart';
import 'package:stockdrop/models/stock.dart';
import 'package:stockdrop/services/api_service.dart';

// Import StockDetail from detail_screen.dart
import 'package:stockdrop/screens/detail_screen.dart';

class StockComparisonScreen extends StatefulWidget {
  final StockDetail initialStockDetail;

  const StockComparisonScreen({super.key, required this.initialStockDetail});

  @override
  State<StockComparisonScreen> createState() => _StockComparisonScreenState();
}

class _StockComparisonScreenState extends State<StockComparisonScreen> {
  final ApiService _apiService = ApiService();

  List<Stock> _selectedStocks = [];
  List<Stock> _searchResults = [];
  bool _isLoading = false;
  String _searchQuery = '';
  Stock? _winner;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
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

    setState(() {
      _selectedStocks = [initialStock];
    });
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
      // Fetch financial ratios for all selected stocks
      final futures = _selectedStocks.map((stock) async {
        final ratios = await _apiService.getFinancialRatios(stock.symbol);
        return {'stock': stock, 'ratios': ratios};
      });

      final results = await Future.wait(futures);

      // Calculate scores based on PE ratio and dividend yield
      double bestScore = double.negativeInfinity;
      Stock? currentWinner;

      for (final result in results) {
        final stock = result['stock'] as Stock;
        final ratios = result['ratios'] as dynamic;

        // Lower PE ratio is better (value investing)
        final peRatio = ratios?.priceToEarningsRatio ?? double.infinity;
        final peScore = peRatio == double.infinity ? 0 : (100 / (peRatio + 1));

        // Higher dividend yield is better
        final dividendYield = ratios?.dividendYield ?? 0.0;
        final dividendScore = dividendYield * 100; // Convert to percentage

        final totalScore = peScore + dividendScore;

        if (totalScore > bestScore) {
          bestScore = totalScore.toDouble();
          currentWinner = stock;
        }
      }

      setState(() {
        _winner = currentWinner;
      });

      if (_winner != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_winner!.symbol} is the winner!')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Stocks'),
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
      body: Column(
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
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        child: Card(
                          color: isWinner ? Colors.green.shade100 : null,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
                                  '\$${stock.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isWinner
                                        ? Colors.green.shade600
                                        : null,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 16),
                                  onPressed: () =>
                                      _removeStockFromComparison(stock),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
      ),
    );
  }
}
