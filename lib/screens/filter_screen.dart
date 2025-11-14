import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../widgets/enhanced_stock_card.dart';
import '../models/market_hours.dart';

/// Comprehensive filter screen for stock screening using FMP Company Screener API
class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // Market Data Filters
  double? _marketCapMin;
  double? _marketCapMax;
  double? _priceMin;
  double? _priceMax;
  double? _betaMin;
  double? _betaMax;
  double? _volumeMin;
  double? _volumeMax;
  double? _changeMin; // Percentage change minimum (can be negative for losses)

  // Market hours data
  List<MarketHours> _marketHours = [];
  bool _isLoadingMarketHours = true;
  double? _changeMax; // Percentage change maximum

  // Fundamentals Filters
  double? _dividendMin;
  double? _dividendMax;

  // Classification Filters
  String? _sector;
  String? _industry;
  String? _exchange;
  String? _country;

  // Trading Status Filters
  bool? _isEtf;
  bool? _isFund;
  bool? _isActivelyTrading;

  // Results Filters
  int _limit = 100;
  bool _includeAllShareClasses = false;

  // UI State
  List<FilteredStock> _filteredStocks = [];
  bool _isLoading = false;
  String? _error;
  bool _filtersApplied = false;

  // Dropdown options
  final List<String> _sectorOptions = [
    'Technology',
    'Healthcare',
    'Financial Services',
    'Consumer Cyclical',
    'Communication Services',
    'Industrials',
    'Consumer Defensive',
    'Energy',
    'Utilities',
    'Real Estate',
    'Basic Materials',
  ];

  final List<String> _industryOptions = [
    'Consumer Electronics',
    'Software',
    'Semiconductors',
    'Banks',
    'Medical Devices',
    'Drug Manufacturers',
    'Insurance',
    'Retail',
    'Automobiles',
    'Telecommunications',
    'Aerospace',
    'Chemicals',
    'Utilities',
    'REITs',
    'Metals & Mining',
  ];

  final List<String> _exchangeOptions = [
    'NASDAQ',
    'NYSE',
    'AMEX',
    'OTC',
    'TSX',
    'LSE',
    'HKSE',
    'SSE',
    'SZSE',
  ];

  final List<String> _countryOptions = [
    'US',
    'CA',
    'GB',
    'DE',
    'FR',
    'JP',
    'CN',
    'AU',
    'IN',
    'BR',
    'MX',
    'KR',
    'SG',
    'NL',
    'CH',
  ];

  @override
  void initState() {
    super.initState();
    _fetchMarketHours();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Screener'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Filter controls section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Stock Screener',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Filter stocks using comprehensive criteria',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Market Data Section
                  _buildSectionHeader(theme, 'Market Data', Icons.show_chart),
                  const SizedBox(height: 16),
                  _buildMarketDataSection(theme),
                  const SizedBox(height: 24),

                  // Fundamentals Section
                  _buildSectionHeader(
                    theme,
                    'Fundamentals',
                    Icons.account_balance_wallet,
                  ),
                  const SizedBox(height: 16),
                  _buildFundamentalsSection(theme),
                  const SizedBox(height: 24),

                  // Classification Section
                  _buildSectionHeader(theme, 'Classification', Icons.category),
                  const SizedBox(height: 16),
                  _buildClassificationSection(theme),
                  const SizedBox(height: 24),

                  // Trading Status Section
                  _buildSectionHeader(
                    theme,
                    'Trading Status',
                    Icons.trending_up,
                  ),
                  const SizedBox(height: 16),
                  _buildTradingStatusSection(theme),
                  const SizedBox(height: 24),

                  // Results Section
                  _buildSectionHeader(theme, 'Results', Icons.list),
                  const SizedBox(height: 16),
                  _buildResultsSection(theme),
                  const SizedBox(height: 24),

                  // Apply Filters Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _applyFilters,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Apply Filters',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reset Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _resetFilters,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reset All Filters',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Filtered results section
            if (_filtersApplied) ...[
              Container(
                height: 1,
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
              _buildFilteredResultsScrollable(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildMarketDataSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRangeInput(
              theme,
              'Market Cap',
              'Minimum market cap (millions)',
              _marketCapMin,
              (value) => setState(() => _marketCapMin = value),
              'Maximum market cap (millions)',
              _marketCapMax,
              (value) => setState(() => _marketCapMax = value),
            ),
            const SizedBox(height: 16),
            _buildRangeInput(
              theme,
              'Price',
              'Minimum price',
              _priceMin,
              (value) => setState(() => _priceMin = value),
              'Maximum price',
              _priceMax,
              (value) => setState(() => _priceMax = value),
            ),
            const SizedBox(height: 16),
            _buildRangeInput(
              theme,
              'Beta',
              'Minimum beta',
              _betaMin,
              (value) => setState(() => _betaMin = value),
              'Maximum beta',
              _betaMax,
              (value) => setState(() => _betaMax = value),
            ),
            const SizedBox(height: 16),
            _buildRangeInput(
              theme,
              'Volume',
              'Minimum volume',
              _volumeMin,
              (value) => setState(() => _volumeMin = value),
              'Maximum volume',
              _volumeMax,
              (value) => setState(() => _volumeMax = value),
            ),
            const SizedBox(height: 16),
            _buildRangeInput(
              theme,
              'Percentage Change (%)',
              'Minimum change (%)',
              _changeMin,
              (value) => setState(() => _changeMin = value),
              'Maximum change (%)',
              _changeMax,
              (value) => setState(() => _changeMax = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFundamentalsSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildRangeInput(
          theme,
          'Dividend Yield',
          'Minimum dividend yield (%)',
          _dividendMin,
          (value) => setState(() => _dividendMin = value),
          'Maximum dividend yield (%)',
          _dividendMax,
          (value) => setState(() => _dividendMax = value),
        ),
      ),
    );
  }

  Widget _buildClassificationSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown(
              theme,
              'Sector',
              _sector,
              _sectorOptions,
              (value) => setState(() => _sector = value),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              theme,
              'Industry',
              _industry,
              _industryOptions,
              (value) => setState(() => _industry = value),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              theme,
              'Exchange',
              _exchange,
              _exchangeOptions,
              (value) => setState(() => _exchange = value),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              theme,
              'Country',
              _country,
              _countryOptions,
              (value) => setState(() => _country = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradingStatusSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTriStateSwitch(
              theme,
              'ETF',
              _isEtf,
              (value) => setState(() => _isEtf = value),
            ),
            const SizedBox(height: 16),
            _buildTriStateSwitch(
              theme,
              'Fund',
              _isFund,
              (value) => setState(() => _isFund = value),
            ),
            const SizedBox(height: 16),
            _buildTriStateSwitch(
              theme,
              'Actively Trading',
              _isActivelyTrading,
              (value) => setState(() => _isActivelyTrading = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Results Limit',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _limit.toDouble(),
              min: 10,
              max: 5000,
              divisions: 499,
              label: _limit.toString(),
              onChanged: (value) => setState(() => _limit = value.toInt()),
            ),
            Text(
              'Maximum $_limit results',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(
                'Include All Share Classes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Include all share classes (A, B, etc.)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: _includeAllShareClasses,
              onChanged: (value) =>
                  setState(() => _includeAllShareClasses = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeInput(
    ThemeData theme,
    String title,
    String minLabel,
    double? minValue,
    Function(double?) onMinChanged,
    String maxLabel,
    double? maxValue,
    Function(double?) onMaxChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: minLabel,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: minValue?.toString() ?? '',
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  onMinChanged(parsed);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: maxLabel,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: maxValue?.toString() ?? '',
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  onMaxChanged(parsed);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown(
    ThemeData theme,
    String label,
    String? value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('Any')),
            ...options.map(
              (option) =>
                  DropdownMenuItem<String>(value: option, child: Text(option)),
            ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTriStateSwitch(
    ThemeData theme,
    String label,
    bool? value,
    Function(bool?) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DropdownButton<bool?>(
          value: value,
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('Any')),
            DropdownMenuItem<bool?>(value: true, child: Text('Yes')),
            DropdownMenuItem<bool?>(value: false, child: Text('No')),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _applyFilters() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiKey = dotenv.env['FMP_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API key not found');
      }

      // Build query parameters
      final queryParams = <String, String>{};

      if (_marketCapMin != null)
        queryParams['marketCapMoreThan'] = (_marketCapMin! * 1000000)
            .toStringAsFixed(0);
      if (_marketCapMax != null)
        queryParams['marketCapLowerThan'] = (_marketCapMax! * 1000000)
            .toStringAsFixed(0);
      if (_priceMin != null)
        queryParams['priceMoreThan'] = _priceMin!.toString();
      if (_priceMax != null)
        queryParams['priceLowerThan'] = _priceMax!.toString();
      if (_betaMin != null) queryParams['betaMoreThan'] = _betaMin!.toString();
      if (_betaMax != null) queryParams['betaLowerThan'] = _betaMax!.toString();
      if (_volumeMin != null)
        queryParams['volumeMoreThan'] = _volumeMin!.toStringAsFixed(0);
      if (_volumeMax != null)
        queryParams['volumeLowerThan'] = _volumeMax!.toStringAsFixed(0);
      if (_changeMin != null)
        queryParams['changeMoreThan'] = _changeMin!.toString();
      if (_changeMax != null)
        queryParams['changeLowerThan'] = _changeMax!.toString();
      if (_dividendMin != null)
        queryParams['dividendMoreThan'] = _dividendMin!.toString();
      if (_dividendMax != null)
        queryParams['dividendLowerThan'] = _dividendMax!.toString();
      if (_sector != null) queryParams['sector'] = _sector!;
      if (_industry != null) queryParams['industry'] = _industry!;
      if (_exchange != null) queryParams['exchange'] = _exchange!;
      if (_country != null) queryParams['country'] = _country!;
      if (_isEtf != null) queryParams['isEtf'] = _isEtf!.toString();
      if (_isFund != null) queryParams['isFund'] = _isFund!.toString();
      if (_isActivelyTrading != null)
        queryParams['isActivelyTrading'] = _isActivelyTrading!.toString();
      queryParams['limit'] = _limit.toString();
      queryParams['includeAllShareClasses'] = _includeAllShareClasses
          .toString();

      // Build URL with query parameters
      final uri = Uri.https(
        'financialmodelingprep.com',
        '/api/v3/stock-screener',
        queryParams,
      );

      final response = await http.get(
        uri.replace(
          queryParameters: {...uri.queryParameters, 'apikey': apiKey},
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _filteredStocks = data
              .map((json) => FilteredStock.fromJson(json))
              .toList();
          _filtersApplied = true;
          _isLoading = false;
        });
      } else {
        throw Exception(
          'Failed to fetch filtered stocks: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _marketCapMin = null;
      _marketCapMax = null;
      _priceMin = null;
      _priceMax = null;
      _betaMin = null;
      _betaMax = null;
      _volumeMin = null;
      _volumeMax = null;
      _changeMin = null;
      _changeMax = null;
      _dividendMin = null;
      _dividendMax = null;
      _sector = null;
      _industry = null;
      _exchange = null;
      _country = null;
      _isEtf = null;
      _isFund = null;
      _isActivelyTrading = null;
      _limit = 100;
      _includeAllShareClasses = false;
      _filteredStocks = [];
      _filtersApplied = false;
      _error = null;
    });
  }

  Widget _buildFilteredResultsScrollable(ThemeData theme) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading filtered stocks',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_filteredStocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              color: theme.colorScheme.onSurfaceVariant,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No stocks match your criteria',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters to see more results',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Filtered Results (${_filteredStocks.length})',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredStocks.length,
            itemBuilder: (context, index) {
              final stock = _filteredStocks[index];

              return EnhancedStockCard(
                stock: FilteredStockAdapter(stock),
                marketHours: _marketHours,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/detail',
                  arguments: {'symbol': stock.symbol},
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getMarketCapCategory(double marketCap) {
    if (marketCap >= 200e9) {
      // $200B+
      return 'Mega Cap';
    } else if (marketCap >= 10e9) {
      // $10B-$200B
      return 'Large Cap';
    } else if (marketCap >= 2e9) {
      // $2B-$10B
      return 'Mid Cap';
    } else if (marketCap >= 300e6) {
      // $300M-$2B
      return 'Small Cap';
    } else if (marketCap >= 50e6) {
      // $50M-$300M
      return 'Micro Cap';
    } else {
      // <$50M
      return 'Nano Cap';
    }
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

/// Model class for filtered stock data
class FilteredStock {
  final String symbol;
  final String name;
  final double price;
  final double changesPercentage;
  final double volume;
  final double? beta;
  final String? sector;
  final double? marketCap;
  final String? exchange;
  final String? country;
  final double? yearHigh;
  final double? yearLow;

  FilteredStock({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changesPercentage,
    required this.volume,
    this.beta,
    this.sector,
    this.marketCap,
    this.exchange,
    this.country,
    this.yearHigh,
    this.yearLow,
  });

  factory FilteredStock.fromJson(Map<String, dynamic> json) {
    return FilteredStock(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      changesPercentage: (json['changesPercentage'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      beta: (json['beta'] as num?)?.toDouble(),
      sector: json['sector']?.toString(),
      marketCap: (json['marketCap'] as num?)?.toDouble(),
      exchange: json['exchange']?.toString(),
      country: json['country']?.toString(),
      yearHigh: (json['yearHigh'] as num?)?.toDouble(),
      yearLow: (json['yearLow'] as num?)?.toDouble(),
    );
  }
}
