/// Alert category — used for tab filtering in NotificationScreen.
enum AlertCategory {
  lhdn,      // Compliance / LHDN / MyInvois submissions
  financial, // Cash-flow, due dates, revenue
  audit,     // Record integrity, exports, imports
}

/// Alert severity — drives colour coding in the UI.
enum AlertSeverity {
  critical, // Red
  high,     // Orange
  medium,   // Amber / Blue
  low,      // Grey / Green
}

class ComplianceAlert {
  final String id;
  final String title;
  final String message;
  /// Visual type: 'error' | 'warning' | 'info' | 'deadline' | 'success'
  final String type;
  /// Functional grouping for tab bar.
  final AlertCategory category;
  final AlertSeverity severity;
  final DateTime deadline;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedInvoiceId;
  final Map<String, dynamic>? metadata;

  ComplianceAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.category = AlertCategory.lhdn,
    this.severity = AlertSeverity.medium,
    required this.deadline,
    DateTime? createdAt,
    this.isRead = false,
    this.relatedInvoiceId,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Derives [AlertCategory] from a stored string (for backwards compat).
  static AlertCategory _categoryFromString(String? v) {
    switch (v) {
      case 'financial':
        return AlertCategory.financial;
      case 'audit':
        return AlertCategory.audit;
      default:
        return AlertCategory.lhdn;
    }
  }

  static AlertSeverity _severityFromString(String? v) {
    switch (v) {
      case 'critical':
        return AlertSeverity.critical;
      case 'high':
        return AlertSeverity.high;
      case 'low':
        return AlertSeverity.low;
      default:
        return AlertSeverity.medium;
    }
  }

  factory ComplianceAlert.fromJson(Map<String, dynamic> json) {
    return ComplianceAlert(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      category: _categoryFromString(json['category'] as String?),
      severity: _severityFromString(json['severity'] as String?),
      deadline: DateTime.parse(json['deadline'] ?? DateTime.now().toIso8601String()),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      relatedInvoiceId: json['relatedInvoiceId'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'category': category.name,
      'severity': severity.name,
      'deadline': deadline.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'relatedInvoiceId': relatedInvoiceId,
      if (metadata != null) 'metadata': metadata,
    };
  }

  ComplianceAlert copyWith({bool? isRead}) => ComplianceAlert(
        id: id,
        title: title,
        message: message,
        type: type,
        category: category,
        severity: severity,
        deadline: deadline,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        relatedInvoiceId: relatedInvoiceId,
        metadata: metadata,
      );
}

class ComplianceStats {
  final int totalInvoices;
  final int pendingSubmissions;
  final int submittedThisMonth;
  final double totalRevenue;
  final double complianceScore;
  final int overdueInvoices;

  ComplianceStats({
    required this.totalInvoices,
    required this.pendingSubmissions,
    required this.submittedThisMonth,
    required this.totalRevenue,
    required this.complianceScore,
    required this.overdueInvoices,
  });

  factory ComplianceStats.fromJson(Map<String, dynamic> json) {
    return ComplianceStats(
      totalInvoices: json['totalInvoices'] ?? 0,
      pendingSubmissions: json['pendingSubmissions'] ?? 0,
      submittedThisMonth: json['submittedThisMonth'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      complianceScore: (json['complianceScore'] ?? 0).toDouble(),
      overdueInvoices: json['overdueInvoices'] ?? 0,
    );
  }
}
