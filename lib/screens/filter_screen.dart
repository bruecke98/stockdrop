import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Filter screen for customizing stock search and display preferences
class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // Filter options - only percentage loss/gain
  double _lossThreshold = 5.0;
  double _gainThreshold = 5.0;
  String _filterType = 'loss'; // 'loss', 'gain', or 'both'
  String _timeframe = 'daily';

  // Filtered results state
  List<FilteredStock> _filteredStocks = [];
  bool _isLoading = false;
  String? _error;
  bool _filtersApplied = false;

  final List<String> _filterTypeOptions = ['loss', 'gain', 'both'];

  final List<String> _timeframeOptions = ['daily', 'weekly', 'monthly'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filters'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter controls section
          Expanded(
            flex: _filtersApplied ? 1 : 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Percentage Filter',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Filter stocks by percentage loss or gain',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Filter Type Selection
                  _buildSectionHeader(theme, 'Filter Type', Icons.filter_alt),
                  const SizedBox(height: 16),
                  _buildFilterTypeCard(theme),
                  const SizedBox(height: 24),

                  // Percentage Thresholds
                  if (_filterType == 'loss' || _filterType == 'both') ...[
                    _buildSectionHeader(
                      theme,
                      'Loss Threshold',
                      Icons.trending_down,
                    ),
                    const SizedBox(height: 16),
                    _buildLossThresholdCard(theme),
                    const SizedBox(height: 24),
                  ],

                  if (_filterType == 'gain' || _filterType == 'both') ...[
                    _buildSectionHeader(
                      theme,
                      'Gain Threshold',
                      Icons.trending_up,
                    ),
                    const SizedBox(height: 16),
                    _buildGainThresholdCard(theme),
                    const SizedBox(height: 24),
                  ],

                  // Timeframe Selection
                  _buildSectionHeader(theme, 'Timeframe', Icons.schedule),
                  const SizedBox(height: 16),
                  _buildTimeframeCard(theme),
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
                        'Reset to Defaults',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filtered results section
          if (_filtersApplied) ...[
            Container(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            Expanded(flex: 2, child: _buildFilteredResults(theme)),
          ],
        ],
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

  Widget _buildFilterTypeCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What type of stocks to filter?',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...ListTile.divideTiles(
              context: context,
              tiles: _filterTypeOptions.map((type) {
                String title;
                String subtitle;
                IconData icon;

                switch (type) {
                  case 'loss':
                    title = 'Losing Stocks';
                    subtitle = 'Show stocks with percentage losses';
                    icon = Icons.trending_down;
                    break;
                  case 'gain':
                    title = 'Gaining Stocks';
                    subtitle = 'Show stocks with percentage gains';
                    icon = Icons.trending_up;
                    break;
                  case 'both':
                    title = 'Both Losses and Gains';
                    subtitle = 'Show stocks with significant changes';
                    icon = Icons.swap_vert;
                    break;
                  default:
                    title = type;
                    subtitle = '';
                    icon = Icons.help;
                }

                return RadioListTile<String>(
                  title: Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(title),
                    ],
                  ),
                  subtitle: Text(subtitle),
                  value: type,
                  groupValue: _filterType,
                  onChanged: (value) {
                    setState(() {
                      _filterType = value!;
                    });
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLossThresholdCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Minimum Loss Percentage',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _lossThreshold,
              min: 1.0,
              max: 20.0,
              divisions: 19,
              label: '${_lossThreshold.toStringAsFixed(1)}%',
              onChanged: (value) {
                setState(() {
                  _lossThreshold = value;
                });
              },
            ),
            Text(
              'Show stocks with at least ${_lossThreshold.toStringAsFixed(1)}% loss',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGainThresholdCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Minimum Gain Percentage',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _gainThreshold,
              min: 1.0,
              max: 20.0,
              divisions: 19,
              label: '${_gainThreshold.toStringAsFixed(1)}%',
              onChanged: (value) {
                setState(() {
                  _gainThreshold = value;
                });
              },
            ),
            Text(
              'Show stocks with at least ${_gainThreshold.toStringAsFixed(1)}% gain',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframeCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Period',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _timeframeOptions.map((timeframe) {
                final isSelected = _timeframe == timeframe;
                return ChoiceChip(
                  label: Text(timeframe.capitalize()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _timeframe = timeframe;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Calculate percentage changes over $_timeframe period',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
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
        throw Exception('FMP API key not found in environment variables');
      }

      // Use screener to get stocks with good volume and reasonable price
      final screenerUrl =
          'https://financialmodelingprep.com/api/v3/stock-screener'
          '?volumeMoreThan=100000'
          '&priceMoreThan=1'
          '&priceLowerThan=1000'
          '&limit=200'
          '&apikey=$apiKey';

      final screenerResponse = await http.get(Uri.parse(screenerUrl));

      if (screenerResponse.statusCode != 200) {
        throw Exception(
          'Failed to fetch stock screener data: ${screenerResponse.statusCode}',
        );
      }

      final List<dynamic> screenerData = json.decode(screenerResponse.body);

      if (screenerData.isEmpty) {
        throw Exception('No stocks found in screener');
      }

      // Get symbols from screener results
      final symbols = screenerData
          .map((item) => item['symbol']?.toString())
          .where((symbol) => symbol != null)
          .take(100) // Limit to avoid URL length issues
          .join(',');

      // Get detailed quotes for these stocks
      final quotesUrl =
          'https://financialmodelingprep.com/api/v3/quote/$symbols?apikey=$apiKey';
      final quotesResponse = await http.get(Uri.parse(quotesUrl));

      if (quotesResponse.statusCode != 200) {
        throw Exception(
          'Failed to fetch stock quotes: ${quotesResponse.statusCode}',
        );
      }

      final List<dynamic> quotesData = json.decode(quotesResponse.body);

      // Filter stocks based on user criteria
      final filteredStocks = quotesData
          .where((item) {
            final changesPercentage =
                (item['changesPercentage'] as num?)?.toDouble() ?? 0.0;
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
            final volume = (item['volume'] as num?)?.toDouble() ?? 0.0;

            // Basic validation to ensure we have good data
            if (price <= 0 || volume <= 0) return false;

            // Apply filter based on type and thresholds
            switch (_filterType) {
              case 'loss':
                return changesPercentage <= -_lossThreshold;
              case 'gain':
                return changesPercentage >= _gainThreshold;
              case 'both':
                return changesPercentage <= -_lossThreshold ||
                    changesPercentage >= _gainThreshold;
              default:
                return false;
            }
          })
          .map((item) => FilteredStock.fromJson(item))
          .toList();

      // Sort by change percentage (most extreme first)
      filteredStocks.sort((a, b) {
        if (_filterType == 'loss') {
          return a.changesPercentage.compareTo(
            b.changesPercentage,
          ); // Most negative first
        } else if (_filterType == 'gain') {
          return b.changesPercentage.compareTo(
            a.changesPercentage,
          ); // Most positive first
        } else {
          // For 'both', sort by absolute change magnitude
          return b.changesPercentage.abs().compareTo(a.changesPercentage.abs());
        }
      });

      setState(() {
        _filteredStocks = filteredStocks
            .take(50)
            .toList(); // Limit to 50 results
        _filtersApplied = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Found ${_filteredStocks.length} stocks matching your criteria',
          ),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      _lossThreshold = 5.0;
      _gainThreshold = 5.0;
      _filterType = 'loss';
      _timeframe = 'daily';
      _filteredStocks = [];
      _filtersApplied = false;
      _error = null;
    });
  }

  Widget _buildFilteredResults(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Results header
          Row(
            children: [
              Icon(Icons.list_alt, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Filtered Results',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${_filteredStocks.length} stocks',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Results list
          Expanded(
            child: _error != null
                ? _buildErrorWidget(theme)
                : _filteredStocks.isEmpty
                ? _buildEmptyWidget(theme)
                : ListView.builder(
                    itemCount: _filteredStocks.length,
                    itemBuilder: (context, index) {
                      final stock = _filteredStocks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getChangeColor(
                              stock.changesPercentage,
                              theme,
                            ).withOpacity(0.1),
                            child: Text(
                              stock.symbol.substring(0, 2).toUpperCase(),
                              style: TextStyle(
                                color: _getChangeColor(
                                  stock.changesPercentage,
                                  theme,
                                ),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            stock.symbol,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stock.name,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Vol: ${_formatVolume(stock.volume)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${stock.price.toStringAsFixed(2)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getChangeColor(
                                    stock.changesPercentage,
                                    theme,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${stock.changesPercentage >= 0 ? '+' : ''}${stock.changesPercentage.toStringAsFixed(1)}%',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load filtered results',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error occurred',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _applyFilters, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(ThemeData theme) {
    return Center(
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
            'No stocks found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filter criteria',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Color _getChangeColor(double changePercent, ThemeData theme) {
    if (changePercent > 0) {
      return Colors.green;
    } else if (changePercent < 0) {
      return theme.colorScheme.error;
    } else {
      return theme.colorScheme.outline;
    }
  }

  String _formatVolume(double volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(1)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toStringAsFixed(0);
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

/// Model class for filtered stock data
class FilteredStock {
  final String symbol;
  final String name;
  final double price;
  final double changesPercentage;
  final double volume;

  FilteredStock({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changesPercentage,
    required this.volume,
  });

  factory FilteredStock.fromJson(Map<String, dynamic> json) {
    return FilteredStock(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      changesPercentage: (json['changesPercentage'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
