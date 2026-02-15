import 'package:uuid/uuid.dart';
import '../models/compliance_model.dart';

class ComplianceService {
  final _uuid = const Uuid();

  // Get compliance statistics
  Future<ComplianceStats> getComplianceStats() async {
    await Future.delayed(const Duration(seconds: 1));

    return ComplianceStats(
      totalInvoices: 156,
      pendingSubmissions: 8,
      submittedThisMonth: 42,
      totalRevenue: 456789.50,
      complianceScore: 92.5,
      overdueInvoices: 2,
    );
  }

  // Get compliance alerts
  Future<List<ComplianceAlert>> getComplianceAlerts() async {
    await Future.delayed(const Duration(seconds: 1));

    return [
      ComplianceAlert(
        id: _uuid.v4(),
        title: 'RM10k Transaction Pending',
        message: 'Invoice INV-2026-001 exceeds RM10,000 and requires MyInvois submission',
        type: 'warning',
        deadline: DateTime.now().add(const Duration(days: 2)),
        isRead: false,
        relatedInvoiceId: 'inv_001',
      ),
      ComplianceAlert(
        id: _uuid.v4(),
        title: 'Monthly Submission Deadline',
        message: '15 invoices pending submission. Deadline: End of month',
        type: 'deadline',
        deadline: DateTime.now().add(const Duration(days: 15)),
        isRead: false,
      ),
      ComplianceAlert(
        id: _uuid.v4(),
        title: 'Compliance Update',
        message: 'New LHDN guidelines published for 2026 relaxation period',
        type: 'info',
        deadline: DateTime.now().add(const Duration(days: 30)),
        isRead: true,
      ),
    ];
  }

  // Check if invoice requires MyInvois submission
  Future<bool> requiresMyInvoisSubmission(double amount) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return amount >= 10000.0;
  }

  // Get compliance recommendations
  Future<List<String>> getComplianceRecommendations() async {
    await Future.delayed(const Duration(seconds: 1));

    return [
      'Submit 8 pending invoices to maintain compliance',
      'Review and update buyer TIN information for 3 invoices',
      'Enable automatic submission for invoices above RM10,000',
      'Schedule monthly compliance review',
      'Complete MyInvois API integration verification',
    ];
  }
}