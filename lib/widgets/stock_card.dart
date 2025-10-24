import 'package:flutter/material.dart';
import '../models/stock.dart';

/// A reusable card widget for displaying stock information
///
/// Features:
/// - Material 3 design with rounded corners
/// - Displays stock symbol, price, and percentage change
/// - Color-coded percentage change (red for negative, green for positive)
/// - Optional favorite button with callback
/// - Tap callback for navigation
/// - Responsive design with proper spacing
class StockCard extends StatelessWidget {
  /// The stock data to display
  final Stock stock;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  /// Callback when the favorite button is pressed
  final VoidCallback? onFavoritePressed;

  /// Whether this stock is currently favorited
  final bool isFavorited;

  /// Whether to show the favorite button
  final bool showFavoriteButton;

  const StockCard({
    super.key,
    required this.stock,
    this.onTap,
    this.onFavoritePressed,
    this.isFavorited = false,
    this.showFavoriteButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine color for percentage change
    final changeColor = stock.changePercent >= 0
        ? colorScheme.primary
        : colorScheme.error;

    // Format percentage with + or - sign
    final percentageText =
        '${stock.changePercent >= 0 ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%';

    // Format price with proper decimal places
    final priceText = '\$${stock.price.toStringAsFixed(2)}';

    // Format change amount
    final changeText =
        '${stock.change >= 0 ? '+' : ''}${stock.change.toStringAsFixed(2)}';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Stock symbol and name section
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stock.symbol,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stock.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Price and change section
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      priceText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          changeText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: changeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: changeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
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
                  ],
                ),
              ),

              // Favorite button section
              if (showFavoriteButton) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onFavoritePressed,
                  icon: Icon(
                    isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: isFavorited
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                  tooltip: isFavorited
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact version of StockCard for dense lists
class CompactStockCard extends StatelessWidget {
  final Stock stock;
  final VoidCallback? onTap;
  final VoidCallback? onFavoritePressed;
  final bool isFavorited;
  final bool showFavoriteButton;

  const CompactStockCard({
    super.key,
    required this.stock,
    this.onTap,
    this.onFavoritePressed,
    this.isFavorited = false,
    this.showFavoriteButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final changeColor = stock.changePercent >= 0
        ? colorScheme.primary
        : colorScheme.error;

    final percentageText =
        '${stock.changePercent >= 0 ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%';
    final priceText = '\$${stock.price.toStringAsFixed(2)}';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Stock symbol
              Expanded(
                flex: 1,
                child: Text(
                  stock.symbol,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 12),

              // Price
              Text(
                priceText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(width: 12),

              // Percentage change
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: changeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  percentageText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Favorite button
              if (showFavoriteButton) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onFavoritePressed,
                  icon: Icon(
                    isFavorited ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: isFavorited
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                  tooltip: isFavorited
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A skeleton loading version of StockCard for loading states
class StockCardSkeleton extends StatelessWidget {
  final bool showFavoriteButton;

  const StockCardSkeleton({super.key, this.showFavoriteButton = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Stock symbol and name section
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 16,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Price and change section
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 16,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),

            // Favorite button section
            if (showFavoriteButton) ...[
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
