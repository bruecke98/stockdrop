import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';

/// Screen displaying comprehensive insights for a stock symbol
class InsightsScreen extends StatefulWidget {
  final String? symbol;

  const InsightsScreen({super.key, this.symbol});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final ApiService _apiService = ApiService();
  final SupabaseService _supabaseService = SupabaseService();

  Map<String, dynamic> _insights = {};
  Map<String, String> _userNotes = {};
  bool _isLoading = true;
  String? _errorMessage;
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
          _loadInsights();
        } else {
          setState(() {
            _errorMessage = 'No stock symbol provided';
            _isLoading = false;
          });
        }
      });
    } else {
      _loadInsights();
    }
  }

  Future<void> _loadInsights() async {
    if (_stockSymbol == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load insights and user notes in parallel
      final futures = [
        _apiService.getInsights(_stockSymbol!),
        _supabaseService.getInsightNotes(_stockSymbol!),
      ];

      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          _insights = results[0];
          _userNotes = results[1] as Map<String, String>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load insights: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveNote(String insightType, String note) async {
    if (_stockSymbol == null) return;

    try {
      await _supabaseService.saveInsightNote(_stockSymbol!, insightType, note);
      setState(() {
        _userNotes[insightType] = note;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: ${e.toString()}')),
        );
      }
    }
  }

  void _showNoteDialog(String insightType, String title) {
    final controller = TextEditingController(
      text: _userNotes[insightType] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Note for $title'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Add your notes here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveNote(insightType, controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_stockSymbol ?? 'Stock'} Insights'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: RefreshIndicator(
        onRefresh: _loadInsights,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading insights...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInsights,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCompanyProfileSection(theme),
        const SizedBox(height: 16),
        _buildESGSection(theme),
        const SizedBox(height: 16),
        _buildAnalystSection(theme),
        const SizedBox(height: 16),
        _buildOwnershipSection(theme),
        const SizedBox(height: 16),
        _buildInsiderSection(theme),
        const SizedBox(height: 16),
        _buildEconomicSection(theme),
        const SizedBox(height: 16),
        _buildMergerSection(theme),
      ],
    );
  }

  Widget _buildCompanyProfileSection(ThemeData theme) {
    final profileData = _insights['companyProfile'] as Map<String, dynamic>?;

    return _buildInsightCard(
      theme: theme,
      title: 'Company Profile',
      insightType: 'profile',
      icon: Icons.business_outlined,
      child: profileData != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profileData['industry'] != null)
                  _buildDataRow(
                    'Industry',
                    profileData['industry'].toString(),
                    theme,
                  ),
                if (profileData['sector'] != null)
                  _buildDataRow(
                    'Sector',
                    profileData['sector'].toString(),
                    theme,
                  ),
                if (profileData['country'] != null)
                  _buildDataRow(
                    'Country',
                    profileData['country'].toString(),
                    theme,
                  ),
                if (profileData['marketCap'] != null)
                  _buildDataRow(
                    'Market Cap',
                    '\$${_formatLargeNumber(profileData['marketCap'])}',
                    theme,
                  ),
                if (profileData['employees'] != null)
                  _buildDataRow(
                    'Employees',
                    _formatNumber(profileData['employees']),
                    theme,
                  ),
                if (profileData['description'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Description:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profileData['description'].toString(),
                    style: theme.textTheme.bodyMedium,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company profile data is not available for this stock.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'This might be due to API limitations or the stock being recently listed.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildESGSection(ThemeData theme) {
    final esgData = _insights['esgScore'] as Map<String, dynamic>?;

    return _buildInsightCard(
      theme: theme,
      title: 'ESG Score',
      insightType: 'esg',
      icon: Icons.eco_outlined,
      child: esgData != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildESGScoreRow(
                  'Environment',
                  (esgData['environment'] ?? 0).toDouble(),
                  theme,
                ),
                _buildESGScoreRow(
                  'Social',
                  (esgData['social'] ?? 0).toDouble(),
                  theme,
                ),
                _buildESGScoreRow(
                  'Governance',
                  (esgData['governance'] ?? 0).toDouble(),
                  theme,
                ),
                const Divider(),
                Row(
                  children: [
                    Text(
                      'Overall: ${((esgData['total'] ?? 0).toDouble()).toStringAsFixed(1)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getESGColor(
                          esgData['rating']?.toString() ?? 'N/A',
                        ).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        esgData['rating']?.toString() ?? 'N/A',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getESGColor(
                            esgData['rating']?.toString() ?? 'N/A',
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESG (Environmental, Social, Governance) data is not available for this stock.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'ESG data may not be available for all stocks, especially smaller companies or recently listed stocks.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }

  Color _getESGColor(String rating) {
    switch (rating.toUpperCase()) {
      case 'A':
      case 'AA':
      case 'AAA':
        return Colors.green;
      case 'B':
      case 'BB':
      case 'BBB':
        return Colors.orange;
      case 'C':
      case 'CC':
      case 'CCC':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildESGScoreRow(String label, double score, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                score >= 70
                    ? Colors.green
                    : score >= 50
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score.toStringAsFixed(1),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalystSection(ThemeData theme) {
    final analystData = _insights['analystEstimates'] as Map<String, dynamic>?;

    return _buildInsightCard(
      theme: theme,
      title: 'Analyst Estimates',
      insightType: 'analyst',
      icon: Icons.analytics_outlined,
      child: analystData != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDataRow(
                  'Revenue Est.',
                  analystData['estimatedRevenue']?.toString() ?? 'N/A',
                  theme,
                ),
                _buildDataRow(
                  'EPS Est.',
                  analystData['estimatedEps']?.toString() ?? 'N/A',
                  theme,
                ),
                _buildDataRow(
                  'Number of Analysts',
                  analystData['numberAnalystEstimatedRevenue']?.toString() ??
                      'N/A',
                  theme,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analyst estimates are not available for this stock.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Analyst coverage may be limited for smaller companies or stocks with low trading volume.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOwnershipSection(ThemeData theme) {
    final ownershipData =
        _insights['institutionalOwnership'] as List<Map<String, dynamic>>?;

    return _buildInsightCard(
      theme: theme,
      title: 'Institutional Ownership',
      insightType: 'institutional',
      icon: Icons.business_outlined,
      child: ownershipData != null && ownershipData.isNotEmpty
          ? Column(
              children: ownershipData
                  .take(5)
                  .map(
                    (item) => _buildDataRow(
                      item['investorName']?.toString() ?? 'Unknown',
                      '${(item['sharesHeld'] ?? 0)} shares',
                      theme,
                    ),
                  )
                  .toList(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Institutional ownership data is not available for this stock.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'This data shows major institutional investors like pension funds, mutual funds, and hedge funds.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInsiderSection(ThemeData theme) {
    final insiderData =
        _insights['insiderTrading'] as List<Map<String, dynamic>>?;

    return _buildInsightCard(
      theme: theme,
      title: 'Insider Trading',
      insightType: 'insider',
      icon: Icons.person_outline,
      child: insiderData != null && insiderData.isNotEmpty
          ? Column(
              children: insiderData
                  .take(5)
                  .map(
                    (item) => _buildDataRow(
                      item['reportingName']?.toString() ?? 'Unknown',
                      '${item['transactionType']?.toString() ?? 'Unknown'} - ${item['securitiesOwnedFollowingTransaction'] ?? 0} shares',
                      theme,
                    ),
                  )
                  .toList(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insider trading data is not available for this stock.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'This shows trading activity by company executives and major shareholders.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEconomicSection(ThemeData theme) {
    final economicData =
        _insights['economicCalendar'] as List<Map<String, dynamic>>?;

    return _buildInsightCard(
      theme: theme,
      title: 'Economic Events',
      insightType: 'economic',
      icon: Icons.calendar_today_outlined,
      child: economicData != null && economicData.isNotEmpty
          ? Column(
              children: economicData
                  .take(5)
                  .map(
                    (item) => _buildDataRow(
                      item['event']?.toString() ?? 'Unknown Event',
                      item['date']?.toString().split('T')[0] ?? 'Unknown Date',
                      theme,
                    ),
                  )
                  .toList(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Economic events data is not available.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'This section shows upcoming economic events that might affect the stock market.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMergerSection(ThemeData theme) {
    final mergerData =
        _insights['mergersAcquisitions'] as List<Map<String, dynamic>>?;

    return _buildInsightCard(
      theme: theme,
      title: 'Mergers & Acquisitions',
      insightType: 'mergers',
      icon: Icons.merge_outlined,
      child: mergerData != null && mergerData.isNotEmpty
          ? Column(
              children: mergerData
                  .take(5)
                  .map(
                    (item) => _buildDataRow(
                      '${item['targetedCompany']?.toString() ?? 'Unknown'} ← ${item['acquiringCompany']?.toString() ?? 'Unknown'}',
                      item['announcedDate']?.toString().split('T')[0] ??
                          'Unknown Date',
                      theme,
                    ),
                  )
                  .toList(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mergers & acquisitions data is not available.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'This section shows recent M&A activity that might be relevant to this stock.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDataRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required ThemeData theme,
    required String title,
    required String insightType,
    required IconData icon,
    required Widget child,
  }) {
    final hasNote = _userNotes[insightType]?.isNotEmpty ?? false;

    return Card(
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasNote)
              Icon(
                Icons.note_outlined,
                color: theme.colorScheme.primary,
                size: 16,
              ),
            IconButton(
              icon: const Icon(Icons.edit_note_outlined),
              onPressed: () => _showNoteDialog(insightType, title),
              tooltip: 'Add note',
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                child,
                if (hasNote) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Your Note:',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _userNotes[insightType]!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Format large numbers (like market cap) with appropriate suffixes
  String _formatLargeNumber(dynamic number) {
    if (number == null) return 'N/A';

    final value = number is String
        ? double.tryParse(number) ?? 0
        : number.toDouble();

    if (value >= 1e12) {
      return '${(value / 1e12).toStringAsFixed(2)}T';
    } else if (value >= 1e9) {
      return '${(value / 1e9).toStringAsFixed(2)}B';
    } else if (value >= 1e6) {
      return '${(value / 1e6).toStringAsFixed(2)}M';
    } else if (value >= 1e3) {
      return '${(value / 1e3).toStringAsFixed(2)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  /// Format regular numbers with commas
  String _formatNumber(dynamic number) {
    if (number == null) return 'N/A';

    final value = number is String ? int.tryParse(number) ?? 0 : number.toInt();
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]},',
    );
  }
}
