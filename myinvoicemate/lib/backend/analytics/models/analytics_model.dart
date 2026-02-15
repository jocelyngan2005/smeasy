class AnalyticsData {
  final List<SalesDataPoint> salesTrend;
  final List<InvoiceStatusCount> statusBreakdown;
  final double totalRevenue;
  final double averageInvoiceValue;
  final int totalInvoices;
  final Map<String, double> topCustomers;

  AnalyticsData({
    required this.salesTrend,
    required this.statusBreakdown,
    required this.totalRevenue,
    required this.averageInvoiceValue,
    required this.totalInvoices,
    required this.topCustomers,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      salesTrend: (json['salesTrend'] as List?)
              ?.map((e) => SalesDataPoint.fromJson(e))
              .toList() ??
          [],
      statusBreakdown: (json['statusBreakdown'] as List?)
              ?.map((e) => InvoiceStatusCount.fromJson(e))
              .toList() ??
          [],
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      averageInvoiceValue: (json['averageInvoiceValue'] ?? 0).toDouble(),
      totalInvoices: json['totalInvoices'] ?? 0,
      topCustomers: Map<String, double>.from(json['topCustomers'] ?? {}),
    );
  }
}

class SalesDataPoint {
  final String period;
  final double amount;
  final int count;

  SalesDataPoint({
    required this.period,
    required this.amount,
    required this.count,
  });

  factory SalesDataPoint.fromJson(Map<String, dynamic> json) {
    return SalesDataPoint(
      period: json['period'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      count: json['count'] ?? 0,
    );
  }
}

class InvoiceStatusCount {
  final String status;
  final int count;

  InvoiceStatusCount({
    required this.status,
    required this.count,
  });

  factory InvoiceStatusCount.fromJson(Map<String, dynamic> json) {
    return InvoiceStatusCount(
      status: json['status'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}
