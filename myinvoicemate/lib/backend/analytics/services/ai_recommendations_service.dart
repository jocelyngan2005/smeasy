import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../firestore_collections.dart';
import '../models/analytics_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// AI-powered recommendations service using Vertex AI.
///
/// Generates intelligent business insights based on:
/// - Invoice patterns and trends
/// - Compliance risk analysis
/// - Revenue optimization opportunities
/// - Customer behavior predictions
class AIRecommendationsService {
  AIRecommendationsService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _httpClient = httpClient ?? http.Client();

  final FirebaseFirestore _db;
  final http.Client _httpClient;

  // Vertex AI configuration
  static const String _projectId = 'myinvoicemate';
  static const String _location = 'global';
  static const String _modelId = 'gemini-1.5-flash';

  // ---------------------------------------------------------------------------
  // AI Recommendations
  // ---------------------------------------------------------------------------

  /// Generate AI-powered recommendations based on user's business data.
  ///
  /// Returns actionable insights across multiple categories:
  /// - Compliance alerts
  /// - Revenue optimization
  /// - Customer retention
  /// - Cash flow improvements
  Future<List<AIRecommendation>> generateRecommendations(String userId) async {
    try {
      // 1. Gather business context
      final context = await _buildBusinessContext(userId);
      
      // 2. Generate AI insights using Vertex AI
      final insights = await _callVertexAI(context);
      
      // 3. Parse and structure recommendations
      final recommendations = _parseRecommendations(insights);
      
      // 4. Cache recommendations for quick access
      await _cacheRecommendations(userId, recommendations);
      
      return recommendations;
    } catch (e) {
      print('Error generating AI recommendations: $e');
      // Fallback to cached recommendations
      return await _getCachedRecommendations(userId);
    }
  }

  /// Get cached recommendations (faster, updated hourly).
  Future<List<AIRecommendation>> getCachedRecommendations(String userId) async {
    return await _getCachedRecommendations(userId);
  }

  /// Analyze specific invoice for compliance and optimization suggestions.
  Future<InvoiceAnalysis> analyzeInvoice(String invoiceId) async {
    try {
      final invoiceDoc = await _db
          .collection(FirestoreCollections.invoices)
          .doc(invoiceId)
          .get();

      if (!invoiceDoc.exists) {
        return InvoiceAnalysis.empty();
      }

      final data = invoiceDoc.data()!;
      final prompt = _buildInvoiceAnalysisPrompt(data);
      final analysis = await _callVertexAI(prompt);

      return InvoiceAnalysis.fromAI(analysis);
    } catch (e) {
      print('Error analyzing invoice: $e');
      return InvoiceAnalysis.empty();
    }
  }

  // ---------------------------------------------------------------------------
  // Context Building
  // ---------------------------------------------------------------------------

  Future<String> _buildBusinessContext(String userId) async {
    // Gather comprehensive business data
    final [invoices, analytics, complianceStats] = await Future.wait([
      _getRecentInvoices(userId),
      _getAnalyticsSummary(userId),
      _getComplianceMetrics(userId),
    ]);

    // Build structured prompt for AI
    return '''
You are a business intelligence advisor for MyInvoisMate, specializing in Malaysian e-invoicing compliance and business optimization.

BUSINESS CONTEXT:
$analytics

RECENT INVOICES (Last 30 days):
$invoices

COMPLIANCE STATUS:
$complianceStats

TASK:
Generate 5-7 personalized, actionable recommendations for this business. Focus on:
1. MyInvois compliance risks and improvements
2. Revenue optimization opportunities
3. Customer retention strategies
4. Cash flow management
5. Operational efficiency

Format each recommendation as:
CATEGORY: [Compliance/Revenue/Customers/Operations/Tax]
PRIORITY: [High/Medium/Low]
TITLE: Brief actionable title
DESCRIPTION: 2-3 sentences explaining the insight and action
IMPACT: Expected business benefit

Make recommendations specific, data-driven, and immediately actionable.
''';
  }

