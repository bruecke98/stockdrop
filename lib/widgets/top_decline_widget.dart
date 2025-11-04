import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';

/// Widget that displays the stock with the most decline today
/// Perfect for Android home screen widget or app dashboard
class TopDeclineWidget extends StatefulWidget {
  final VoidCallback? onTap;
  final double? height;
  final EdgeInsets? padding;

  const TopDeclineWidget({
    super.key,
    this.onTap,
    this.height = 120,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<TopDeclineWidget> createState() => _TopDeclineWidgetState();
}

class _TopDeclineWidgetState extends State<TopDeclineWidget> {
  final ApiService _apiService = ApiService();
  Stock? _topDeclineStock;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTopDeclineStock();
  }

  Future<void> _loadTopDeclineStock() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get the list of declining stocks and take the first (most declining) one
      final decliningStocks = await _apiService.getTopDecliningStocks();

      if (decliningStocks.isNotEmpty) {
        setState(() {
          _topDeclineStock =
              decliningStocks.first; // First stock has the biggest decline
          _isLoading = false;
        });

        // Also refresh the Android home screen widget
        WidgetService.refreshWidget();
      } else {
        setState(() {
          _errorMessage = 'No stocks found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: widget.height,
      padding: widget.padding,
      child: Card(
        elevation: 4,
        child: InkWell(
          onTap: widget.onTap ?? () => _onStockTap(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildContent(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return _buildLoadingState(theme);
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme);
    }

    if (_topDeclineStock == null) {
      return _buildEmptyState(theme);
    }

    return _buildStockInfo(theme);
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Row(
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Top Declining Stock',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Loading...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _errorMessage ?? 'Unknown error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadTopDeclineStock,
          icon: const Icon(Icons.refresh),
          tooltip: 'Retry',
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.trending_up, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Market Update',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No stocks available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockInfo(ThemeData theme) {
    final stock = _topDeclineStock!;
    final isNegative = stock.changePercent < 0;
    final changeColor = isNegative
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    // Choose appropriate icon and label based on change
    final icon = isNegative ? Icons.trending_down : Icons.trending_up;
    final label = isNegative ? 'Top Decline: ' : 'Top Stock: ';

    return Row(
      children: [
        // Stock indicator icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: changeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(icon, color: changeColor, size: 24),
        ),
        const SizedBox(width: 16),
        // Stock info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    stock.symbol,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '\$${stock.price.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${isNegative ? '' : '+'}${stock.changePercent.toStringAsFixed(1)}%',
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
        // Refresh button
        IconButton(
          onPressed: _loadTopDeclineStock,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          iconSize: 20,
        ),
      ],
    );
  }

  void _onStockTap(BuildContext context) {
    if (_topDeclineStock != null) {
      // Navigate to stock detail screen
      Navigator.pushNamed(
        context,
        '/detail',
        arguments: {'symbol': _topDeclineStock!.symbol},
      );
    }
  }
}

/// Compact version of the widget for smaller spaces
class CompactTopDeclineWidget extends StatelessWidget {
  final VoidCallback? onTap;

  const CompactTopDeclineWidget({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return TopDeclineWidget(
      height: 80,
      padding: const EdgeInsets.all(8),
      onTap: onTap,
    );
  }
}
