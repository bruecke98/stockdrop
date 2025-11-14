import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../models/market_hours.dart';

// Import the screen files to access StockLoss and FilteredStock classes
import '../screens/home_screen.dart' show StockLoss;
import '../screens/filter_screen.dart' show FilteredStock;
import '../screens/search_screen.dart' show StockSearchResult;

/// Abstract interface for stock data that can be displayed in enhanced stock cards
abstract class StockData {
  String get symbol;
  String get name;
  double get price;
  double? get changePercentValue; // Unified field for percentage change
  double? get beta;
  String? get sector;
  double? get marketCap;
  String? get exchangeShortName;
  String? get country;
  double? get lastAnnualDividend;
  double? get yearHigh;
  double? get yearLow;
}

/// Enhanced stock card widget that supports multiple stock model types
/// with beta, sector, and market cap information
///
/// Features:
/// - Material 3 design with rounded corners
/// - Displays stock symbol, price, and percentage change
/// - Color-coded percentage change (red for negative, green for positive)
/// - Beta value with color coding (red >3, yellow 1-3, green =1, blue <1)
/// - Sector information display
/// - Market cap category display
/// - Responsive design with proper spacing
/// - Tap callback for navigation
class EnhancedStockCard extends StatelessWidget {
  /// The stock data to display (must implement StockData interface)
  final StockData stock;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  /// Market hours data to determine if exchange is open
  final List<MarketHours>? marketHours;

