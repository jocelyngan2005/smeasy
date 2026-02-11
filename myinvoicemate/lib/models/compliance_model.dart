class ComplianceAlert {
  final String id;
  final String title;
  final String message;
  final String type; // 'warning', 'info', 'error', 'deadline'
  final DateTime deadline;
  final bool isRead;
  final String? relatedInvoiceId;

  ComplianceAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.deadline,
    this.isRead = false,
    this.relatedInvoiceId,
  });

  factory ComplianceAlert.fromJson(Map<String, dynamic> json) {
    return ComplianceAlert(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      deadline: DateTime.parse(json['deadline'] ?? DateTime.now().toIso8601String()),
      isRead: json['isRead'] ?? false,
      relatedInvoiceId: json['relatedInvoiceId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'deadline': deadline.toIso8601String(),
      'isRead': isRead,
      'relatedInvoiceId': relatedInvoiceId,
    };
  }
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
