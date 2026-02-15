import 'package:flutter/material.dart';
import '../../backend/compliance/models/compliance_model.dart';
import '../../backend/compliance/services/compliance_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _complianceService = ComplianceService();
  List<ComplianceAlert> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final alerts = await _complianceService.getComplianceAlerts();
      
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Helpers.showErrorSnackbar(context, 'Failed to load notifications');
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
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          if (_alerts.isNotEmpty)
            TextButton(
              onPressed: () {
                Helpers.showInfoSnackbar(context, 'Mark all as read');
              },
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAlerts,
              child: _alerts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _alerts.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildAlertCard(_alerts[index]),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(ComplianceAlert alert) {
    final color = _getAlertColor(alert.type);
    final icon = _getAlertIcon(alert.type);

    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          radius: 24,
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          alert.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              alert.message,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Deadline: ${Helpers.formatDate(alert.deadline)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: alert.relatedInvoiceId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_forward),
                color: AppColors.primary,
                onPressed: () {
                  Helpers.showInfoSnackbar(context, 'Opening related invoice');
                },
              )
            : null,
      ),
    );
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'warning':
        return AppColors.warning;
      case 'error':
        return AppColors.error;
      case 'deadline':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning_amber;
      case 'error':
        return Icons.error;
      case 'deadline':
        return Icons.access_time;
      default:
        return Icons.info;
    }
  }
}
