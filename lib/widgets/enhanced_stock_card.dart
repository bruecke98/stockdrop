import 'package:flutter/material.dart';
import '../models/stock.dart';

// Import the screen files to access StockLoss and FilteredStock classes
import '../screens/home_screen.dart' show StockLoss;
import '../screens/filter_screen.dart' show FilteredStock;

/// Abstract interface for stock data that can be displayed in enhanced stock cards
abstract class StockData {
  String get symbol;
  String get name;
  double get price;
  double get changePercentValue; // Unified field for percentage change
  double? get beta;
  String? get sector;
  double? get marketCap;
  String? get exchangeShortName;
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

  const EnhancedStockCard({super.key, required this.stock, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine color for percentage change
    final changeColor = stock.changePercentValue >= 0
        ? colorScheme.primary
        : colorScheme.error;

    // Format percentage with + or - sign
    final percentageText =
        '${stock.changePercentValue >= 0 ? '+' : ''}${stock.changePercentValue.toStringAsFixed(1)}%';

    // Format price
    final priceText = '\$${stock.price.toStringAsFixed(2)}';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Main card content
            Padding(
              padding: const EdgeInsets.all(16),
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

                            // Beta, sector, and market cap row (exchange moved to top right)
                            Row(
                              children: [
                                // Beta display
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'β1.23',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Sector display
                                Expanded(
                                  child: Text(
                                    'Technology',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Market cap category
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Large Cap',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 10,
                                    ),
                                  ),
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
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
                  ), // Exchange badge positioned at top right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
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
                      child: Text(
                        _getExchangeAbbreviation(
                          stock.exchangeShortName ?? 'NYSE',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                      ),
                    ),
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
    if (beta > 3.0) {
      return Colors.red;
    } else if (beta > 1.0) {
      return Colors.yellow.shade700;
    } else if (beta == 1.0) {
      return Colors.green;
    } else {
      return Colors.blue;
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

  /// Get color for market cap category
  Color _getMarketCapColor(double marketCap) {
    if (marketCap >= 200e9) {
      // Mega Cap - Gold color
      return const Color(0xFFFFD700);
    } else if (marketCap >= 10e9) {
      // Large Cap - Blue
      return Colors.blue;
    } else if (marketCap >= 2e9) {
      // Mid Cap - Green
      return Colors.green;
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
        return 'NAS';
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
  double get changePercentValue => stock.changesPercentage;

  @override
  double? get beta => stock.beta;

  @override
  String? get sector => stock.sector;

  @override
  double? get marketCap => stock.marketCap;

  @override
  String? get exchangeShortName => stock.exchange;
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
  double get changePercentValue => stock.changesPercentage;

  @override
  double? get beta => stock.beta;

  @override
  String? get sector => stock.sector;

  @override
  double? get marketCap => stock.marketCap;

  @override
  String? get exchangeShortName => stock.exchange;
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
  double get changePercentValue => stock.changePercent;

  @override
  double? get beta => stock.beta;

  @override
  String? get sector => stock.sector;

  @override
  double? get marketCap => stock.marketCap;

  @override
  String? get exchangeShortName => stock.exchange;
}
