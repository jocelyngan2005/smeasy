import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firestore_collections.dart';
import '../models/analytics_model.dart';

/// Firestore-backed analytics service.
///
/// Pre-computed aggregates are stored in /analytics_cache/{userId} and
/// refreshed on demand (or by a Cloud Function on invoice create/update).
class AnalyticsService {
  AnalyticsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _cache =>
      _db.collection(FirestoreCollections.analyticsCache);

  // ---------------------------------------------------------------------------
  // Cache read / write
  // ---------------------------------------------------------------------------

  /// Read the pre-computed [AnalyticsData] from the cache document.
  ///
  /// Falls back to computing live from the invoices collection when the cache
  /// has never been written or is stale (older than 1 hour).
  Future<AnalyticsData> getAnalytics(String userId) async {
    // 1 — try cache
    final cacheDoc = await _cache.doc(userId).get();
    if (cacheDoc.exists) {
      final data = cacheDoc.data()!;
      final lastUpdated = (data['lastUpdated'] as Timestamp?);
      final isStale = lastUpdated == null ||
          DateTime.now()
              .difference(lastUpdated.toDate())
              .inHours >=
          1;
      if (!isStale) {
        return _fromCacheDoc(data);
      }
    }

    // 2 — compute live
    final analytics = await _computeLiveAnalytics(userId);

    // 3 — write back to cache
    await _writeCacheDoc(userId, analytics);

    return analytics;
  }

  /// Force-refresh the analytics cache for [userId].
  Future<AnalyticsData> refreshAnalytics(String userId) async {
    final analytics = await _computeLiveAnalytics(userId);
    await _writeCacheDoc(userId, analytics);
    return analytics;
  }

  // ---------------------------------------------------------------------------
  // Derived queries
  // ---------------------------------------------------------------------------

  /// Month-over-month revenue comparison for [userId].
  Future<Map<String, double>> getMonthlyComparison(String userId) async {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    final [current, previous] = await Future.wait([
      _revenueInPeriod(userId, thisMonthStart, now),
      _revenueInPeriod(userId, lastMonthStart, thisMonthStart),
    ]);

    final growth = previous == 0
        ? 0.0
        : ((current - previous) / previous * 100);

    return {
      'currentMonth': current,
      'previousMonth': previous,
      'growth': growth,
    };
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<double> _revenueInPeriod(
      String userId, DateTime from, DateTime to) async {
    final snap = await _db
        .collection(FirestoreCollections.invoices)
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('complianceStatus', whereIn: ['submitted', 'accepted'])
        .where('issueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('issueDate', isLessThan: Timestamp.fromDate(to))
        .get();
    return snap.docs.fold<double>(
      0.0,
      (s, d) => s + ((d.data()['totalAmount'] as num?) ?? 0).toDouble(),
    );
  }

  Future<AnalyticsData> _computeLiveAnalytics(String userId) async {
    final snap = await _db
        .collection(FirestoreCollections.invoices)
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('issueDate', descending: false)
        .get();

    double totalRevenue = 0;
    final statusCounts = <String, int>{};
    final monthRevenue = <String, double>{};
    final topCustomersMap = <String, double>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final amount = ((data['totalAmount'] as num?) ?? 0).toDouble();
      final status = data['complianceStatus'] as String? ?? 'draft';
      final issuedTs = data['issueDate'];

      totalRevenue += amount;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;

      // Monthly trend (last 6 months)
      if (issuedTs is Timestamp) {
        final dt = issuedTs.toDate();
        final key = '${_monthName(dt.month)} ${dt.year}';
        monthRevenue[key] = (monthRevenue[key] ?? 0) + amount;
      }

      // Top customers by buyer name
      final buyerName =
          (data['buyer'] as Map<String, dynamic>?)?['name'] as String? ??
              'Unknown';
      topCustomersMap[buyerName] =
          (topCustomersMap[buyerName] ?? 0) + amount;
    }

    final totalInvoices = snap.docs.length;
    final avgValue =
        totalInvoices == 0 ? 0.0 : totalRevenue / totalInvoices;

    // Keep only last 6 months in trend
    final now = DateTime.now();
    final trendKeys = List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - i, 1);
      return '${_monthName(dt.month)} ${dt.year}';
    }).reversed.toList();

    final salesTrend = trendKeys.map((k) {
      return SalesDataPoint(
        period: k.split(' ').first, // month name only
        amount: monthRevenue[k] ?? 0,
        count: 0, // count is secondary; skip expensive recount
      );
    }).toList();

    final statusBreakdown = statusCounts.entries
        .map((e) => InvoiceStatusCount(status: e.key, count: e.value))
        .toList();

    // Top 5 customers
    final topCustomers = Map.fromEntries(
      (topCustomersMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(5),
    );

    return AnalyticsData(
      salesTrend: salesTrend,
      statusBreakdown: statusBreakdown,
      totalRevenue: totalRevenue,
      averageInvoiceValue: avgValue,
      totalInvoices: totalInvoices,
      topCustomers: topCustomers,
    );
  }

  Future<void> _writeCacheDoc(String userId, AnalyticsData data) async {
    await _cache.doc(userId).set({
      'totalRevenue': data.totalRevenue,
      'totalInvoices': data.totalInvoices,
      'averageInvoiceValue': data.averageInvoiceValue,
      'salesTrend': data.salesTrend
          .map((s) => {'period': s.period, 'amount': s.amount, 'count': s.count})
          .toList(),
      'statusBreakdown': data.statusBreakdown
          .map((s) => {'status': s.status, 'count': s.count})
          .toList(),
      'topCustomers': data.topCustomers,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  AnalyticsData _fromCacheDoc(Map<String, dynamic> data) {
    final salesTrend = (data['salesTrend'] as List<dynamic>? ?? [])
        .map((e) => SalesDataPoint(
              period: e['period'] as String? ?? '',
              amount: ((e['amount'] as num?) ?? 0).toDouble(),
              count: (e['count'] as int?) ?? 0,
            ))
        .toList();

    final statusBreakdown =
        (data['statusBreakdown'] as List<dynamic>? ?? [])
            .map((e) => InvoiceStatusCount(
                  status: e['status'] as String? ?? '',
                  count: (e['count'] as int?) ?? 0,
                ))
            .toList();

    return AnalyticsData(
      salesTrend: salesTrend,
      statusBreakdown: statusBreakdown,
      totalRevenue:
          ((data['totalRevenue'] as num?) ?? 0).toDouble(),
      averageInvoiceValue:
          ((data['averageInvoiceValue'] as num?) ?? 0).toDouble(),
      totalInvoices: (data['totalInvoices'] as int?) ?? 0,
      topCustomers:
          (data['topCustomers'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, ((v as num?) ?? 0).toDouble()),
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static String _monthName(int month) => _months[month - 1];
}
