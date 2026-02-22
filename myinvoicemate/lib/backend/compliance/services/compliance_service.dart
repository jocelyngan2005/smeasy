import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firestore_collections.dart';
import '../models/compliance_model.dart';

/// Firestore-backed compliance service.
///
/// /compliance_alerts/{alertId} — per-user alerts with deadlines.
class ComplianceService {
  ComplianceService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _alerts =>
      _db.collection(FirestoreCollections.complianceAlerts);

  // ---------------------------------------------------------------------------
  // Real-time compliance stats (aggregated from the invoices collection)
  // ---------------------------------------------------------------------------

  /// Build a [ComplianceStats] snapshot for [userId] from live invoice data.
  ///
  /// For production, prefer pre-computing these in [/analytics_cache/{userId}]
  /// via a Cloud Function or the [AnalyticsService].
  Future<ComplianceStats> getComplianceStats(String userId) async {
    final snap = await _db
        .collection(FirestoreCollections.invoices)
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .get();

    int total = snap.docs.length;
    int pendingSubmissions = 0;
    int submittedThisMonth = 0;
    int overdueInvoices = 0;
    double totalRevenue = 0;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    for (final doc in snap.docs) {
      final data = doc.data();
      final status = data['complianceStatus'] as String? ?? '';
      final requiresSubmission = data['requiresSubmission'] as bool? ?? false;
      final totalAmount =
          ((data['totalAmount'] as num?) ?? 0).toDouble();

      totalRevenue += totalAmount;

      if (requiresSubmission &&
          status != 'submitted' &&
          status != 'accepted') {
        pendingSubmissions++;
      }

      if (status == 'submitted' || status == 'accepted') {
        final submissionTs = data['submissionDate'];
        if (submissionTs is Timestamp) {
          if (!submissionTs.toDate().isBefore(startOfMonth)) {
            submittedThisMonth++;
          }
        }
      }

      if (requiresSubmission && status == 'submitted') {
        final dueTs = data['dueDate'];
        if (dueTs is Timestamp && dueTs.toDate().isBefore(now)) {
          overdueInvoices++;
        }
      }
    }

    final complianceScore = total == 0
        ? 100.0
        : ((total - pendingSubmissions) / total * 100).clamp(0.0, 100.0);

    return ComplianceStats(
      totalInvoices: total,
      pendingSubmissions: pendingSubmissions,
      submittedThisMonth: submittedThisMonth,
      totalRevenue: totalRevenue,
      complianceScore: complianceScore,
      overdueInvoices: overdueInvoices,
    );
  }

  // ---------------------------------------------------------------------------
  // Compliance alerts
  // ---------------------------------------------------------------------------

  /// All unread + upcoming compliance alerts for [userId],
  /// ordered by deadline ascending.
  Future<List<ComplianceAlert>> getComplianceAlerts(String userId) async {
    final snap = await _alerts
        .where('userId', isEqualTo: userId)
        .orderBy('deadline')
        .get();
    return snap.docs.map((d) {
      final data = _fromFirestore(d.data());
      return ComplianceAlert.fromJson(data..['id'] = d.id);
    }).toList();
  }

  /// Save a new compliance alert and return its ID.
  Future<String> createAlert(ComplianceAlert alert, String userId) async {
    final doc = _alerts.doc();
    await doc.set({
      'userId': userId,
      'title': alert.title,
      'message': alert.message,
      'type': alert.type,
      'deadline': Timestamp.fromDate(alert.deadline),
      'isRead': alert.isRead,
      if (alert.relatedInvoiceId != null)
        'relatedInvoiceId': alert.relatedInvoiceId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Mark a single alert as read.
  Future<void> markAlertRead(String alertId) async {
    await _alerts.doc(alertId).update({'isRead': true});
  }

  /// Delete a compliance alert.
  Future<void> deleteAlert(String alertId) async {
    await _alerts.doc(alertId).delete();
  }

  /// Count of unread alerts for [userId] (useful for badge display).
  Future<int> getUnreadAlertCount(String userId) async {
    final snap = await _alerts
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Business logic helpers
  // ---------------------------------------------------------------------------

  /// Returns true when [amount] ≥ RM 10 000 (MyInvois submission required).
  bool requiresMyInvoisSubmission(double amount) => amount >= 10000.0;

  /// Static compliance recommendations for the current relaxation period.
  List<String> getComplianceRecommendations() {
    return [
      'Submit all invoices ≥ RM10,000 to MyInvois within 72 hours of issuance.',
      'Review and update buyer TIN information on any pending invoices.',
      'Enable automatic e-invoice submission for transactions above the threshold.',
      'Schedule a monthly compliance review to catch overdue submissions early.',
      'Verify your MyInvois API credentials are active before the next billing cycle.',
    ];
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _fromFirestore(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      }
      return MapEntry(key, value);
    });
  }
}