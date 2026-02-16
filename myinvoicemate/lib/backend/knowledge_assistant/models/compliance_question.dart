/// Model for compliance questions and answers
class ComplianceQuestion {
  final String id;
  final String question;
  final String answer;
  final List<String> sources;
  final List<String> relatedTopics;
  final double confidenceScore;
  final DateTime timestamp;
  final String category;

  ComplianceQuestion({
    required this.id,
    required this.question,
    required this.answer,
    required this.sources,
    required this.relatedTopics,
    required this.confidenceScore,
    required this.timestamp,
    required this.category,
  });

  factory ComplianceQuestion.fromJson(Map<String, dynamic> json) {
    return ComplianceQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      sources: (json['sources'] as List<dynamic>).cast<String>(),
      relatedTopics: (json['relatedTopics'] as List<dynamic>).cast<String>(),
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'sources': sources,
      'relatedTopics': relatedTopics,
      'confidenceScore': confidenceScore,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
    };
  }
}

/// Model for quick compliance insights
class ComplianceInsight {
  final String title;
  final String description;
  final String category;
  final CompliancePriority priority;
  final DateTime? deadline;
  final String? actionUrl;

  ComplianceInsight({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    this.deadline,
    this.actionUrl,
  });
}

enum CompliancePriority {
  critical,
  high,
  medium,
  low,
}

/// Model for compliance categories
enum ComplianceCategory {
  einvoicing,
  taxation,
  reporting,
  deadlines,
  penalties,
  exemptions,
  technical,
  general,
}

extension ComplianceCategoryExtension on ComplianceCategory {
  String get displayName {
    switch (this) {
      case ComplianceCategory.einvoicing:
        return 'E-Invoicing';
      case ComplianceCategory.taxation:
        return 'Taxation';
      case ComplianceCategory.reporting:
        return 'Reporting';
      case ComplianceCategory.deadlines:
        return 'Deadlines';
      case ComplianceCategory.penalties:
        return 'Penalties';
      case ComplianceCategory.exemptions:
        return 'Exemptions';
      case ComplianceCategory.technical:
        return 'Technical';
      case ComplianceCategory.general:
        return 'General';
    }
  }

  String get icon {
    switch (this) {
      case ComplianceCategory.einvoicing:
        return '📄';
      case ComplianceCategory.taxation:
        return '💰';
      case ComplianceCategory.reporting:
        return '📊';
      case ComplianceCategory.deadlines:
        return '⏰';
      case ComplianceCategory.penalties:
        return '⚠️';
      case ComplianceCategory.exemptions:
        return '✅';
      case ComplianceCategory.technical:
        return '🔧';
      case ComplianceCategory.general:
        return '💡';
    }
  }
}
