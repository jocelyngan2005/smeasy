import 'package:flutter/material.dart';
import '../../models/compliance_model.dart';
import '../../services/compliance_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class ComplianceDashboardScreen extends StatefulWidget {
  const ComplianceDashboardScreen({super.key});

  @override
  State<ComplianceDashboardScreen> createState() => _ComplianceDashboardScreenState();
}

class _ComplianceDashboardScreenState extends State<ComplianceDashboardScreen> {
  final _complianceService = ComplianceService();
  ComplianceStats? _stats;
  List<String> _recommendations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComplianceData();
  }

  Future<void> _loadComplianceData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _complianceService.getComplianceStats();
      final recommendations = await _complianceService.getComplianceRecommendations();
      
      setState(() {
        _stats = stats;
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Helpers.showErrorSnackbar(context, 'Failed to load compliance data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Compliance Tracker', style: TextStyle(color: Colors.black),),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadComplianceData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Compliance Score and Quick Stats Combined
                    _buildComplianceOverviewCard(),
                    const SizedBox(height: 24),

                    // Recommendations
                    _buildSectionTitle('Recommendations', _recommendations.length),
                    const SizedBox(height: 8),
                    _buildRecommendationsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildComplianceOverviewCard() {
    final score = _stats?.complianceScore ?? 0;
    final color = score >= 90
        ? AppColors.success
        : score >= 70
            ? AppColors.warning
            : AppColors.error;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Compliance Score Section
            Column(
              children: [
                Text(
                  'Compliance Score',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${score.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          score >= 90 ? 'Excellent' : score >= 70 ? 'Good' : 'Needs Attention',
                          style: TextStyle(
                            fontSize: 14,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Quick Stats Section
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.pending_actions,
                    label: 'Pending',
                    value: _stats?.pendingSubmissions.toString() ?? '0',
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.warning,
                    label: 'Overdue',
                    value: _stats?.overdueInvoices.toString() ?? '0',
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.check_circle,
                    label: 'This Month',
                    value: _stats?.submittedThisMonth.toString() ?? '0',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
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
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendationsCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _recommendations.map((recommendation) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
