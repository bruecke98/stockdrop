import 'package:flutter/material.dart';
import '../widgets/commodity_card.dart';

/// Oil example screen demonstrating crude oil commodity tracking
/// Shows current oil price, trends, and market information
class OilExampleScreen extends StatefulWidget {
  const OilExampleScreen({super.key});

  @override
  State<OilExampleScreen> createState() => _OilExampleScreenState();
}

class _OilExampleScreenState extends State<OilExampleScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.local_gas_station, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            const Text('Oil Tracking', style: TextStyle(color: Colors.white)),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withOpacity(0.3),
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
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_gas_station,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crude Oil Commodity',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Real-time BZUSD tracking',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Track crude oil prices with real-time data from Financial Modeling Prep API. Monitor energy market trends, analyze performance, and stay updated with oil commodity movements.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Current Oil Price Section
            _buildSectionHeader(theme, 'Current Oil Price', Icons.trending_up),
            const SizedBox(height: 12),
            CommodityCard(
              commodityType: 'oil',
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

            // Oil Facts Section
            _buildSectionHeader(
              theme,
              'About Crude Oil',
              Icons.lightbulb_outline,
            ),
            const SizedBox(height: 12),
            _buildOilFacts(theme),

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
        Icon(icon, color: Colors.black87, size: 20),
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
                'BZUSD',
                Icons.code,
                Colors.black87,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                theme,
                'Market',
                'Energy',
                Icons.bolt,
                Colors.black87,
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
                Colors.black87,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                theme,
                'Unit',
                'Per Barrel',
                Icons.oil_barrel,
                Colors.black87,
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

  Widget _buildOilFacts(ThemeData theme) {
    final facts = [
      {
        'title': 'Energy Source',
        'description':
            'Primary source of energy for transportation and industry worldwide.',
        'icon': Icons.local_gas_station,
      },
      {
        'title': 'Global Commodity',
        'description':
            'Most traded commodity globally, affecting world economies.',
        'icon': Icons.public,
      },
      {
        'title': 'Petrochemicals',
        'description':
            'Used to produce plastics, chemicals, and synthetic materials.',
        'icon': Icons.science,
      },
      {
        'title': 'Strategic Resource',
        'description': 'Critical for national security and economic stability.',
        'icon': Icons.security,
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
            border: Border.all(color: Colors.black.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  fact['icon'] as IconData,
                  color: Colors.black87,
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
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.api, color: Colors.black87, size: 20),
              const SizedBox(width: 8),
              Text(
                'API Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Data Source: Financial Modeling Prep API\nEndpoint: /quote/BZUSD\nUpdate Frequency: Real-time\nSymbol: BZUSD (Brent Crude Oil in USD)',
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
