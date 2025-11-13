import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:stockdrop/services/api_service.dart';
import 'package:stockdrop/models/stock.dart';
import 'package:stockdrop/models/market_hours.dart';
import 'package:stockdrop/screens/detail_screen.dart';
import 'package:stockdrop/widgets/enhanced_stock_card.dart';

class IndustryScreen extends StatefulWidget {
  const IndustryScreen({super.key});

  @override
  State<IndustryScreen> createState() => _IndustryScreenState();
}

class _IndustryScreenState extends State<IndustryScreen> {
  final List<Industry> _industries = [
    Industry(
      sector: 'Basic Materials',
      icon: Icons.build_outlined,
      color: Colors.brown,
    ),
    Industry(
      sector: 'Communication Services',
      icon: Icons.phone_outlined,
      color: Colors.indigo,
    ),
    Industry(
      sector: 'Consumer Cyclical',
      icon: Icons.shopping_cart_outlined,
      color: Colors.orange,
    ),
    Industry(
      sector: 'Consumer Defensive',
      icon: Icons.shopping_basket_outlined,
      color: Colors.green,
    ),
    Industry(sector: 'Energy', icon: Icons.bolt_outlined, color: Colors.amber),
    Industry(
      sector: 'Financial Services',
      icon: Icons.account_balance_outlined,
      color: Colors.blue,
    ),
    Industry(
      sector: 'Healthcare',
      icon: Icons.medical_services_outlined,
      color: Colors.red,
    ),
    Industry(
      sector: 'Industrials',
      icon: Icons.factory_outlined,
      color: Colors.grey,
    ),
    Industry(
      sector: 'Real Estate',
      icon: Icons.home_outlined,
      color: Colors.teal,
    ),
    Industry(
      sector: 'Technology',
      icon: Icons.computer_outlined,
      color: Colors.purple,
    ),
    Industry(
      sector: 'Utilities',
      icon: Icons.electrical_services_outlined,
      color: Colors.cyan,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Industries',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.colorScheme.onBackground,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explore Industries',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Discover top-performing stocks across different sectors',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Industries Grid
            Text(
              'Select an Industry',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _industries.length,
              itemBuilder: (context, index) {
                final industry = _industries[index];
                return _buildIndustryCard(industry, theme);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndustryCard(Industry industry, ThemeData theme) {
    return GestureDetector(
      onTap: () => _navigateToIndustryStocks(industry),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: industry.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(industry.icon, color: industry.color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                industry.sector,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToIndustryStocks(Industry industry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IndustryStocksScreen(industry: industry),
      ),
    );
  }
}

class IndustryStocksScreen extends StatefulWidget {
  final Industry industry;

  const IndustryStocksScreen({super.key, required this.industry});

  @override
  State<IndustryStocksScreen> createState() => _IndustryStocksScreenState();
}

class _IndustryStocksScreenState extends State<IndustryStocksScreen> {
  List<Stock> _stocks = [];
  bool _isLoading = true;
  String? _error;

  // Market hours data
  List<MarketHours> _marketHours = [];

  @override
  void initState() {
    super.initState();
    _loadIndustryStocks();
    _fetchMarketHours();
  }

  Future<void> _loadIndustryStocks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ApiService();
      final stocks = await apiService.getStocksBySector(widget.industry.sector);

      // Sort by market cap (largest first) to show most important stocks
      stocks.sort((a, b) => (b.marketCap ?? 0).compareTo(a.marketCap ?? 0));

      // Debug: Check change percentages
      for (final stock in stocks.take(3)) {
        debugPrint(
          '🏭 Stock ${stock.symbol}: changePercent = ${stock.changePercent}',
        );
      }

      setState(() {
        _stocks = stocks.take(10).toList(); // Limit to top 10 for performance
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMarketHours() async {
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

      // Filter for the specific exchanges: NYSE, NASDAQ, XETRA, NSE, HKSE, LSE
      final targetExchanges = ['NYSE', 'NASDAQ', 'XETRA', 'NSE', 'HKSE', 'LSE'];
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
          'HKSE': 6,
        };

        final aOrder = regionOrder[a.exchange] ?? 99;
        final bOrder = regionOrder[b.exchange] ?? 99;
        return aOrder.compareTo(bOrder);
      });

      setState(() {
        _marketHours = filteredMarketHours;
      });
    } catch (e) {
      // Market hours failed to load, continue without them
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          widget.industry.sector,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.colorScheme.onBackground,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
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

    if (_stocks.isEmpty) {
      return _buildEmptyWidget(theme);
    }

    return RefreshIndicator(
      onRefresh: _loadIndustryStocks,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Industry Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.industry.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.industry.color.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: widget.industry.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.industry.icon,
                      color: widget.industry.color,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.industry.sector,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: widget.industry.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_stocks.length} stocks in sector',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stocks List
            Text(
              'Top Stocks',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _stocks.length,
              itemBuilder: (context, index) {
                final stock = _stocks[index];
                return EnhancedStockCard(
                  stock: StockAdapter(stock),
                  marketHours: _marketHours,
                  onTap: () => _navigateToStockDetail(stock),
                );
              },
            ),
          ],
        ),
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
              'Failed to Load Stocks',
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
              onPressed: _loadIndustryStocks,
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
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Stocks Found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No stocks available for ${widget.industry.sector} at the moment',
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

  void _navigateToStockDetail(Stock stock) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailScreen(symbol: stock.symbol),
      ),
    );
  }
}

class Industry {
  final String sector;
  final IconData icon;
  final Color color;

  Industry({required this.sector, required this.icon, required this.color});
}