  const EnhancedStockCard({
    super.key,
    required this.stock,
    this.onTap,
    this.marketHours,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine color for percentage change
    final changeColor = stock.changePercentValue == null
        ? colorScheme.onSurfaceVariant
        : stock.changePercentValue! >= 0
        ? colorScheme.primary
        : colorScheme.error;

    // Format percentage with + or - sign
    final percentageText = stock.changePercentValue == null
        ? 'N/A'
        : '${stock.changePercentValue! >= 0 ? '+' : ''}${stock.changePercentValue!.toStringAsFixed(1)}%';

    // Format price
    final priceText = '\$${stock.price.toStringAsFixed(2)}';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Main card content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main row with symbol/name and price/change
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Symbol and logo
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Image.network(
                                      'https://images.financialmodelingprep.com/symbol/${stock.symbol}.png',
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: colorScheme.error
                                                  .withOpacity(0.1),
                                              child: Center(
                                                child: Text(
                                                  stock.symbol
                                                      .substring(0, 2)
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    color: colorScheme.error,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stock.symbol,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        stock.name,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Beta, sector, and market cap (market cap below beta/sector)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Market cap and country row (moved up)
                                if (stock.marketCap != null) ...[
                                  Row(
                                    children: [
                                      // Market cap badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getMarketCapColor(
                                            stock.marketCap!,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: _getMarketCapColor(
                                              stock.marketCap!,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${_getMarketCapCategory(stock.marketCap!)} ${_getFormattedMarketCap(stock.marketCap)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: _getMarketCapColor(
                                                  stock.marketCap!,
                                                ),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 10,
                                              ),
                                        ),
                                      ),
                                      // Country display (like sector)
                                      if (stock.country != null) ...[
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            stock.country!,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                // Beta and sector row (moved down)
                                Row(
                                  children: [
                                    // Beta display (only if beta is available)
                                    if (stock.beta != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getBetaColor(
                                            stock.beta!,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: _getBetaColor(stock.beta!),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'β${stock.beta!.toStringAsFixed(2)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: _getBetaColor(
                                                  stock.beta!,
                                                ),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    // Sector display
                                    Expanded(
                                      child: Text(
                                        stock.sector ?? 'N/A',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // 52-Week Range and Dividends row
                                Row(
                                  children: [
                                    // 52-Week Range badge
                                    if (stock.yearHigh != null &&
                                        stock.yearLow != null) ...[
                                      _buildWeekRangeBadge(theme, colorScheme),
                                      const SizedBox(width: 6),
                                    ],
                                    // Dividends badge
                                    if (stock.lastAnnualDividend != null &&
                                        stock.lastAnnualDividend! > 0) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme
                                              .surfaceContainerHighest
                                              .withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: colorScheme.outline,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'Dividends',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 10,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Price and change section
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Exchange badge above price
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.primary,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isMarketOpen(
                                          stock.exchangeShortName ?? 'NYSE',
                                        )
                                        ? Icons.wb_sunny
                                        : Icons.nightlight_round,
                                    size: 12,
                                    color:
                                        _isMarketOpen(
                                          stock.exchangeShortName ?? 'NYSE',
                                        )
                                        ? Colors.lightGreen
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getExchangeAbbreviation(
                                      stock.exchangeShortName ?? 'NYSE',
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              priceText,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: changeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                percentageText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: changeColor,
                                  fontWeight: FontWeight.bold,
                                ),
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
          ],
        ),
      ),
    );
  }

  /// Get color for beta value
  Color _getBetaColor(double beta) {
    if (beta >= 3.0) {
      return Colors.red; // Very aggressive
    } else if (beta >= 2.0) {
      return Colors.orange.shade600; // Aggressive
    } else if (beta >= 1.25) {
      return Colors.yellow.shade700; // Moderately aggressive
    } else if (beta > 1.0) {
      return Colors.teal; // Market neutral
    } else if (beta >= 0.75) {
      return Colors.blue.shade300; // Moderately defensive
    } else {
      return Colors.blue.shade400; // Very defensive
    }
  }

  /// Get market cap category
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

  /// Get formatted market cap string
  String _getFormattedMarketCap(double? marketCap) {
    if (marketCap == null) return 'N/A';

    if (marketCap >= 1e12) {
      return '\$${(marketCap / 1e12).toStringAsFixed(2)}T';
    } else if (marketCap >= 1e9) {
      return '\$${(marketCap / 1e9).toStringAsFixed(2)}B';
    } else if (marketCap >= 1e6) {
      return '\$${(marketCap / 1e6).toStringAsFixed(2)}M';
    } else {
      return '\$${marketCap.toStringAsFixed(0)}';
    }
  }

  /// Get color for market cap category
  Color _getMarketCapColor(double marketCap) {
    if (marketCap >= 200e9) {
      // Mega Cap - Cornflower Blue
      return const Color(0xFF6495ED);
    } else if (marketCap >= 10e9) {
      // Large Cap - Light Sea Green
      return const Color(0xFF20B2AA);
    } else if (marketCap >= 2e9) {
      // Mid Cap - Copper
      return const Color(0xFFB87333);
    } else if (marketCap >= 300e6) {
      // Small Cap - Orange
      return Colors.orange;
    } else if (marketCap >= 50e6) {
      // Micro Cap - Purple
      return Colors.purple;
    } else {
      // Nano Cap - Red
      return Colors.red;
    }
  }

  /// Get abbreviated exchange name
  String _getExchangeAbbreviation(String exchangeName) {
    // Handle common exchange names
    switch (exchangeName.toUpperCase()) {
      case 'NASDAQ':
        return 'NASDAQ';
      case 'NEW YORK STOCK EXCHANGE':
      case 'NYSE':
        return 'NYSE';
      case 'AMERICAN STOCK EXCHANGE':
      case 'AMEX':
        return 'AMEX';
      case 'OTC MARKETS':
      case 'OTC':
        return 'OTC';
      case 'TORONTO STOCK EXCHANGE':
      case 'TSX':
        return 'TSX';
      case 'LONDON STOCK EXCHANGE':
      case 'LSE':
        return 'LSE';
      case 'SHANGHAI STOCK EXCHANGE':
      case 'SSE':
        return 'SSE';
      case 'HONG KONG EXCHANGES AND CLEARING':
      case 'HKEX':
        return 'HKEX';
      case 'TOKYO STOCK EXCHANGE':
      case 'TSE':
        return 'TSE';
      default:
        // For unknown exchanges, take first 3-4 characters or split by space
        if (exchangeName.length <= 4) {
          return exchangeName.toUpperCase();
        }
        final parts = exchangeName.split(' ');
        if (parts.length >= 2) {
          final first = parts[0].length >= 2
              ? parts[0].substring(0, 2)
              : parts[0];
          final second = parts[1].length >= 2
              ? parts[1].substring(0, 2)
              : parts[1];
          return '$first$second'.toUpperCase();
        }
        return exchangeName.substring(0, 4).toUpperCase();
    }
  }

  /// Check if the market is currently open
  bool _isMarketOpen(String exchangeName) {
    if (marketHours == null) return false;

    // Map exchange names to the ones used in market hours API
    String mappedExchange = exchangeName.toUpperCase();
    switch (mappedExchange) {
      case 'NYSE':
        mappedExchange = 'NYSE';
        break;
      case 'NASDAQ':
        mappedExchange = 'NASDAQ';
        break;
      case 'AMEX':
        mappedExchange = 'AMEX';
        break;
      default:
        // For other exchanges, try to find a match
        break;
    }

    final marketHour = marketHours!.firstWhere(
      (mh) => mh.exchange.toUpperCase() == mappedExchange,
      orElse: () => MarketHours(
        exchange: '',
        name: '',
        openingHour: '',
        closingHour: '',
        timezone: '',
        isMarketOpen: false,
      ),
    );

    return marketHour.isMarketOpen;
  }

  Widget _buildWeekRangeBadge(ThemeData theme, ColorScheme colorScheme) {
    // Calculate position as percentage (0.0 to 1.0)
    double position = 0.5; // Default to middle if calculation fails
    if (stock.yearHigh != null &&
        stock.yearLow != null &&
        stock.yearHigh! > stock.yearLow!) {
      position =
          ((stock.price - stock.yearLow!) / (stock.yearHigh! - stock.yearLow!))
              .clamp(0.0, 1.0);
    }

    // Determine color based on position
    Color indicatorColor;
    Color textColor;
    if (position < 0.33) {
      indicatorColor = Colors.deepOrange;
      textColor = Colors.deepOrange.shade800; // Darker orange-red for text
    } else if (position < 0.67) {
      indicatorColor = Colors.amber;
      textColor = Colors.amber.shade800; // Darker yellow for text
    } else {
      indicatorColor = Colors.teal;
      textColor = Colors.teal.shade800; // Darker blue-green for text
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini progress bar
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [Colors.deepOrange, Colors.amber, Colors.teal],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: (position * 44) - 1, // Adjust for dot size
                  top: -1,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: indicatorColor, width: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '52W',
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Adapter classes to make existing models implement StockData interface

/// Adapter for StockLoss model
class StockLossAdapter implements StockData {
  final StockLoss stock;

  StockLossAdapter(this.stock);

  @override
  String get symbol => stock.symbol;

  @override
  String get name => stock.name;

  @override
  double get price => stock.price;

  @override
  double? get changePercentValue => stock.changesPercentage;

  @override
  double? get beta => stock.beta;

  @override
  String? get sector => stock.sector;

  @override
  double? get marketCap => stock.marketCap;

  @override
  String? get exchangeShortName => stock.exchange;

  @override
  String? get country => stock.country;

  @override
  double? get lastAnnualDividend => stock.lastAnnualDividend;

  @override
  double? get yearHigh => stock.yearHigh;

  @override
  double? get yearLow => stock.yearLow;
}

/// Adapter for FilteredStock model
class FilteredStockAdapter implements StockData {
  final FilteredStock stock;

  FilteredStockAdapter(this.stock);

  @override
  String get symbol => stock.symbol;

  @override
  String get name => stock.name;

  @override
  double get price => stock.price;

  @override
  double? get changePercentValue => stock.changesPercentage;

  @override
  double? get beta => stock.beta;

  @override
  String? get sector => stock.sector;

  @override
  double? get marketCap => stock.marketCap;

  @override
  String? get exchangeShortName => stock.exchange;

  @override
  String? get country => stock.country;

  @override
  double? get lastAnnualDividend => null; // Not available in FilteredStock

  @override
  double? get yearHigh => stock.yearHigh;

  @override
  double? get yearLow => stock.yearLow;
}

/// Adapter for Stock model
class StockAdapter implements StockData {
  final Stock stock;

  StockAdapter(this.stock);

  @override
  String get symbol => stock.symbol;

  @override
  String get name => stock.name;

  @override
  double get price => stock.price;

  @override
  double? get changePercentValue => stock.changePercent;

  @override
  double? get beta => stock.beta;

  @override
  String? get sector => stock.sector;

  @override
  double? get marketCap => stock.marketCap;

  @override
  String? get exchangeShortName => stock.exchange;

  @override
  String? get country => stock.country;

  @override
  double? get lastAnnualDividend => stock.lastAnnualDividend;

  @override
  double? get yearHigh => stock.yearHigh;

  @override
  double? get yearLow => stock.yearLow;
}

/// Adapter for StockSearchResult model
class StockSearchResultAdapter implements StockData {
  final StockSearchResult stock;

  StockSearchResultAdapter(this.stock);

  @override
  String get symbol => stock.symbol;

  @override
  String get name => stock.name;

  @override
  double get price => stock.price ?? 0.0;

  @override
  double? get changePercentValue => stock.changePercent;

  @override
  double? get beta => stock.beta;

  @override
  String? get sector => stock.sector;

  @override
  double? get marketCap => stock.marketCap;

  @override
  String? get exchangeShortName => stock.exchangeShortName;

  @override
  String? get country => stock.country;

  @override
  double? get lastAnnualDividend => null; // Not available in StockSearchResult

  @override
  double? get yearHigh => stock.yearHigh;

  @override
  double? get yearLow => stock.yearLow;
}
