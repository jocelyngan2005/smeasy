import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Vertex AI Search integration for enterprise-grade semantic search
/// Provides grounded answers from LHDN compliance documents
class VertexAISearchService {
  final String? _projectId;
  final String? _location;
  final String? _dataStoreId;
  final String? _apiKey;

  VertexAISearchService()
      : _projectId = dotenv.env['VERTEX_PROJECT_ID'],
        _location = dotenv.env['VERTEX_LOCATION'] ?? 'global',
        _dataStoreId = dotenv.env['VERTEX_DATASTORE_ID'],
        _apiKey = dotenv.env['VERTEX_API_KEY'];

  /// Search LHDN compliance documents using Vertex AI Search
  Future<VertexSearchResult> search({
    required String query,
    int pageSize = 5,
    bool useSummary = true,
  }) async {
    // Validate configuration
    final projectId = _projectId;
    final dataStoreId = _dataStoreId;
    final apiKey = _apiKey;
    
    if (projectId == null || projectId.isEmpty) {
      throw Exception('VERTEX_PROJECT_ID not found in .env file');
    }
    if (dataStoreId == null || dataStoreId.isEmpty) {
      throw Exception('VERTEX_DATASTORE_ID not found in .env file');
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('VERTEX_API_KEY not found in .env file');
    }

    // Build API endpoint
    final endpoint = Uri.parse(
      'https://$_location-discoveryengine.googleapis.com/v1/'
      'projects/$projectId/locations/$_location/collections/default_collection/'
      'dataStores/$dataStoreId/servingConfigs/default_search:search',
    );

    // Build request body
    final requestBody = {
      'query': query,
      'pageSize': pageSize,
      'queryExpansionSpec': {
        'condition': 'AUTO', // Automatic query expansion
      },
      'spellCorrectionSpec': {
        'mode': 'AUTO', // Automatic spell correction
      },
      if (useSummary)
        'contentSearchSpec': {
          'summarySpec': {
            'summaryResultCount': 3,
            'includeCitations': true,
            'ignoreAdversarialQuery': true,
            'ignoreNonSummarySeekingQuery': false,
            'modelPromptSpec': {
              'preamble': 'You are a Malaysian e-invoicing compliance expert. '
                  'Answer the question based only on the provided LHDN documents. '
                  'Be specific and cite relevant sections. '
                  'If information is not in the documents, say so clearly.',
            },
            'modelSpec': {
              'version': 'stable', // Use stable model
            },
          },
          'extractiveContentSpec': {
            'maxExtractiveAnswerCount': 3,
            'maxExtractiveSegmentCount': 3,
          },
        },
    };

    try {
      // Make API request
      final response = await http.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VertexSearchResult.fromJson(data);
      } else {
        final errorBody = response.body;
        throw Exception(
          'Vertex AI Search API error (${response.statusCode}): $errorBody',
        );
      }
    } catch (e) {
      throw Exception('Failed to search Vertex AI: $e');
    }
  }

  /// Check if Vertex AI Search is configured
  bool get isConfigured {
    final projectId = _projectId;
    final dataStoreId = _dataStoreId;
    final apiKey = _apiKey;
    
    return projectId != null && projectId.isNotEmpty &&
        dataStoreId != null && dataStoreId.isNotEmpty &&
        apiKey != null && apiKey.isNotEmpty;
  }

  /// Get configuration status message
  String get configurationStatus {
    if (isConfigured) {
      return 'Vertex AI Search is configured (Project: $_projectId, DataStore: $_dataStoreId)';
    } else {
      final missing = <String>[];
      final projectId = _projectId;
      final dataStoreId = _dataStoreId;
      final apiKey = _apiKey;
      
      if (projectId == null || projectId.isEmpty) missing.add('VERTEX_PROJECT_ID');
      if (dataStoreId == null || dataStoreId.isEmpty) missing.add('VERTEX_DATASTORE_ID');
      if (apiKey == null || apiKey.isEmpty) missing.add('VERTEX_API_KEY');
      return 'Vertex AI Search not configured. Missing: ${missing.join(", ")}';
    }
  }
}

/// Result from Vertex AI Search
class VertexSearchResult {
  final List<SearchResult> results;
  final String? summary;
  final List<Citation> citations;
  final int totalSize;

  VertexSearchResult({
    required this.results,
    this.summary,
    this.citations = const [],
    this.totalSize = 0,
  });

  factory VertexSearchResult.fromJson(Map<String, dynamic> json) {
    final results = <SearchResult>[];
    if (json['results'] != null) {
      for (var result in json['results'] as List) {
        results.add(SearchResult.fromJson(result as Map<String, dynamic>));
      }
    }

    String? summary;
    final citations = <Citation>[];

    if (json['summary'] != null) {
      final summaryData = json['summary'] as Map<String, dynamic>;
      summary = summaryData['summaryText'] as String?;

      if (summaryData['summaryWithMetadata'] != null) {
        final metadata = summaryData['summaryWithMetadata'] as Map<String, dynamic>;
        summary = metadata['summary'] as String?;

        if (metadata['citations'] != null) {
          for (var citation in metadata['citations'] as List) {
            citations.add(Citation.fromJson(citation as Map<String, dynamic>));
          }
        }
      }
    }

    return VertexSearchResult(
      results: results,
      summary: summary,
      citations: citations,
      totalSize: json['totalSize'] as int? ?? results.length,
    );
  }
}

/// Individual search result
class SearchResult {
  final String id;
  final Map<String, dynamic> document;
  final String? title;
  final String? snippet;

  SearchResult({
    required this.id,
    required this.document,
    this.title,
    this.snippet,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final document = json['document'] as Map<String, dynamic>? ?? {};
    final structData = document['structData'] as Map<String, dynamic>? ?? {};

    return SearchResult(
      id: json['id'] as String? ?? '',
      document: document,
      title: structData['title'] as String?,
      snippet: structData['snippet'] as String? ?? 
               structData['extractiveSegments']?[0]?['content'] as String?,
    );
  }
}

/// Citation from search results
class Citation {
  final int startIndex;
  final int endIndex;
  final List<CitationSource> sources;

  Citation({
    required this.startIndex,
    required this.endIndex,
    required this.sources,
  });

  factory Citation.fromJson(Map<String, dynamic> json) {
    final sources = <CitationSource>[];
    if (json['sources'] != null) {
      for (var source in json['sources'] as List) {
        sources.add(CitationSource.fromJson(source as Map<String, dynamic>));
      }
    }

    return Citation(
      startIndex: json['startIndex'] as int? ?? 0,
      endIndex: json['endIndex'] as int? ?? 0,
      sources: sources,
    );
  }
}

/// Citation source reference
class CitationSource {
  final String referenceId;
  final String? title;

  CitationSource({
    required this.referenceId,
    this.title,
  });

  factory CitationSource.fromJson(Map<String, dynamic> json) {
    return CitationSource(
      referenceId: json['referenceId'] as String? ?? '',
      title: json['title'] as String?,
    );
  }
}
