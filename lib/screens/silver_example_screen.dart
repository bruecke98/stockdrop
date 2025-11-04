import 'package:flutter/material.dart';
import '../widgets/commodity_card.dart';

/// Silver example screen demonstrating silver commodity tracking
/// Shows current silver price, trends, and market information
class SilverExampleScreen extends StatefulWidget {
  const SilverExampleScreen({super.key});

  @override
  State<SilverExampleScreen> createState() => _SilverExampleScreenState();
}

class _SilverExampleScreenState extends State<SilverExampleScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.circle, color: Colors.grey.shade600, size: 24),
            const SizedBox(width: 8),
            const Text('Silver Tracking'),
          ],
        ),
        centerTitle: false,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.withOpacity(0.15),
                    Colors.grey.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.circle,
                          color: Colors.grey.shade600,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Silver Commodity',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              'Real-time SIUSD tracking',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Track silver prices with real-time data from Financial Modeling Prep API. Monitor trends, analyze performance, and stay updated with precious metals market movements.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Current Silver Price Section
            _buildSectionHeader(
              theme,
              'Current Silver Price',
              Icons.trending_up,
            ),
            const SizedBox(height: 12),
            CommodityCard(
              commodityType: 'silver',
              isCompact: false,
              margin: EdgeInsets.zero,
            ),

            const SizedBox(height: 32),

            // Market Information Section
            _buildSectionHeader(
              theme,
              'Market Information',
              Icons.info_outline,
            ),
            const SizedBox(height: 12),
            _buildMarketInfoCards(theme),

            const SizedBox(height: 32),

            // Silver Facts Section
            _buildSectionHeader(theme, 'About Silver', Icons.lightbulb_outline),
            const SizedBox(height: 12),
            _buildSilverFacts(theme),

            const SizedBox(height: 32),

            // API Information
            _buildApiInfo(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildMarketInfoCards(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                theme,
                'Symbol',
                'SIUSD',
                Icons.code,
                Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                theme,
                'Market',
                'Commodities',
                Icons.store,
                Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                theme,
                'Currency',
                'USD',
                Icons.attach_money,
                Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                theme,
                'Type',
                'Precious Metal',
                Icons.diamond,
                Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSilverFacts(ThemeData theme) {
    final facts = [
      {
        'title': 'Industrial Metal',
        'description':
            'Silver has the highest electrical and thermal conductivity of all metals.',
        'icon': Icons.electrical_services,
      },
      {
        'title': 'Investment Asset',
        'description':
            'Precious metal used as store of value and portfolio diversification.',
        'icon': Icons.savings,
      },
      {
        'title': 'Medical Uses',
        'description':
            'Silver has antimicrobial properties and is used in medical applications.',
        'icon': Icons.medical_services,
      },
      {
        'title': 'Photography',
        'description':
            'Historically important in photography and still used in film.',
        'icon': Icons.camera_alt,
      },
    ];

    return Column(
      children: facts.map((fact) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  fact['icon'] as IconData,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fact['title'] as String,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fact['description'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildApiInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.api, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'API Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Data Source: Financial Modeling Prep API\nEndpoint: /quote/SIUSD\nUpdate Frequency: Real-time\nSymbol: SIUSD (Silver in USD)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
