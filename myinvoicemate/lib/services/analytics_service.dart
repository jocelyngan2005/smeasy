import '../models/analytics_model.dart';

class AnalyticsService {
  // Get sales analytics
  Future<AnalyticsData> getAnalytics() async {
    await Future.delayed(const Duration(seconds: 1));

    return AnalyticsData(
      salesTrend: _generateSalesTrend(),
      statusBreakdown: _generateStatusBreakdown(),
      totalRevenue: 456789.50,
      averageInvoiceValue: 2929.42,
      totalInvoices: 156,
      topCustomers: {
        'ABC Corporation': 125000.00,
        'XYZ Enterprise': 89500.00,
        'Tech Solutions Ltd': 67800.00,
        'Global Trading Co': 45600.00,
        'Modern Retail Sdn Bhd': 38900.00,
      },
    );
  }

  // Generate mock sales trend data
  List<SalesDataPoint> _generateSalesTrend() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    return months.asMap().entries.map((entry) {
      return SalesDataPoint(
        period: entry.value,
        amount: 35000 + (entry.key * 5000) + (entry.key % 2 == 0 ? 10000 : 0),
        count: 15 + (entry.key * 3),
      );
    }).toList();
  }

  // Generate mock status breakdown
  List<InvoiceStatusCount> _generateStatusBreakdown() {
    return [
      InvoiceStatusCount(status: 'submitted', count: 98),
      InvoiceStatusCount(status: 'approved', count: 42),
      InvoiceStatusCount(status: 'pending', count: 8),
      InvoiceStatusCount(status: 'draft', count: 6),
      InvoiceStatusCount(status: 'rejected', count: 2),
    ];
  }

  // Get monthly revenue comparison
  Future<Map<String, double>> getMonthlyComparison() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return {
      'currentMonth': 78500.00,
      'previousMonth': 65300.00,
      'growth': 20.2,
    };
  }

  // Get compliance trend
  Future<List<Map<String, dynamic>>> getComplianceTrend() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      {'month': 'Jan', 'score': 85.0},
      {'month': 'Feb', 'score': 88.0},
      {'month': 'Mar', 'score': 90.0},
      {'month': 'Apr', 'score': 89.0},
      {'month': 'May', 'score': 92.0},
      {'month': 'Jun', 'score': 92.5},
    ];
  }
}