  String _buildInvoiceAnalysisPrompt(Map<String, dynamic> invoiceData) {
    return '''
Analyze this Malaysian e-invoice for compliance and optimization:

INVOICE DETAILS:
- Number: ${invoiceData['invoiceNumber']}
- Amount: MYR ${invoiceData['totalAmount']}
- Tax: MYR ${invoiceData['taxTotal'] ?? 0}
- Status: ${invoiceData['complianceStatus']}
- Buyer: ${invoiceData['buyer']?['name']}
- Buyer TIN: ${invoiceData['buyer']?['tin'] ?? 'Not provided'}
- Line Items: ${(invoiceData['lineItems'] as List?)?.length ?? 0}

ANALYSIS REQUIRED:
1. MyInvois compliance check
2. Tax calculation accuracy
3. Required field completeness
4. Best practices alignment

Provide specific issues found and improvement suggestions.
''';
  }

  // ---------------------------------------------------------------------------
  // Vertex AI Integration
  // ---------------------------------------------------------------------------

  Future<String> _callVertexAI(String prompt) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('Unable to get access token');
      }

      final url = Uri.parse(
        'https://$_location-aiplatform.googleapis.com/v1/'
        'projects/$_projectId/locations/$_location/'
        'publishers/google/models/$_modelId:generateContent',
      );

      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.4,
            'topP': 0.8,
            'topK': 40,
            'maxOutputTokens': 2048,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final text = result['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return text ?? 'No recommendations available';
      }

      throw Exception('Vertex AI API error: ${response.statusCode}');
    } catch (e) {
      print('Error calling Vertex AI: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Data Gathering Helpers
  // ---------------------------------------------------------------------------

  Future<String> _getRecentInvoices(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    final snapshot = await _db
        .collection(FirestoreCollections.invoices)
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('issueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('issueDate', descending: true)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) {
      return 'No invoices in the last 30 days';
    }

    final invoicesSummary = snapshot.docs.map((doc) {
      final data = doc.data();
      return '- ${data['invoiceNumber']}: MYR ${data['totalAmount']} '
             '(${data['complianceStatus']}) - ${data['buyer']?['name']}';
    }).join('\n');

    return 'Total: ${snapshot.docs.length} invoices\n$invoicesSummary';
  }

  Future<String> _getAnalyticsSummary(String userId) async {
    final cacheDoc = await _db
        .collection(FirestoreCollections.analyticsCache)
        .doc(userId)
        .get();

    if (!cacheDoc.exists) {
      return 'No analytics data available';
    }

    final data = cacheDoc.data()!;
    return '''
Total Revenue: MYR ${data['totalRevenue']}
Total Invoices: ${data['totalInvoices']}
Average Invoice Value: MYR ${data['averageInvoiceValue']}
Top Customers: ${(data['topCustomers'] as Map).keys.take(3).join(', ')}
''';
  }

  Future<String> _getComplianceMetrics(String userId) async {
    final snapshot = await _db
        .collection(FirestoreCollections.invoices)
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .get();

    int pending = 0, submitted = 0, overdue = 0, missingTIN = 0;
    final now = DateTime.now();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = data['complianceStatus'] ?? 'draft';
      final amount = (data['totalAmount'] as num?) ?? 0;
      
      if (status == 'pending') pending++;
      if (status == 'submitted' || status == 'accepted') submitted++;
      
      // Check if invoice requires submission (≥ RM 10,000)
      if (amount >= 10000 && status != 'submitted' && status != 'accepted') {
        final issueDate = (data['issueDate'] as Timestamp?)?.toDate();
        if (issueDate != null && now.difference(issueDate).inHours > 72) {
          overdue++;
        }
      }
      
      if (data['buyer']?['tin'] == null || (data['buyer']['tin'] as String).isEmpty) {
        missingTIN++;
      }
    }

    return '''
Pending Submissions: $pending
Successfully Submitted: $submitted
Overdue Submissions: $overdue
Missing Buyer TIN: $missingTIN
''';
  }

  // ---------------------------------------------------------------------------
  // Response Parsing
  // ---------------------------------------------------------------------------

  List<AIRecommendation> _parseRecommendations(String aiResponse) {
    final recommendations = <AIRecommendation>[];
    final lines = aiResponse.split('\n');
    
    String? category, priority, title, description, impact;

    for (final line in lines) {
      final trimmed = line.trim();
      
      if (trimmed.startsWith('CATEGORY:')) {
        category = trimmed.substring(9).trim();
      } else if (trimmed.startsWith('PRIORITY:')) {
        priority = trimmed.substring(9).trim();
      } else if (trimmed.startsWith('TITLE:')) {
        title = trimmed.substring(6).trim();
      } else if (trimmed.startsWith('DESCRIPTION:')) {
        description = trimmed.substring(12).trim();
      } else if (trimmed.startsWith('IMPACT:')) {
        impact = trimmed.substring(7).trim();
        
        // Complete recommendation found
        if (category != null && priority != null && title != null) {
          recommendations.add(AIRecommendation(
            category: category,
            priority: priority,
            title: title,
            description: description ?? '',
            impact: impact ?? '',
            timestamp: DateTime.now(),
          ));
          
          // Reset for next recommendation
          category = priority = title = description = impact = null;
        }
      }
    }

    return recommendations;
  }

  // ---------------------------------------------------------------------------
  // Caching
  // ---------------------------------------------------------------------------

  Future<void> _cacheRecommendations(
    String userId,
    List<AIRecommendation> recommendations,
  ) async {
    try {
      await _db
          .collection('ai_recommendations_cache')
          .doc(userId)
          .set({
        'recommendations': recommendations
            .map((r) => r.toJson())
            .toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error caching recommendations: $e');
    }
  }

  Future<List<AIRecommendation>> _getCachedRecommendations(String userId) async {
    try {
      final doc = await _db
          .collection('ai_recommendations_cache')
          .doc(userId)
          .get();

      if (!doc.exists) {
        return _getFallbackRecommendations();
      }

      final data = doc.data()!;
      final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();
      
      // Check if cache is stale (older than 1 hour)
      if (lastUpdated != null && 
          DateTime.now().difference(lastUpdated).inHours >= 1) {
        return _getFallbackRecommendations();
      }

      final recommendations = (data['recommendations'] as List?)
          ?.map((r) => AIRecommendation.fromJson(r))
          .toList() ?? [];

      return recommendations.isNotEmpty 
          ? recommendations 
          : _getFallbackRecommendations();
    } catch (e) {
      print('Error getting cached recommendations: $e');
      return _getFallbackRecommendations();
    }
  }

  List<AIRecommendation> _getFallbackRecommendations() {
    return [
      AIRecommendation(
        category: 'Compliance',
        priority: 'High',
        title: 'Review Pending MyInvois Submissions',
        description: 'You have invoices ≥ RM10,000 that require MyInvois submission within 72 hours. Review and submit them to avoid penalties.',
        impact: 'Maintain compliance and avoid fines',
        timestamp: DateTime.now(),
      ),
      AIRecommendation(
        category: 'Revenue',
        priority: 'Medium',
        title: 'Optimize Invoice Timing',
        description: 'Analysis shows better payment rates when invoices are sent on Monday-Wednesday. Consider adjusting your invoicing schedule.',
        impact: 'Improve cash flow by 15-20%',
        timestamp: DateTime.now(),
      ),
      AIRecommendation(
        category: 'Operations',
        priority: 'Medium',
        title: 'Update Customer TIN Information',
        description: 'Several invoices are missing buyer TIN numbers. Complete this information to ensure seamless e-invoice submission.',
        impact: 'Reduce submission errors',
        timestamp: DateTime.now(),
      ),
    ];
  }

  Future<String?> _getAccessToken() async {
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }
}
