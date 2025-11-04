import 'package:flutter/material.dart';
import '../models/gold.dart';
import '../services/api_service.dart';

/// A Material 3 designed card widget for displaying gold commodity information
///
/// Features:
/// - Real-time gold price display with GCUSD symbol
/// - Color-coded price changes (green for positive, red for negative)
/// - Material 3 design with rounded corners and proper elevation
/// - Loading states with shimmer effect
/// - Error handling with retry functionality
/// - Tap callback for navigation to gold details
/// - Responsive design that adapts to different screen sizes
class GoldCard extends StatefulWidget {
  /// Callback when the card is tapped
  final VoidCallback? onTap;

  /// Height of the card (optional, defaults to auto-sizing)
  final double? height;

  /// Whether to show a compact version of the card
  final bool isCompact;

  /// Custom card margin
  final EdgeInsets? margin;

  const GoldCard({
    super.key,
    this.onTap,
    this.height,
    this.isCompact = false,
    this.margin,
  });

  @override
  State<GoldCard> createState() => _GoldCardState();
}

class _GoldCardState extends State<GoldCard> {
  final ApiService _apiService = ApiService();
  Gold? _goldData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchGoldData();
  }

  /// Fetch gold price data from API
  Future<void> _fetchGoldData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final goldData = await _apiService.getComprehensiveGoldData();

      if (mounted) {
        setState(() {
          _goldData = goldData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Retry fetching gold data
  void _retry() {
    _fetchGoldData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin:
          widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.all(16),
          child: _buildContent(theme, colorScheme),
        ),
      ),
    );
  }

  /// Build the main content of the card
  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return _buildLoadingState(colorScheme);
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme, colorScheme);
    }

    if (_goldData == null) {
      return _buildNoDataState(theme, colorScheme);
    }

    return widget.isCompact
        ? _buildCompactContent(theme, colorScheme)
        : _buildFullContent(theme, colorScheme);
  }

  /// Build loading state with shimmer effect
  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Row(
      children: [
        // Gold icon placeholder
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.toll_outlined,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
        ),

        const SizedBox(width: 16),

        // Content placeholders
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Symbol placeholder
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              // Name placeholder
              Container(
                width: 120,
                height: 12,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),

        // Price placeholders
        Column(
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
      ],
    );
  }

  /// Build error state with retry option
  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: colorScheme.error, size: 32),
        const SizedBox(height: 8),
        Text(
          'Failed to load gold price',
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  /// Build no data state
  Widget _buildNoDataState(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.toll_outlined,
          color: colorScheme.onSurface.withOpacity(0.5),
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          'Gold price not available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  /// Build compact version of the card content
  Widget _buildCompactContent(ThemeData theme, ColorScheme colorScheme) {
    final changeColor = _goldData!.isTrendingUp
        ? colorScheme.primary
        : _goldData!.isTrendingDown
        ? colorScheme.error
        : colorScheme.onSurface;

    return Row(
      children: [
        // Gold icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.toll, color: Colors.amber, size: 20),
        ),

        const SizedBox(width: 12),

        // Symbol and price
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _goldData!.symbol,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _goldData!.formattedPrice,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),

        // Change percentage
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: changeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _goldData!.formattedChangePercent,
            style: theme.textTheme.labelSmall?.copyWith(
              color: changeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Build full version of the card content
  Widget _buildFullContent(ThemeData theme, ColorScheme colorScheme) {
    final changeColor = _goldData!.isTrendingUp
        ? colorScheme.primary
        : _goldData!.isTrendingDown
        ? colorScheme.error
        : colorScheme.onSurface;

    return Row(
      children: [
        // Gold icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.toll, color: Colors.amber, size: 28),
        ),

        const SizedBox(width: 16),

        // Symbol and name section
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _goldData!.symbol,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                _goldData!.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
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
                _goldData!.formattedPrice,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _goldData!.formattedChange,
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _goldData!.formattedChangePercent,
                      style: theme.textTheme.labelSmall?.copyWith(
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
      ],
    );
  }
}

/// Skeleton loading version of GoldCard for loading states
class GoldCardSkeleton extends StatelessWidget {
  final bool isCompact;
  final EdgeInsets? margin;

  const GoldCardSkeleton({super.key, this.isCompact = false, this.margin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon placeholder
            Container(
              width: isCompact ? 32 : 48,
              height: isCompact ? 32 : 48,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            SizedBox(width: isCompact ? 12 : 16),

            // Content placeholders
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: isCompact ? 14 : 16,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!isCompact)
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

            // Price placeholders
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: isCompact ? 14 : 16,
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
          ],
        ),
      ),
    );
  }
}
