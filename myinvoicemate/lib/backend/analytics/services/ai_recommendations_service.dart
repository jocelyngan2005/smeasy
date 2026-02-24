import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../firestore_collections.dart';
import '../models/analytics_model.dart';

/// AI-powered recommendations service using Vertex AI.
///
/// Generates intelligent business insights based on:
/// - Invoice patterns and trends
/// - Compliance risk analysis
/// - Revenue optimization opportunities
/// - Customer behavior predictions
class AIRecommendationsService {
  AIRecommendationsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  
  // Gemini AI API configuration
  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  // ---------------------------------------------------------------------------
  // AI Recommendations
  // ---------------------------------------------------------------------------

  /// Generate AI-powered recommendations based on user's business data.
  ///
  /// Uses Firebase Cloud Functions as a secure proxy for Vertex AI.
  Future<List<AIRecommendation>> generateRecommendations(String userId) async {
    try {
      print('🤖 Generating AI recommendations via Cloud Function...');
      
      // 1. Gather business context
      final context = await _buildBusinessContext(userId);
      
      // 2. Call Cloud Function with business context
      final result = await _callCloudFunction('generateAIRecommendations', {
        'businessContext': context,
      });
      
      if (result['success'] == true) {
        // 3. Parse and return recommendations
        final recommendations = (result['recommendations'] as List? ?? [])
            .map((r) => AIRecommendation.fromJson(Map<String, dynamic>.from(r)))
            .toList();
            
        print('✅ Generated ${recommendations.length} AI recommendations');
        return recommendations;
      } else {
        print('⚠️ Cloud Function returned error: ${result['error']}');
        return await _getGeminiRecommendations(userId);
      }
    } catch (e) {
      print('❌ Error generating AI recommendations: $e');
      // Fallback to direct Gemini AI
      return await _getGeminiRecommendations(userId);
    }
  }

  /// Get cached recommendations (faster, updated hourly).
  Future<List<AIRecommendation>> getCachedRecommendations(String userId) async {
    try {
      print('📱 Getting cached recommendations via Cloud Function...');
      
      final result = await _callCloudFunction('getCachedAIRecommendations', {});
      
      if (result['success'] == true) {
        final recommendations = (result['recommendations'] as List? ?? [])
            .map((r) => AIRecommendation.fromJson(Map<String, dynamic>.from(r)))
            .toList();
            
        print('📦 Retrieved ${recommendations.length} cached recommendations');
        return recommendations;
      } else {
        return await _getGeminiRecommendations();
      }
    } catch (e) {
      print('Error getting cached recommendations: $e');
      return await _getGeminiRecommendations();
    }
  }

  /// Analyze specific invoice for compliance and optimization suggestions.
  /// TODO: Implement Cloud Function for invoice analysis
  Future<InvoiceAnalysis> analyzeInvoice(String invoiceId) async {
    try {
      final invoiceDoc = await _db
          .collection(FirestoreCollections.invoices)
          .doc(invoiceId)
          .get();

      if (!invoiceDoc.exists) {
        return InvoiceAnalysis.empty();
      }

      // For now, return a basic analysis
      // TODO: Create a Cloud Function for detailed invoice analysis
      print('📄 Analyzing invoice: $invoiceId (basic analysis)');
      return InvoiceAnalysis.empty();
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
  // Cloud Functions Integration
  // ---------------------------------------------------------------------------

  /// Call Firebase Cloud Function securely
  Future<Map<String, dynamic>> _callCloudFunction(
    String functionName, 
    Map<String, dynamic> data,
  ) async {
    try {
      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call(data);
      
      return Map<String, dynamic>.from(result.data ?? {});
    } catch (e) {
      print('Cloud Function error: $e');
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
        return await _getGeminiRecommendations(userId);
      }

      final data = doc.data()!;
      final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();
      
      // Check if cache is stale (older than 1 hour)
      if (lastUpdated != null && 
          DateTime.now().difference(lastUpdated).inHours >= 1) {
        return await _getGeminiRecommendations(userId);
      }

      final recommendations = (data['recommendations'] as List?)
          ?.map((r) => AIRecommendation.fromJson(r))
          .toList() ?? [];

      return recommendations.isNotEmpty 
          ? recommendations 
          : await _getGeminiRecommendations(userId);
    } catch (e) {
      print('Error getting cached recommendations: $e');
      return await _getGeminiRecommendations(userId);
    }
  }

  // ---------------------------------------------------------------------------
  // Direct Gemini AI Integration (Fallback)
  // ---------------------------------------------------------------------------

  /// Generate recommendations using direct Gemini AI API call.
  /// This is used as a fallback when Cloud Functions are unavailable.
  Future<List<AIRecommendation>> _getGeminiRecommendations([String? userId]) async {
    try {
      print('🤖 Using direct Gemini AI fallback for recommendations...');
      
      // Build business context for AI
      String businessContext = 'No specific business data available';
      if (userId != null) {
        businessContext = await _buildBusinessContext(userId);
      }
      
      // Call Gemini AI directly
      final response = await _callGeminiAI(businessContext);
      
      if (response != null) {
        final recommendations = _parseGeminiRecommendations(response);
        print('✅ Generated ${recommendations.length} AI recommendations via Gemini');
        return recommendations;
      } else {
        return _getStaticFallbackRecommendations();
      }
    } catch (e) {
      print('❌ Error calling Gemini AI: $e');
      return _getStaticFallbackRecommendations();
    }
  }

  /// Call Gemini AI API directly
  Future<String?> _callGeminiAI(String businessContext) async {
    try {
      final response = await http.post(
        Uri.parse('$_geminiApiUrl?key=$_geminiApiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': _buildGeminiPrompt(businessContext),
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topP': 0.95,
            'topK': 64,
            'maxOutputTokens': 2048,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        print('Gemini API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error calling Gemini API: $e');
      return null;
    }
  }

  /// Build prompt for Gemini AI
  String _buildGeminiPrompt(String businessContext) {
    return '''
You are a business intelligence advisor for MyInvoisMate, specializing in Malaysian e-invoicing compliance and business optimization.

$businessContext

Generate 5-7 personalized, actionable business recommendations. Focus on:
1. MyInvois compliance risks and improvements
2. Revenue optimization opportunities
3. Customer retention strategies
4. Cash flow management
5. Operational efficiency

IMPORTANT: Format your response as a JSON array with this exact structure:
[
  {
    "category": "Compliance|Revenue|Customers|Operations|Tax",
    "priority": "High|Medium|Low",
    "title": "Brief actionable title",
    "description": "2-3 sentences explaining the insight and action",
    "impact": "Expected business benefit"
  }
]

Return only the JSON array, no additional text.''';
  }

  /// Parse Gemini AI response into recommendations
  List<AIRecommendation> _parseGeminiRecommendations(String response) {
    try {
      // Clean the response to extract JSON
      String jsonStr = response.trim();
      
      // Remove markdown code blocks if present
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      }
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      
      final List<dynamic> jsonData = jsonDecode(jsonStr.trim());
      
      return jsonData.map((item) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(item);
        return AIRecommendation(
          category: data['category'] ?? 'Operations',
          priority: data['priority'] ?? 'Medium',
          title: data['title'] ?? 'Business Improvement',
          description: data['description'] ?? 'Review your business operations.',
          impact: data['impact'] ?? 'Improve efficiency',
          timestamp: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('Error parsing Gemini response: $e');
      return _getStaticFallbackRecommendations();
    }
  }

  /// Final static fallback if all AI methods fail
  List<AIRecommendation> _getStaticFallbackRecommendations() {
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


}
