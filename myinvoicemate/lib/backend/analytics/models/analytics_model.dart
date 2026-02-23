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

/// AI-generated recommendation for business optimization.
class AIRecommendation {
  final String category; // Compliance, Revenue, Customers, Operations, Tax
  final String priority; // High, Medium, Low
  final String title;
  final String description;
  final String impact;
  final DateTime timestamp;

  AIRecommendation({
    required this.category,
    required this.priority,
    required this.title,
    required this.description,
    required this.impact,
    required this.timestamp,
  });

  factory AIRecommendation.fromJson(Map<String, dynamic> json) {
    return AIRecommendation(
      category: json['category'] ?? 'Operations',
      priority: json['priority'] ?? 'Medium',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      impact: json['impact'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'priority': priority,
      'title': title,
      'description': description,
      'impact': impact,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Get color based on priority.
  int get priorityColor {
    switch (priority.toLowerCase()) {
      case 'high':
        return 0xFFE53935; // Red
      case 'medium':
        return 0xFFFB8C00; // Orange
      case 'low':
        return 0xFF43A047; // Green
      default:
        return 0xFF757575; // Grey
    }
  }

  /// Get icon based on category.
  String get categoryIcon {
    switch (category.toLowerCase()) {
      case 'compliance':
        return '⚖️';
      case 'revenue':
        return '💰';
      case 'customers':
        return '👥';
      case 'operations':
        return '⚙️';
      case 'tax':
        return '📊';
      default:
        return '💡';
    }
  }
}

/// Analysis result for a specific invoice.
class InvoiceAnalysis {
  final List<String> complianceIssues;
  final List<String> optimizations;
  final double complianceScore;
  final String summary;

  InvoiceAnalysis({
    required this.complianceIssues,
    required this.optimizations,
    required this.complianceScore,
    required this.summary,
  });

  factory InvoiceAnalysis.empty() {
    return InvoiceAnalysis(
      complianceIssues: [],
      optimizations: [],
      complianceScore: 100.0,
      summary: 'No analysis available',
    );
  }

  factory InvoiceAnalysis.fromAI(String aiResponse) {
    // Parse AI response to extract insights
    final issues = <String>[];
    final opts = <String>[];
    final lines = aiResponse.split('\n');
    
    for (final line in lines) {
      if (line.toLowerCase().contains('issue') || 
          line.toLowerCase().contains('error') ||
          line.toLowerCase().contains('missing')) {
        issues.add(line.trim());
      } else if (line.toLowerCase().contains('suggest') ||
                 line.toLowerCase().contains('improve') ||
                 line.toLowerCase().contains('optimize')) {
        opts.add(line.trim());
      }
    }

    final score = issues.isEmpty ? 100.0 : (100 - (issues.length * 10)).toDouble();

    return InvoiceAnalysis(
      complianceIssues: issues,
      optimizations: opts,
      complianceScore: score.clamp(0, 100),
      summary: aiResponse.split('\n').first,
    );
  }
}
