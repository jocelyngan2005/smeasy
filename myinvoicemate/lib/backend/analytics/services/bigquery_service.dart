import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../firestore_collections.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// BigQuery integration service for exporting Firestore data.
///
/// This service enables:
/// - Automatic data sync from Firestore to BigQuery
/// - Real-time analytics processing
/// - Looker Studio dashboard integration
class BigQueryService {
  BigQueryService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _httpClient = httpClient ?? http.Client();

  final FirebaseFirestore _db;
  final http.Client _httpClient;

  // BigQuery configuration (update these with your project details)
  static const String _projectId = 'myinvoicemate';
  static const String _datasetId = 'myinvoicemate_analytics';
  static const String _invoicesTable = 'invoices';
  static const String _analyticsTable = 'analytics_cache';

  // ---------------------------------------------------------------------------
  // Export Operations
  // ---------------------------------------------------------------------------

  /// Export all invoices for a user to BigQuery.
  ///
  /// This creates a streaming insert to BigQuery for real-time analytics.
  Future<bool> exportInvoicesToBigQuery(String userId) async {
    try {
      final invoices = await _db
          .collection(FirestoreCollections.invoices)
          .where('createdBy', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .get();

      final rows = invoices.docs.map((doc) {
        final data = doc.data();
        return _prepareInvoiceRow(doc.id, data);
      }).toList();

      if (rows.isEmpty) return true;

      // Stream data to BigQuery
      return await _streamToBigQuery(_invoicesTable, rows);
    } catch (e) {
      print('Error exporting invoices to BigQuery: $e');
      return false;
    }
  }

  /// Export analytics cache to BigQuery for historical tracking.
  Future<bool> exportAnalyticsCacheToBigQuery(String userId) async {
    try {
      final cacheDoc = await _db
          .collection(FirestoreCollections.analyticsCache)
          .doc(userId)
          .get();

      if (!cacheDoc.exists) return false;

      final data = cacheDoc.data()!;
      final row = _prepareAnalyticsRow(userId, data);

      return await _streamToBigQuery(_analyticsTable, [row]);
    } catch (e) {
      print('Error exporting analytics to BigQuery: $e');
      return false;
    }
  }

  /// Schedule automatic export (call this periodically or via Cloud Functions).
  Future<void> scheduleAutoExport(String userId) async {
    await Future.wait([
      exportInvoicesToBigQuery(userId),
      exportAnalyticsCacheToBigQuery(userId),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Query Operations
  // ---------------------------------------------------------------------------

  /// Run a custom BigQuery SQL query and return results.
  ///
  /// Example: Get revenue trends with predictive insights.
  Future<List<Map<String, dynamic>>> runQuery(String sqlQuery) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return [];

      final url = Uri.parse(
        'https://bigquery.googleapis.com/bigquery/v2/projects/$_projectId/queries',
      );

      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'query': sqlQuery,
          'useLegacySql': false,
          'timeoutMs': 10000,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return List<Map<String, dynamic>>.from(
          result['rows'] ?? [],
        );
      }

      return [];
    } catch (e) {
      print('Error running BigQuery query: $e');
      return [];
    }
  }

  /// Get revenue forecast using BigQuery ML (if model exists).
  Future<List<Map<String, dynamic>>> getRevenueForecast(String userId) async {
    final query = '''
      SELECT
        forecast_timestamp,
        forecast_value,
        prediction_interval_lower_bound,
        prediction_interval_upper_bound
      FROM
        ML.FORECAST(MODEL `$_projectId.$_datasetId.revenue_forecast_model`,
                    STRUCT(30 AS horizon))
      WHERE user_id = '$userId'
      ORDER BY forecast_timestamp
    ''';

    return await runQuery(query);
  }

  /// Get customer churn prediction insights.
  Future<List<Map<String, dynamic>>> getChurnPredictions(String userId) async {
    final query = '''
      WITH customer_activity AS (
        SELECT
          buyer_name,
          COUNT(*) as invoice_count,
          MAX(issue_date) as last_invoice_date,
          DATE_DIFF(CURRENT_DATE(), MAX(issue_date), DAY) as days_since_last_invoice,
          AVG(total_amount) as avg_invoice_value
        FROM `$_projectId.$_datasetId.$_invoicesTable`
        WHERE created_by = '$userId'
        GROUP BY buyer_name
      )
      SELECT
        buyer_name,
        invoice_count,
        last_invoice_date,
        days_since_last_invoice,
        avg_invoice_value,
        CASE
          WHEN days_since_last_invoice > 90 THEN 'High Risk'
          WHEN days_since_last_invoice > 60 THEN 'Medium Risk'
          ELSE 'Low Risk'
        END as churn_risk
      FROM customer_activity
      WHERE days_since_last_invoice > 45
      ORDER BY days_since_last_invoice DESC
    ''';

    return await runQuery(query);
  }

  // ---------------------------------------------------------------------------
  // Looker Studio Integration
  // ---------------------------------------------------------------------------

  /// Generate Looker Studio connection URL.
  ///
  /// Returns a URL that can be used to create a Looker Studio dashboard.
  String getLookerStudioConnectionUrl() {
    final encodedDataset = Uri.encodeComponent('$_projectId.$_datasetId');
    return 'https://lookerstudio.google.com/datasources/create?'
        'connectorId=BigQuery&'
        'datasetId=$encodedDataset';
  }

  /// Get pre-built dashboard template URL.
  String getLookerStudioDashboardTemplate() {
    // This would be your custom Looker Studio template
    return 'https://lookerstudio.google.com/reporting/CREATE';
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _prepareInvoiceRow(String id, Map<String, dynamic> data) {
    return {
      'invoice_id': id,
      'user_id': data['createdBy'],
      'invoice_number': data['invoiceNumber'],
      'issue_date': _formatTimestamp(data['issueDate']),
      'total_amount': data['totalAmount'],
      'currency': data['currency'] ?? 'MYR',
      'compliance_status': data['complianceStatus'],
      'buyer_name': data['buyer']?['name'],
      'buyer_tin': data['buyer']?['tin'],
      'supplier_name': data['supplier']?['name'],
      'supplier_tin': data['supplier']?['tin'],
      'tax_total': data['taxTotal'] ?? 0,
      'line_items_count': (data['lineItems'] as List?)?.length ?? 0,
      'created_at': _formatTimestamp(data['createdAt']),
      'submitted_at': _formatTimestamp(data['submittedAt']),
      'export_timestamp': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _prepareAnalyticsRow(String userId, Map<String, dynamic> data) {
    return {
      'user_id': userId,
      'total_revenue': data['totalRevenue'],
      'total_invoices': data['totalInvoices'],
      'average_invoice_value': data['averageInvoiceValue'],
      'sales_trend': json.encode(data['salesTrend']),
      'status_breakdown': json.encode(data['statusBreakdown']),
      'top_customers': json.encode(data['topCustomers']),
      'last_updated': _formatTimestamp(data['lastUpdated']),
      'export_timestamp': DateTime.now().toIso8601String(),
    };
  }

  String? _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate().toIso8601String();
    }
    return timestamp.toString();
  }

  Future<bool> _streamToBigQuery(String table, List<Map<String, dynamic>> rows) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return false;

      final url = Uri.parse(
        'https://bigquery.googleapis.com/bigquery/v2/projects/$_projectId/'
        'datasets/$_datasetId/tables/$table/insertAll',
      );

      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'rows': rows.map((row) => {
            'json': row,
            'insertId': '${row['invoice_id'] ?? row['user_id']}_${DateTime.now().millisecondsSinceEpoch}',
          }).toList(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error streaming to BigQuery: $e');
      return false;
    }
  }

  /// Get Google Cloud access token from Firebase Auth.
  Future<String?> _getAccessToken() async {
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Get ID token with Google Cloud scope
      final idToken = await user.getIdToken();
      return idToken;
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }
}
