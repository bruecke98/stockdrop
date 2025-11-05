import 'package:flutter/material.dart';

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
      body: SingleChildScrollView(
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
              _buildSectionHeader(theme, 'Loss Threshold', Icons.trending_down),
              const SizedBox(height: 16),
              _buildLossThresholdCard(theme),
              const SizedBox(height: 24),
            ],

            if (_filterType == 'gain' || _filterType == 'both') ...[
              _buildSectionHeader(theme, 'Gain Threshold', Icons.trending_up),
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
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reset Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetFilters,
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

  void _applyFilters() {
    // Here you would apply the filters to your stock data
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_buildFilterSummary()),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _lossThreshold = 5.0;
      _gainThreshold = 5.0;
      _filterType = 'loss';
      _timeframe = 'daily';
    });
  }

  String _buildFilterSummary() {
    String summary = 'Filters applied: ';

    switch (_filterType) {
      case 'loss':
        summary += 'Losses ≥ ${_lossThreshold.toStringAsFixed(1)}%';
        break;
      case 'gain':
        summary += 'Gains ≥ ${_gainThreshold.toStringAsFixed(1)}%';
        break;
      case 'both':
        summary +=
            'Losses ≥ ${_lossThreshold.toStringAsFixed(1)}% or Gains ≥ ${_gainThreshold.toStringAsFixed(1)}%';
        break;
    }

    summary += ' ($_timeframe)';
    return summary;
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
