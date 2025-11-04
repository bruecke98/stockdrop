import 'package:flutter/material.dart';
import '../models/commodity.dart';
import '../services/api_service.dart';

/// A Material 3 card widget that displays commodity price information
/// Supports gold, silver, and oil with real-time data from Financial Modeling Prep API
class CommodityCard extends StatefulWidget {
  final String commodityType; // 'gold', 'silver', 'oil'
  final bool isCompact;
  final EdgeInsets margin;

  const CommodityCard({
    super.key,
    required this.commodityType,
    this.isCompact = false,
    this.margin = const EdgeInsets.all(8.0),
  });

  @override
  State<CommodityCard> createState() => _CommodityCardState();
}

class _CommodityCardState extends State<CommodityCard> {
  final ApiService _apiService = ApiService();
  Commodity? _commodity;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCommodityData();
  }

  Future<void> _fetchCommodityData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final commodity = await _apiService.getCommodityPrice(
        widget.commodityType,
      );

      if (mounted) {
        setState(() {
          _commodity = commodity;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactCard(context);
    }

    return _buildFullCard(context);
  }

  Widget _buildCompactCard(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Container(
        margin: widget.margin,
        width: 100,
        height: 40,
        child: const CommodityCardSkeleton(isCompact: true),
      );
    }

    if (_error != null || _commodity == null) {
      return Container(
        margin: widget.margin,
        width: 100,
        height: 40,
        child: Card(
          child: Container(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                Text(
                  'Error',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final commodity = _commodity!;
    final isPositive = commodity.changePercent >= 0;

    return Container(
      margin: widget.margin,
      width: 100,
      height: 40,
      child: Card(
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                commodity.formattedPrice,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                commodity.formattedChangePercent,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isPositive
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: widget.margin,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: _fetchCommodityData,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: _isLoading
                ? const CommodityCardSkeleton()
                : _error != null
                ? _buildErrorState(theme)
                : _buildLoadedState(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_getCommodityIcon(), color: theme.colorScheme.error, size: 24),
            const SizedBox(width: 8),
            Text(
              _getCommodityDisplayName(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Failed to load data',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: _fetchCommodityData, child: const Text('Retry')),
      ],
    );
  }

  Widget _buildLoadedState(ThemeData theme) {
    final commodity = _commodity!;
    final isPositive = commodity.changePercent >= 0;
    final commodityColor = Color(commodity.primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon and name
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: commodityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getCommodityIcon(), color: commodityColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getCommodityDisplayName(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    commodity.symbol,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              color: isPositive ? Colors.green : Colors.red,
              size: 20,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Price information
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              commodity.formattedPrice,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositive
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                commodity.formattedChangePercent,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isPositive
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Change amount
        Text(
          commodity.formattedChange,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isPositive ? Colors.green.shade600 : Colors.red.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 12),

        // Last updated
        Text(
          'Updated ${_getRelativeTime(commodity.lastUpdated)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  IconData _getCommodityIcon() {
    switch (widget.commodityType.toLowerCase()) {
      case 'gold':
        return Icons.toll;
      case 'silver':
        return Icons.circle;
      case 'oil':
        return Icons.local_gas_station;
      default:
        return Icons.trending_up;
    }
  }

  String _getCommodityDisplayName() {
    switch (widget.commodityType.toLowerCase()) {
      case 'gold':
        return 'Gold';
      case 'silver':
        return 'Silver';
      case 'oil':
        return 'Crude Oil';
      default:
        return widget.commodityType.toUpperCase();
    }
  }

  String _getRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'recently';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Skeleton loading widget for commodity card
class CommodityCardSkeleton extends StatefulWidget {
  final bool isCompact;

  const CommodityCardSkeleton({super.key, this.isCompact = false});

  @override
  State<CommodityCardSkeleton> createState() => _CommodityCardSkeletonState();
}

class _CommodityCardSkeletonState extends State<CommodityCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isCompact) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(
                    0.1 * _animation.value,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(
                    0.1 * _animation.value,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = 0.1 * _animation.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(opacity),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 16,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(
                            opacity,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 60,
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(
                            opacity,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: 120,
              height: 24,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(opacity),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 80,
              height: 16,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(opacity),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        );
      },
    );
  }
}
