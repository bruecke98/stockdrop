import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// Import the new ChartWidget
import '../widgets/chart_widget.dart';

/// Detail screen for StockDrop app
/// Shows detailed stock information including price, chart, and news
class DetailScreen extends StatefulWidget {
  final String? symbol;

  const DetailScreen({super.key, this.symbol});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  StockDetail? _stockDetail;
  List<StockNews> _news = [];
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isTogglingFavorite = false;
  String? _error;
  String? _stockSymbol;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  void _initializeScreen() {
    // Get symbol from widget parameter or route arguments
    _stockSymbol = widget.symbol;

    if (_stockSymbol == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        _stockSymbol = args?['symbol'] as String?;

        if (_stockSymbol != null) {
          _loadStockData();
        } else {
          setState(() {
            _error = 'No stock symbol provided';
            _isLoading = false;
          });
        }
      });
    } else {
      _loadStockData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_stockSymbol ?? 'Stock Details'),
        centerTitle: true,
        actions: [if (_stockDetail != null) _buildFavoriteButton(theme)],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildFavoriteButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: _isTogglingFavorite
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onSurface,
                ),
              )
            : Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : theme.colorScheme.onSurface,
              ),
        onPressed: _isTogglingFavorite ? null : _toggleFavorite,
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget(theme);
    }

    if (_stockDetail == null) {
      return _buildNotFoundWidget(theme);
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStockHeader(theme),
            const SizedBox(height: 16),
            _buildActionButtons(theme),
            const SizedBox(height: 24),
            _buildPriceChart(theme),
            const SizedBox(height: 24),
            _buildNewsSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStockHeader(ThemeData theme) {
    final stock = _stockDetail!;
    final isPositive = (stock.changesPercentage ?? 0) >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    stock.symbol.length >= 2
                        ? stock.symbol.substring(0, 2).toUpperCase()
                        : stock.symbol.toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock.symbol,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stock.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Price',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '\$${stock.price.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPositive ? '+' : ''}${stock.changesPercentage?.toStringAsFixed(2) ?? '0.00'}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Day High',
                    stock.dayHigh != null
                        ? '\$${stock.dayHigh!.toStringAsFixed(2)}'
                        : 'N/A',
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Day Low',
                    stock.dayLow != null
                        ? '\$${stock.dayLow!.toStringAsFixed(2)}'
                        : 'N/A',
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Volume',
                    stock.volume != null ? _formatVolume(stock.volume!) : 'N/A',
                    theme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/insights',
                    arguments: {'symbol': _stockSymbol},
                  );
                },
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Insights'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Add share functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share feature coming soon!')),
                  );
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceChart(ThemeData theme) {
    if (_stockSymbol == null) {
      return Card(
        child: Container(
          height: 350,
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No stock symbol available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    // Determine chart color based on stock performance
    Color? chartColor;
    if (_stockDetail != null) {
      final changePercent = _stockDetail!.changesPercentage ?? 0;
      chartColor = changePercent >= 0
          ? theme.colorScheme.primary
          : theme.colorScheme.error;
    }

    return ChartWidget(
      symbol: _stockSymbol!,
      height: 350,
      lineColor: chartColor,
    );
  }

  Widget _buildNewsSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest News',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_news.isEmpty)
              Text(
                'No recent news available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ..._news.map((article) => _buildNewsItem(article, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsItem(StockNews article, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            article.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                article.publishedDate,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                article.site,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (article != _news.last)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Divider(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
        ],
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
              'Failed to Load Stock',
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
              onPressed: _loadStockData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundWidget(ThemeData theme) {
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
              'Stock Not Found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The stock symbol "${_stockSymbol ?? 'N/A'}" could not be found.',
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

  Future<void> _loadStockData() async {
    if (_stockSymbol == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _fetchStockQuote(),
        _fetchNews(),
        _checkFavoriteStatus(),
      ]);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStockQuote() async {
    final apiKey = dotenv.env['FMP_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('FMP API key not found');
    }

    final url =
        'https://financialmodelingprep.com/api/v3/quote/$_stockSymbol?apikey=$apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        _stockDetail = StockDetail.fromJson(data.first);
      } else {
        throw Exception('Stock not found');
      }
    } else {
      throw Exception('Failed to fetch stock quote');
    }
  }

  Future<void> _fetchNews() async {
    final apiKey = dotenv.env['FMP_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return;

    try {
      final url =
          'https://financialmodelingprep.com/api/v3/stock_news?tickers=$_stockSymbol&limit=2&apikey=$apiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _news = data.map((item) => StockNews.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching news: $e');
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _stockSymbol == null) return;

    try {
      final response = await Supabase.instance.client
          .from('st_favorites')
          .select('id')
          .eq('user_id', user.id)
          .eq('symbol', _stockSymbol!)
          .maybeSingle();

      _isFavorite = response != null;
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _stockSymbol == null) return;

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      if (_isFavorite) {
        await Supabase.instance.client
            .from('st_favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('symbol', _stockSymbol!);

        setState(() {
          _isFavorite = false;
        });

        _showMessage('Removed from favorites');
      } else {
        await Supabase.instance.client.from('st_favorites').insert({
          'user_id': user.id,
          'symbol': _stockSymbol!,
        });

        setState(() {
          _isFavorite = true;
        });

        _showMessage('Added to favorites');
      }
    } catch (e) {
      _showMessage('Failed to update favorites', isError: true);
    } finally {
      setState(() {
        _isTogglingFavorite = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadStockData();
  }

  String _formatVolume(int volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toString();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// Data Models
class StockDetail {
  final String symbol;
  final String name;
  final double price;
  final double? changesPercentage;
  final double? dayHigh;
  final double? dayLow;
  final int? volume;

  StockDetail({
    required this.symbol,
    required this.name,
    required this.price,
    this.changesPercentage,
    this.dayHigh,
    this.dayLow,
    this.volume,
  });

  factory StockDetail.fromJson(Map<String, dynamic> json) {
    return StockDetail(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      changesPercentage: (json['changesPercentage'] as num?)?.toDouble(),
      dayHigh: (json['dayHigh'] as num?)?.toDouble(),
      dayLow: (json['dayLow'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toInt(),
    );
  }
}

class StockNews {
  final String title;
  final String summary;
  final String publishedDate;
  final String site;

  StockNews({
    required this.title,
    required this.summary,
    required this.publishedDate,
    required this.site,
  });

  factory StockNews.fromJson(Map<String, dynamic> json) {
    return StockNews(
      title: json['title']?.toString() ?? '',
      summary: json['text']?.toString() ?? '',
      publishedDate: json['publishedDate']?.toString() ?? '',
      site: json['site']?.toString() ?? '',
    );
  }
}
