import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/themes/color_palette.dart';
import '../../data/providers/admin_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/ai_service.dart';

class AIInsightsDashboard extends StatefulWidget {
  const AIInsightsDashboard({super.key});

  @override
  State<AIInsightsDashboard> createState() => _AIInsightsDashboardState();
}

class _AIInsightsDashboardState extends State<AIInsightsDashboard> {
  final AIService _aiService = AIService();
  final TextEditingController _knowledgeQueryController =
      TextEditingController();

  bool _isLoading = true;
  bool _knowledgeLoading = false;
  String? _error;
  Map<String, dynamic>? _dashboard;
  Map<String, dynamic>? _ltdcOverview;
  Map<String, dynamic>? _reviewAnalysis;
  List<Map<String, dynamic>> _forecast = [];
  List<Map<String, dynamic>> _hotspots = [];
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _ltdcInsights = [];
  List<Map<String, dynamic>> _knowledgeMatches = [];

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return null;
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, val) => MapEntry(key.toString(), val),
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  @override
  void dispose() {
    _knowledgeQueryController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminProvider = context.read<AdminProvider>();
      await adminProvider.fetchAllAdminData();

      final reviewPayload = adminProvider.reviews
          .where((review) => review.comment.trim().isNotEmpty)
          .take(20)
          .map(
            (review) => <String, dynamic>{
              'comment': review.comment,
              'rating': review.rating,
              'listingTitle': review.listingTitle,
              'userName': review.userName,
            },
          )
          .toList();

      final responses = await Future.wait([
        _aiService.getDashboard().timeout(const Duration(seconds: 8)),
        _aiService.getForecast().timeout(const Duration(seconds: 8)),
        _aiService.getHotspots().timeout(const Duration(seconds: 8)),
        _aiService.getRecommendations(
          role: 'admin',
          preferences: {'focus': 'platform_insights'},
        ).timeout(const Duration(seconds: 8)),
        _aiService
            .getLtdcOverview()
            .timeout(const Duration(seconds: 8))
            .catchError((_) => null),
        _aiService
            .getLtdcInsights()
            .timeout(const Duration(seconds: 8))
            .catchError((_) => const <Map<String, dynamic>>[]),
        reviewPayload.isEmpty
            ? Future.value(null)
            : _aiService
                .analyzeReviews(reviewPayload)
                .timeout(const Duration(seconds: 8))
                .catchError((_) => null),
      ]);

      final dashboard = _asMap(responses[0]);
      if (dashboard == null) {
        throw Exception('ML dashboard unavailable');
      }

      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _forecast = _asListOfMaps(responses[1]);
        _hotspots = _asListOfMaps(responses[2]);
        _recommendations = _asListOfMaps(responses[3]);
        _ltdcOverview = _asMap(responses[4]);
        _ltdcInsights = _asListOfMaps(responses[5]);
        _reviewAnalysis = _asMap(responses[6]);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _runKnowledgeSearch() async {
    final query = _knowledgeQueryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _knowledgeLoading = true;
    });

    try {
      final response = await _aiService.queryLtdcKnowledge(query, topK: 5);
      if (!mounted) return;
      setState(() {
        _knowledgeMatches = _asListOfMaps(response?['matches']);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _knowledgeMatches = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _knowledgeLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final adminProvider = context.watch<AdminProvider>();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.psychology_alt_outlined,
                size: 56,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              Text(
                locale.translate(
                  'ML service not connected',
                  'Tshebeletso ya ML ha e hokahane',
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: Text(locale.translate('Retry', 'Leka Hape')),
              ),
            ],
          ),
        ),
      );
    }

    final systemOverview = _asMap(_dashboard?['system_overview']) ?? {};
    final revenueMetrics = _asMap(_dashboard?['revenue_metrics']) ?? {};
    final sentiment = _asMap(_dashboard?['sentiment']) ?? {};
    final aiInsights = _asMap(_dashboard?['ai_insights']) ?? {};
    final ltdcSummary = _asMap(_dashboard?['ltdc_summary']) ?? {};
    final sentimentDistribution =
        _asMap(_reviewAnalysis?['sentiment_distribution']) ?? {};
    final reviewInsights = _asListOfMaps(_reviewAnalysis?['insights']);
    final recommendedActions =
        (aiInsights['recommended_actions'] as List?) ?? const [];
    final reports = (_ltdcOverview?['reports'] as List?) ?? const [];
    final topics = (_ltdcOverview?['topics'] as List?) ?? const [];
    final legacyIntelligence = _asMap(_dashboard?['legacy_intelligence']) ?? {};
    final peakMonth = _asMap(legacyIntelligence['peak_month']) ?? {};
    final topAttractions = _asListOfMaps(legacyIntelligence['top_attractions']);
    final topMarkets = _asListOfMaps(legacyIntelligence['top_markets']);
    final fastestGrowingMarkets =
        _asListOfMaps(legacyIntelligence['fastest_growing_markets']);
    final sentimentHighlights =
        _asListOfMaps(legacyIntelligence['sentiment_highlights']);
    final seasonalHotspots =
        _asListOfMaps(legacyIntelligence['seasonal_hotspots']);
    final recentPlatformActivity =
        _buildRecentPlatformActivity(adminProvider, locale);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.green, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  locale.translate(
                    'Live AI Insights',
                    'Ditlhahlobo tse Phelang tsa AI',
                  ),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                tooltip: locale.translate('Refresh', 'Ntlafatsa'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            locale.translate(
              'Connected to the trained ML service for platform insights, LTDC knowledge, and review sentiment analytics.',
              'E hokahane le tshebeletso ya ML bakeng sa tlhahlobo ya sethala, tsebo ya LTDC, le maikutlo a ditlhahlobo.',
            ),
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricCard(
                Icons.storefront,
                locale.translate(
                  'Verified Vendors',
                  'Barekisi ba Netefaditsweng',
                ),
                '${systemOverview['verified_vendors'] ?? 0}',
                Colors.green,
              ),
              _buildMetricCard(
                Icons.receipt_long,
                locale.translate(
                  'Total Bookings',
                  'Kakaretso ya Lipeheletso',
                ),
                '${revenueMetrics['total_bookings'] ?? 0}',
                Colors.blue,
              ),
              _buildMetricCard(
                Icons.payments,
                locale.translate(
                  'Projected Revenue',
                  'Lekeno le Lebelletsweng',
                ),
                'M${revenueMetrics['projected_revenue'] ?? 0}',
                Colors.orange,
              ),
              _buildMetricCard(
                Icons.thumb_up_alt_outlined,
                locale.translate(
                  'Positive Sentiment',
                  'Maikutlo a Matle',
                ),
                sentimentDistribution.isNotEmpty
                    ? '${sentimentDistribution['positive'] ?? 0}'
                    : '${sentiment['positive_percentage'] ?? 0}%',
                Colors.purple,
              ),
            ],
          ),
          if (peakMonth.isNotEmpty ||
              topAttractions.isNotEmpty ||
              topMarkets.isNotEmpty ||
              sentimentHighlights.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionTitle(
              locale.translate(
                'Merged Intelligence',
                'Bohlale bo Kopantsweng',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (peakMonth.isNotEmpty)
                  _buildMetricCard(
                    Icons.calendar_month_outlined,
                    locale.translate('Peak Month', 'Kgwedi e Chesehang'),
                    '${peakMonth['month'] ?? '-'}',
                    Colors.deepOrange,
                  ),
                if (topAttractions.isNotEmpty)
                  _buildMetricCard(
                    Icons.terrain_outlined,
                    locale.translate('Top Attraction', 'Sebaka se Tummeng'),
                    '${topAttractions.first['name'] ?? '-'}',
                    Colors.green,
                  ),
                if (topMarkets.isNotEmpty)
                  _buildMetricCard(
                    Icons.public_outlined,
                    locale.translate('Top Market', 'Mmaraka o Moholo'),
                    '${topMarkets.first['country'] ?? '-'}',
                    Colors.blue,
                  ),
                if (sentimentHighlights.isNotEmpty)
                  _buildMetricCard(
                    Icons.favorite_border,
                    locale.translate('Visitor Love', 'Seo Baeti ba se Ratang'),
                    '${sentimentHighlights.first['label'] ?? '-'}',
                    Colors.purple,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _buildSectionTitle(
            locale.translate(
              'LTDC Knowledge Search',
              'Patlo ya Tsebo ya LTDC',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _knowledgeQueryController,
                  decoration: const InputDecoration(
                    hintText: 'Ask about arrivals, perception, attractions...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _runKnowledgeSearch(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _knowledgeLoading ? null : _runKnowledgeSearch,
                child: _knowledgeLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_knowledgeMatches.isNotEmpty)
            ..._knowledgeMatches.take(3).map(
              (match) => _buildListCard(
                icon: Icons.menu_book_outlined,
                title:
                    '${match['report_name'] ?? 'Report'} (${match['year'] ?? '-'})',
                subtitle:
                    '${match['topic'] ?? ''} • ${match['content_excerpt'] ?? ''}',
              ),
            ),
          const SizedBox(height: 24),
          _buildSectionTitle(
            locale.translate(
              'LTDC Knowledge Overview',
              'Kakaretso ya Tsebo ya LTDC',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricCard(
                Icons.library_books_outlined,
                locale.translate('Reports', 'Ditlaleho'),
                '${reports.length}',
                Colors.teal,
              ),
              _buildMetricCard(
                Icons.topic_outlined,
                locale.translate('Topics', 'Dihlooho'),
                '${topics.length > 0 ? topics.length : ((ltdcSummary['topics'] as List?)?.length ?? 0)}',
                Colors.indigo,
              ),
              _buildMetricCard(
                Icons.analytics_outlined,
                locale.translate('Metric Rows', 'Mela ya Dipalopalo'),
                '${_ltdcOverview?['metric_records'] ?? ltdcSummary['metrics_records'] ?? 0}',
                Colors.deepOrange,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(
            locale.translate(
              'Model Recommendations',
              'Likgothaletso tsa Moetso',
            ),
          ),
          const SizedBox(height: 8),
          ...recommendedActions.map(
            (action) => _buildListCard(
              icon: Icons.lightbulb_outline,
              title: '$action',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(
            locale.translate(
              'LTDC Insights',
              'Ditlhahlobo tsa LTDC',
            ),
          ),
          const SizedBox(height: 8),
          ..._ltdcInsights.take(4).map(
            (insight) => _buildListCard(
              icon: Icons.auto_graph,
              title: '${insight['title'] ?? 'Insight'}',
              subtitle: '${insight['description'] ?? ''}',
            ),
          ),
          const SizedBox(height: 24),
          if (topMarkets.isNotEmpty) ...[
            _buildSectionTitle(
              locale.translate(
                'Market Momentum',
                'Matla a Mmaraka',
              ),
            ),
            const SizedBox(height: 8),
            ...topMarkets.take(5).map(
              (market) => _buildListCard(
                icon: Icons.trending_up,
                title:
                    '${market['country'] ?? 'Market'} • ${market['market_share'] ?? 0}% share',
                subtitle:
                    '${market['arrivals'] ?? 0} arrivals • growth ${market['growth'] ?? 0}%',
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (fastestGrowingMarkets.isNotEmpty) ...[
            _buildSectionTitle(
              locale.translate(
                'Fastest Growing Markets',
                'Mebaraka e Holang ka Potlako',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: fastestGrowingMarkets.take(4).map(
                (market) {
                  return _buildMiniHighlight(
                    title: '${market['country'] ?? 'Market'}',
                    value: '+${market['growth'] ?? 0}%',
                    color: Colors.orange,
                  );
                },
              ).toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (topAttractions.isNotEmpty) ...[
            _buildSectionTitle(
              locale.translate(
                'Attraction Leaders',
                'Baetapele ba Maeto',
              ),
            ),
            const SizedBox(height: 8),
            ...topAttractions.take(4).map(
              (spot) => _buildListCard(
                icon: Icons.place_outlined,
                title:
                    '${spot['name'] ?? 'Attraction'} • ${spot['visitors'] ?? 0} visitors',
                subtitle:
                    'Popularity ${spot['popularity'] ?? 0}% • domestic ${spot['domestic_percentage'] ?? 0}%',
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (seasonalHotspots.isNotEmpty) ...[
            _buildSectionTitle(
              locale.translate(
                'Seasonal Playbook',
                'Moralo wa Dihla',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: seasonalHotspots.take(4).map(
                (season) => _buildSeasonCard(season),
              ).toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (sentimentHighlights.isNotEmpty) ...[
            _buildSectionTitle(
              locale.translate(
                'What Visitors Praise',
                'Seo Baeti ba se Rorisang',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: sentimentHighlights.take(4).map(
                (item) => _buildMiniHighlight(
                  title: '${item['label'] ?? 'Sentiment'}',
                  value: '${item['percentage'] ?? 0}%',
                  color: Colors.teal,
                ),
              ).toList(),
            ),
            const SizedBox(height: 24),
          ],
          _buildSectionTitle(
            locale.translate(
              '30-Day Forecast',
              'Polelopele ya Matsatsi a 30',
            ),
          ),
          const SizedBox(height: 8),
          ..._forecast.take(5).map(
            (entry) => _buildListCard(
              icon: Icons.trending_up,
              title:
                  '${entry['date'] ?? ''} - ${entry['predicted_bookings'] ?? entry['bookings'] ?? 0} bookings',
              subtitle:
                  '${entry['day'] ?? ''} • confidence ${entry['confidence'] ?? '-'}',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(
            locale.translate(
              'Tourism Hotspots',
              'Libaka tse Tummeng tsa Bohahlaudi',
            ),
          ),
          const SizedBox(height: 8),
          ..._hotspots.take(5).map(
            (spot) => _buildListCard(
              icon: Icons.location_on_outlined,
              title: '${spot['name'] ?? 'Unknown'}',
              subtitle:
                  '${spot['district'] ?? ''} • ${spot['category'] ?? ''} • score ${spot['score'] ?? 0}',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(
            locale.translate(
              'Suggested Activities',
              'Mesebetsi e Sisinywang',
            ),
          ),
          const SizedBox(height: 8),
          ..._recommendations.take(4).map(
            (item) => _buildListCard(
              icon: Icons.hiking,
              title: '${item['name'] ?? 'Activity'}',
              subtitle:
                  '${item['season'] ?? item['location'] ?? 'Any time'} • popularity ${item['popularity'] ?? 0}',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(
            locale.translate(
              'Review Sentiment Analysis',
              'Tlhahlobo ya Maikutlo a Ditlhahlobo',
            ),
          ),
          const SizedBox(height: 8),
          if (_reviewAnalysis == null)
            _buildListCard(
              icon: Icons.reviews_outlined,
              title: locale.translate(
                'Review sentiment model is not ready yet',
                'Moetso wa maikutlo a ditlhahlobo ha o so lokele',
              ),
            )
          else ...[
            _buildListCard(
              icon: Icons.analytics_outlined,
              title:
                  'Positive: ${sentimentDistribution['positive'] ?? 0}, Neutral: ${sentimentDistribution['neutral'] ?? 0}, Negative: ${sentimentDistribution['negative'] ?? 0}',
              subtitle:
                  'Average rating: ${_formatNumber(_reviewAnalysis?['average_rating'])}',
            ),
            ...reviewInsights.take(3).map(
              (insight) => _buildListCard(
                icon: Icons.warning_amber_rounded,
                title: '${insight['type'] ?? 'Insight'}',
                subtitle: '${insight['message'] ?? ''}',
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildSectionTitle(
            locale.translate(
              'Recent Platform Activity',
              'Mesebetsi ya Haufinyane ya Sethala',
            ),
          ),
          const SizedBox(height: 8),
          if (recentPlatformActivity.isEmpty)
            _buildListCard(
              icon: Icons.insights_outlined,
              title: locale.translate(
                'No recent platform activity yet',
                'Ha ho mesebetsi ya sethala hajoale',
              ),
            )
          else
            ...recentPlatformActivity.take(6).map(
              (item) => _buildListCard(
                icon: item['icon'] as IconData,
                title: item['title'] as String,
                subtitle: item['subtitle'] as String?,
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildRecentPlatformActivity(
    AdminProvider adminProvider,
    LocaleProvider locale,
  ) {
    final activities = <Map<String, dynamic>>[];

    final recentReviews = [...adminProvider.reviews]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentVendors = [...adminProvider.vendors]
      ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));

    activities.addAll(
      recentReviews.take(4).map(
        (review) => <String, dynamic>{
          'icon': Icons.rate_review_outlined,
          'date': review.createdAt,
          'title': locale.translate(
            'Review posted for ${review.listingTitle}',
            'Tlhahlobo e kentsoe bakeng sa ${review.listingTitle}',
          ),
          'subtitle':
              '${review.userName} • ${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
        },
      ),
    );

    activities.addAll(
      recentVendors.take(3).map(
        (vendor) => <String, dynamic>{
          'icon': Icons.storefront_outlined,
          'date': vendor.joinedAt,
          'title': locale.translate(
            'Vendor joined: ${vendor.businessName}',
            'Morekisi o kene: ${vendor.businessName}',
          ),
          'subtitle':
              '${vendor.ownerName} • ${vendor.joinedAt.day}/${vendor.joinedAt.month}/${vendor.joinedAt.year}',
        },
      ),
    );

    activities.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );

    return activities;
  }

  String _formatNumber(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return '${value ?? '-'}';
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: ColorPalette.textPrimary,
      ),
    );
  }

  Widget _buildMetricCard(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: color.withValues(alpha: 0.14),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniHighlight({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            color.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonCard(Map<String, dynamic> season) {
    final places = (season['places'] as List?) ?? const [];
    return Container(
      width: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            ColorPalette.lightGreen.withValues(alpha: 0.42),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ColorPalette.primaryGreen.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${season['season'] ?? 'Season'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          ...places.take(3).map(
                (place) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $place',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildListCard({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: ColorPalette.primaryGreen.withValues(alpha: 0.12),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: ColorPalette.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: ColorPalette.primaryGreen),
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
      ),
    );
  }
}
