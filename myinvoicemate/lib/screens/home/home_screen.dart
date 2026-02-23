import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../backend/auth/services/auth_service.dart';
import '../../backend/compliance/services/compliance_service.dart';
import '../../backend/invoice/services/firestore_invoice_service.dart';
import '../../backend/analytics/services/analytics_service.dart';
import '../../backend/analytics/services/ai_recommendations_service.dart';
import '../../backend/analytics/services/bigquery_service.dart';
import '../../backend/analytics/services/looker_studio_helper.dart';
import '../../backend/analytics/models/analytics_model.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../notifications/notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _complianceService = ComplianceService();
  final _invoiceService = FirestoreInvoiceService();
  final _analyticsService = AnalyticsService();
  final _aiRecommendationsService = AIRecommendationsService();
  final _bigQueryService = BigQueryService();
  bool _isLoading = true;
  bool _isExportingToBigQuery = false;
  int _pendingInvoices = 0;
  int _totalInvoices = 0;
  double _complianceScore = 0;
  AnalyticsData? _analyticsData;
  int _touchedIndex = -1;
  List<AIRecommendation> _aiRecommendations = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // Retrieve user ID from the auth service cache
      final authService = context.read<AuthService>();
      final userId = authService.currentUserId ?? '';

      final stats = await _complianceService.getComplianceStats(userId);
      final invoices = await _invoiceService.getInvoicesByUser(userId);
      final analytics = await _analyticsService.getAnalytics(userId);
      final aiRecommendations = await _aiRecommendationsService.getCachedRecommendations(userId);

      setState(() {
        _pendingInvoices = stats.pendingSubmissions;
        _totalInvoices = invoices.length;
        _complianceScore = stats.complianceScore;
        _analyticsData = analytics;
        _aiRecommendations = aiRecommendations;
        _isLoading = false;
      });

      // Generate fresh AI recommendations in background
      _refreshAIRecommendations();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAIRecommendations() async {
    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUserId ?? '';
      final recommendations = await _aiRecommendationsService.generateRecommendations(userId);
      if (mounted) {
        setState(() {
          _aiRecommendations = recommendations;
        });
      }
    } catch (e) {
      print('Error refreshing AI recommendations: $e');
    }
  }

  Future<void> _exportToBigQuery() async {
    setState(() => _isExportingToBigQuery = true);
    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUserId ?? '';
      
      final success = await _bigQueryService.exportInvoicesToBigQuery(userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? 'Data exported to BigQuery successfully!'
                : 'Export failed. Please try again.'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingToBigQuery = false);
      }
    }
  }

  Future<void> _openLookerStudio() async {
    final url = Uri.parse(LookerStudioHelper.getConnectionUrl());
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Looker Studio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), 
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section with Notification
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      Text(
                        user?.businessName ?? 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    iconSize: 28,
                    color: AppColors.primary,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick Stats
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                // Sales Trend Chart
                _buildSalesTrendChart(),
                const SizedBox(height: 24),

                // Revenue Overview
                _buildRevenueOverview(),
                const SizedBox(height: 24),

                // Status Breakdown
                _buildSectionTitle('Invoice Status Breakdown'),
                const SizedBox(height: 12),
                _buildStatusChart(),
                const SizedBox(height: 24),

                // AI Recommendations
                if (_aiRecommendations.isNotEmpty) ...[
                  _buildAIRecommendationsCard(),
                  const SizedBox(height: 24),
                ],

                // Analytics Actions
                _buildAnalyticsActionsCard(),
                const SizedBox(height: 24),

                // Top Customers
                _buildSectionTitle('Top Customers'),
                const SizedBox(height: 12),
                _buildTopCustomers(),
              ],
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildRevenueOverview() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Helpers.formatCurrency(_analyticsData?.totalRevenue ?? 0),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total Revenue',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 56,
              color: Colors.grey[300],
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Helpers.formatCurrency(
                      _analyticsData?.averageInvoiceValue ?? 0,
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Average Invoice',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTrendChart() {
    if (_analyticsData == null) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E3193), Color(0xFF0533F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Net Cash Flow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Text(
                      'Last 6 months',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'RM${(value / 1000).toStringAsFixed(0)}k',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < _analyticsData!.salesTrend.length) {
                          return Text(
                            _analyticsData!.salesTrend[value.toInt()].period,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _analyticsData!.salesTrend
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.amount))
                        .toList(),
                    isCurved: true,
                    color: Colors.white,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF0533F4),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart() {
    if (_analyticsData == null) return const SizedBox();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: _analyticsData!.statusBreakdown
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final status = entry.value;
                        final isTouched = index == _touchedIndex;
                        final radius = isTouched ? 65.0 : 55.0;
                        
                        return PieChartSectionData(
                          value: status.count.toDouble(),
                          title: '',
                          color: isTouched ? null : const Color(0xFFB8C0E8),
                          gradient: isTouched 
                              ? const LinearGradient(
                                  colors: [Color(0xFF2E3193), Color(0xFF0533F4)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          radius: radius,
                          titleStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isTouched ? Colors.white : const Color(0xFF2E3193),
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              return;
                            }
                            _touchedIndex = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_touchedIndex == -1) ...[
                        Text(
                          '${_complianceScore.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Compliance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        Text(
                          _analyticsData!.statusBreakdown[_touchedIndex].status,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_analyticsData!.statusBreakdown[_touchedIndex].count} invoices',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Helpers.getStatusColor(
                              _analyticsData!.statusBreakdown[_touchedIndex].status,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Tap on chart sections for details',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCustomers() {
    if (_analyticsData == null) return const SizedBox();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _analyticsData!.topCustomers.entries.map((entry) {
            final total = _analyticsData!.topCustomers.values.reduce(
              (a, b) => a + b,
            );
            final percentage = (entry.value / total * 100);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        Helpers.formatCurrency(entry.value),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${percentage.toStringAsFixed(1)}% of total revenue',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAIInsightsBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2E3193).withOpacity(0.8),
            const Color(0xFF0533F4).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI-Powered Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_aiRecommendations.length} personalized recommendations ready',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshAIRecommendations,
          ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendationsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.psychology,
                  color: Color(0xFF2E3193),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'AI Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3193),
                  ),
                ),
                Spacer(), 
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF2E3193)),
                  onPressed: _refreshAIRecommendations,
                ),          
              ],
            ),
            const SizedBox(height: 20),
            ..._aiRecommendations.take(5).map((rec) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(rec.priorityColor).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(rec.priorityColor),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rec.priority.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rec.categoryIcon,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rec.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      rec.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E3193),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rec.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    if (rec.impact.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.trending_up,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Impact: ${rec.impact}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsActionsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced Analytics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3193),
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              icon: Icons.cloud_upload,
              title: 'Export to BigQuery',
              description: 'Sync data for advanced analysis',
              color: const Color(0xFF4285F4),
              isLoading: _isExportingToBigQuery,
              onTap: _exportToBigQuery,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.dashboard,
              title: 'Open Looker Studio',
              description: 'Create interactive dashboards',
              color: const Color(0xFF0F9D58),
              onTap: _openLookerStudio,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
