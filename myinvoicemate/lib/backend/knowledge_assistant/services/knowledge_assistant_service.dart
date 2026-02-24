import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import '../../firestore_collections.dart';
import '../models/compliance_question.dart';
import '../compliance_documents.dart';
import 'vertex_ai_search_service.dart';

/// AI-powered Knowledge Assistant for LHDN Compliance
/// Uses Vertex AI Search (preferred) or Gemini AI with RAG (fallback).
/// Answered questions are persisted to /compliance_questions/{questionId}.
class KnowledgeAssistantService {
  late final GenerativeModel _model;
  late final VertexAISearchService _vertexSearch;
  final Uuid _uuid = const Uuid();
  final FirebaseFirestore _db;

  KnowledgeAssistantService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance {
    // Initialize Vertex AI Search
    _vertexSearch = VertexAISearchService();

    // Initialize Gemini (fallback)
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY not found in .env file. '
        'Please add your API key to use the Knowledge Assistant.',
      );
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3, // Lower temperature for more factual responses
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
  }

  /// Ask a compliance question - uses Vertex AI Search if configured, otherwise RAG.
  ///
  /// When [userId] is provided, the question and answer are persisted to
  /// /compliance_questions/{questionId} for later history retrieval.
  Future<ComplianceQuestion> askQuestion(String question,
      {String? userId}) async {
    ComplianceQuestion result;

    // Try Vertex AI Search first (enterprise-grade)
    if (_vertexSearch.isConfigured) {
      try {
        result = await _askQuestionWithVertexAI(question);
      } catch (e) {
        // ignore: avoid_print
        print('Vertex AI Search failed, falling back to RAG: $e');
        result = await _askQuestionWithRAG(question);
      }
    } else {
      result = await _askQuestionWithRAG(question);
    }

    // Persist to Firestore when we have a userId
    if (userId != null && userId.isNotEmpty) {
      await _saveQuestion(result, userId);
    }

    return result;
  }

  /// Retrieve the chat history for [userId], newest first.
  Future<List<ComplianceQuestion>> getQuestionHistory(String userId,
      {int limit = 50}) async {
    final snap = await _db
        .collection(FirestoreCollections.complianceQuestions)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final raw = d.data();
      final ts = raw['timestamp'];
      raw['timestamp'] = ts is Timestamp
          ? ts.toDate().toIso8601String()
          : DateTime.now().toIso8601String();
      raw['id'] = d.id;
      return ComplianceQuestion.fromJson(raw);
    }).toList();
  }

  /// Extract filename from URI for display
  String _extractFilenameFromUri(String uri) {
    try {
      // Remove query parameters and fragments
      final cleanUri = uri.split('?').first.split('#').first;
      // Get last path segment
      final segments = cleanUri.split('/');
      final filename = segments.last;
      // Remove file extension and decode percent encoding
      return Uri.decodeComponent(filename.replaceAll(RegExp(r'\.[^.]+$'), ''));
    } catch (e) {
      return 'LHDN Document';
    }
  }

  /// Persist a [ComplianceQuestion] to /compliance_questions.
  Future<void> _saveQuestion(
      ComplianceQuestion q, String userId) async {
    try {
      final doc = _db.collection(FirestoreCollections.complianceQuestions).doc();
      await doc.set({
        'userId': userId,
        'question': q.question,
        'answer': q.answer,
        'sources': q.sources,
        'relatedTopics': q.relatedTopics,
        'confidenceScore': q.confidenceScore,
        'category': q.category,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-fatal — question was answered successfully; just log.
      // ignore: avoid_print
      print('Warning: could not persist compliance question: $e');
    }
  }

  /// Ask question using Vertex AI Search (preferred method)
  Future<ComplianceQuestion> _askQuestionWithVertexAI(String question) async {
    try {
      // Search compliance documents
      final searchResult = await _vertexSearch.search(
        query: question,
        pageSize: 5,
        useSummary: true,
      );

      // Extract answer from summary or results
      String answer = searchResult.summary ?? 
          'No specific answer found in compliance documents.';

      // Extract sources from citations with URIs
      final sources = <String>[];
      final seenUris = <String>{};
      
      print('DEBUG: Processing ${searchResult.citations.length} citations');
      
      for (final citation in searchResult.citations) {
        for (final source in citation.sources) {
          final uri = source.uri ?? source.referenceId;
          print('DEBUG: Citation source - URI: $uri, Title: ${source.title}');
          
          if (uri.isNotEmpty && !seenUris.contains(uri)) {
            seenUris.add(uri);
            
            // Convert gs:// to https:// if needed
            final webUri = uri.startsWith('gs://') 
                ? uri.replaceFirst('gs://', 'https://storage.googleapis.com/')
                : uri;
            
            // Format source with URI if available (only use web-accessible URLs)
            final title = source.title ?? _extractFilenameFromUri(uri);
            final formattedSource = webUri.startsWith('http') 
                ? '[$title]($webUri)' 
                : title;
            sources.add(formattedSource);
            print('DEBUG: Added source: $formattedSource');
          }
        }
      }
      
      // Also add sources from search results if citations are empty
      if (sources.isEmpty) {
        print('DEBUG: No citation sources, trying ${searchResult.results.length} search results');
        for (final result in searchResult.results) {
          print('DEBUG: Search result - URI: ${result.uri}, Title: ${result.title}');
          if (result.uri != null && result.uri!.isNotEmpty && !seenUris.contains(result.uri!)) {
            seenUris.add(result.uri!);
            
            // Convert gs:// to https:// if needed
            final webUri = result.uri!.startsWith('gs://') 
                ? result.uri!.replaceFirst('gs://', 'https://storage.googleapis.com/')
                : result.uri!;
            
            final title = result.title ?? _extractFilenameFromUri(result.uri!);
            final formattedSource = webUri.startsWith('http') 
                ? '[$title]($webUri)' 
                : title;
            sources.add(formattedSource);
            print('DEBUG: Added source from result: $formattedSource');
          }
        }
      }

      // Add fallback sources if none found
      if (sources.isEmpty) {
        sources.addAll(['LHDN MyInvois Guidelines 2026 (no direct link available)']);
      }

      // Determine category
      final category = _categorizeQuestion(question);

      // Extract related topics from search results
      final relatedTopics = searchResult.results
          .map((result) => result.title)
          .where((title) => title != null && title.isNotEmpty)
          .take(3)
          .cast<String>()
          .toList();

      // Calculate confidence based on search quality
      double confidence = 0.5; // Base confidence
      
      // Boost confidence based on summary quality
      if (searchResult.summary != null) {
        if (searchResult.summary!.length > 200) {
          confidence += 0.25;
        } else if (searchResult.summary!.length > 100) {
          confidence += 0.15;
        } else {
          confidence += 0.08;
        }
      }
      
      // Boost confidence based on number of citations
      final citationCount = searchResult.citations.length;
      if (citationCount >= 3) {
        confidence += 0.15;
      } else if (citationCount >= 2) {
        confidence += 0.10;
      } else if (citationCount >= 1) {
        confidence += 0.05;
      }
      
      // Boost confidence based on number of search results
      final resultCount = searchResult.results.length;
      if (resultCount >= 5) {
        confidence += 0.10;
      } else if (resultCount >= 3) {
        confidence += 0.05;
      }
      
      // Slight boost if sources have URIs (grounded in actual documents)
      final hasUris = searchResult.citations
          .any((c) => c.sources.any((s) => s.uri != null && s.uri!.isNotEmpty));
      if (hasUris) {
        confidence += 0.05;
      }

      return ComplianceQuestion(
        id: _uuid.v4(),
        question: question,
        answer: answer,
        sources: sources,
        relatedTopics: relatedTopics,
        confidenceScore: confidence.clamp(0.5, 1.0),
        timestamp: DateTime.now(),
        category: category,
      );
    } catch (e) {
      throw Exception('Vertex AI Search error: $e');
    }
  }

  /// Ask question using RAG approach (fallback method)
  Future<ComplianceQuestion> _askQuestionWithRAG(String question) async {
    try {
      // Get compliance context from document store
      final complianceContext = LHDNComplianceDocuments.getComplianceContext();

      // Build RAG prompt
      final prompt = _buildRAGPrompt(question, complianceContext);

      // Get response from Gemini
      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('No response from AI model');
      }

      // Parse the response
      final answer = response.text!;
      
      // Extract sources from the answer (sources are mentioned in the context)
      final sources = _extractSources(answer);
      
      // Determine category based on question content
      final category = _categorizeQuestion(question);
      
      // Extract related topics
      final relatedTopics = _extractRelatedTopics(question, answer);
      
      // Calculate confidence based on response quality
      final confidence = _calculateConfidence(answer);

      return ComplianceQuestion(
        id: _uuid.v4(),
        question: question,
        answer: answer,
        sources: sources,
        relatedTopics: relatedTopics,
        confidenceScore: confidence,
        timestamp: DateTime.now(),
        category: category,
      );
    } catch (e) {
      // Fallback to quick FAQ if AI fails
      final faq = _findClosestFAQ(question);
      if (faq != null) {
        return ComplianceQuestion(
          id: _uuid.v4(),
          question: question,
          answer: faq['answer']!,
          sources: ['LHDN MyInvois Guidelines 2026'],
          relatedTopics: [],
          confidenceScore: 0.7,
          timestamp: DateTime.now(),
          category: faq['category']!,
        );
      }
      
      throw Exception('Failed to get answer: $e');
    }
  }

  /// Get contextual help for specific topics
  Future<String> getContextualHelp(String topic) async {
    final question = 'Explain $topic in the context of Malaysian e-invoicing';
    final result = await askQuestion(question);
    return result.answer;
  }

  /// Get FAQ list
  Future<List<Map<String, String>>> getFAQ() async {
    return LHDNComplianceDocuments.getQuickFAQs();
  }

  /// Get compliance guidelines
  Future<List<String>> getGuidelines() async {
    return LHDNComplianceDocuments.getComplianceTips();
  }

  /// Get compliance insights based on user's invoice data
  Future<List<ComplianceInsight>> getPersonalizedInsights({
    required double monthlyRevenue,
    required int invoiceCount,
    required int pendingSubmissions,
  }) async {
    final insights = <ComplianceInsight>[];

    // Check if approaching RM10k threshold
    if (monthlyRevenue >= 8000 && monthlyRevenue < 10000) {
      insights.add(ComplianceInsight(
        title: 'Approaching RM10K Threshold',
        description: 'Your monthly revenue is near RM10,000. Prepare for mandatory MyInvois submission.',
        category: 'E-Invoicing',
        priority: CompliancePriority.high,
      ));
    }

    // Check pending submissions
    if (pendingSubmissions > 5) {
      insights.add(ComplianceInsight(
        title: 'Pending Submissions',
        description: 'You have $pendingSubmissions invoices pending submission. Submit within 72 hours.',
        category: 'Deadlines',
        priority: CompliancePriority.critical,
        deadline: DateTime.now().add(const Duration(hours: 72)),
      ));
    }

    // Relaxation period reminder
    if (DateTime.now().year <= 2027) {
      insights.add(ComplianceInsight(
        title: 'Relaxation Period Active',
        description: 'Take advantage of monthly consolidation for invoices under RM10K until Dec 2027.',
        category: 'E-Invoicing',
        priority: CompliancePriority.medium,
      ));
    }

    return insights;
  }

  /// Get official document sources
  List<String> getOfficialSources() {
    return LHDNComplianceDocuments.getOfficialSources();
  }

  /// Check if Vertex AI Search is being used
  bool get isUsingVertexAI => _vertexSearch.isConfigured;

  /// Get current search method
  String get searchMethod => _vertexSearch.isConfigured 
      ? 'Vertex AI Search (Enterprise)'
      : 'Gemini RAG (Fallback)';

  /// Get configuration status
  String get configurationStatus => _vertexSearch.configurationStatus;

  // ==================== PRIVATE HELPER METHODS ====================

  /// Build RAG (Retrieval Augmented Generation) prompt
  String _buildRAGPrompt(String question, String context) {
    return '''You are a Malaysian e-invoicing compliance expert specializing in LHDN MyInvois guidelines. 

CONTEXT (Official LHDN Documentation):
$context

USER QUESTION: $question

INSTRUCTIONS:
1. Answer the question based ONLY on the provided LHDN documentation context
2. Be specific and cite relevant sections/rules
3. Use clear, professional language suitable for SME business owners
4. If the question is about dates/deadlines, provide exact dates when available
5. If the question requires clarification, ask for more details
6. Format your answer in clear paragraphs with bullet points where appropriate
7. End with relevant source references from the context
8. If the question cannot be answered from the context, say "I don't have specific information about this in the current guidelines. Please contact LHDN at 1-800-88-4567 for clarification."

ANSWER:''';
  }

  /// Extract sources mentioned in the answer
  List<String> _extractSources(String answer) {
    final sources = <String>[];
    final officialSources = LHDNComplianceDocuments.getOfficialSources();
    
    for (final source in officialSources) {
      if (answer.toLowerCase().contains(source.toLowerCase().substring(0, 20))) {
        sources.add(source);
      }
    }
    
    // Default sources if none found
    if (sources.isEmpty) {
      sources.addAll([
        'LHDN MyInvois Guidelines 2026',
        'LHDN Technical Specifications',
      ]);
    }
    
    return sources.take(3).toList();
  }

  /// Categorize question based on keywords
  String _categorizeQuestion(String question) {
    final lower = question.toLowerCase();
    
    if (lower.contains('rm10') || lower.contains('10000') || lower.contains('threshold')) {
      return 'E-Invoicing';
    } else if (lower.contains('tin') || lower.contains('sst') || lower.contains('tax')) {
      return 'Taxation';
    } else if (lower.contains('deadline') || lower.contains('submit') || lower.contains('when')) {
      return 'Deadlines';
    } else if (lower.contains('penalty') || lower.contains('fine') || lower.contains('punishment')) {
      return 'Penalties';
    } else if (lower.contains('exempt') || lower.contains('exception') || lower.contains('not required')) {
      return 'Exemptions';
    } else if (lower.contains('api') || lower.contains('format') || lower.contains('technical')) {
      return 'Technical';
    } else if (lower.contains('consolidat') || lower.contains('relaxation')) {
      return 'E-Invoicing';
    }
    
    return 'General';
  }

  /// Extract related topics from question and answer
  List<String> _extractRelatedTopics(String question, String answer) {
    final topics = <String>[];
    final combined = '$question $answer'.toLowerCase();
    
    final topicKeywords = {
      'E-Invoicing': ['invoice', 'myinvois', 'submission'],
      'TIN Requirements': ['tin', 'tax identification'],
      'SST': ['sst', 'sales tax', 'service tax'],
      'Penalties': ['penalty', 'fine', 'compliance'],
      'Relaxation Period': ['relaxation', 'consolidat'],
      'Credit Notes': ['credit note', 'debit note', 'adjustment'],
      'Record Keeping': ['record', 'retention', '7 years'],
    };
    
    for (final entry in topicKeywords.entries) {
      for (final keyword in entry.value) {
        if (combined.contains(keyword)) {
          topics.add(entry.key);
          break;
        }
      }
    }
    
    return topics.take(3).toList();
  }

  /// Calculate confidence score based on response quality
  double _calculateConfidence(String answer) {
    double confidence = 0.7; // Base confidence
    
    // Increase confidence if answer contains specific references
    if (answer.contains('LHDN') || answer.contains('Source:')) {
      confidence += 0.15;
    }
    
    // Increase confidence if answer has structured content
    if (answer.contains('•') || answer.contains('-') || answer.contains('\n')) {
      confidence += 0.1;
    }
    
    // Decrease confidence if answer is too short or generic
    if (answer.length < 100) {
      confidence -= 0.2;
    }
    
    return confidence.clamp(0.5, 1.0);
  }

  /// Find closest FAQ match for fallback
  Map<String, String>? _findClosestFAQ(String question) {
    final lower = question.toLowerCase();
    final faqs = LHDNComplianceDocuments.getQuickFAQs();
    
    for (final faq in faqs) {
      final faqQuestion = faq['question']!.toLowerCase();
      // Simple word matching
      final words = lower.split(' ');
      int matches = 0;
      for (final word in words) {
        if (word.length > 3 && faqQuestion.contains(word)) {
          matches++;
        }
      }
      if (matches >= 2) {
        return faq;
      }
    }
    
    return null;
  }
}
