import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Vertex AI Search integration for enterprise-grade semantic search
/// Provides grounded answers from LHDN compliance documents
/// 
/// **AUTHENTICATION**: Vertex AI Search requires OAuth2 access token.
/// Set VERTEX_ACCESS_TOKEN in .env file with a valid OAuth2 token.
/// See VERTEX_AI_SETUP.md for instructions on obtaining access tokens.
class VertexAISearchService {
  final String? _projectId;
  final String? _location;
  final String? _dataStoreId;
  final String? _accessToken;

  VertexAISearchService()
      : _projectId = dotenv.env['VERTEX_PROJECT_ID'],
        _location = dotenv.env['VERTEX_LOCATION'] ?? 'global',
        _dataStoreId = dotenv.env['VERTEX_DATASTORE_ID'],
        _accessToken = dotenv.env['VERTEX_ACCESS_TOKEN'];

  /// Search LHDN compliance documents using Vertex AI Search
  Future<VertexSearchResult> search({
    required String query,
    int pageSize = 5,
    bool useSummary = true,
  }) async {
    // Validate configuration
    final projectId = _projectId;
    final dataStoreId = _dataStoreId;
    final accessToken = _accessToken;
    
    if (projectId == null || projectId.isEmpty) {
      throw Exception('VERTEX_PROJECT_ID not found in .env file');
    }
    if (dataStoreId == null || dataStoreId.isEmpty) {
      throw Exception('VERTEX_DATASTORE_ID not found in .env file');
    }
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('VERTEX_ACCESS_TOKEN not found in .env file. See VERTEX_AI_SETUP.md for instructions.');
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
          // Note: extractiveContentSpec removed to support datastores with chunking config
        },
    };

    try {
      // Make API request with OAuth2 Bearer token
      final response = await http.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
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

  /// Check if Vertex AI Search is configured with OAuth2 access token
  bool get isConfigured {
    final projectId = _projectId;
    final dataStoreId = _dataStoreId;
    final accessToken = _accessToken;
    
    return projectId != null && projectId.isNotEmpty &&
        dataStoreId != null && dataStoreId.isNotEmpty &&
        accessToken != null && accessToken.isNotEmpty;
  }

  /// Get configuration status message
  String get configurationStatus {
    if (isConfigured) {
      return 'Vertex AI Search is configured (Project: $_projectId, DataStore: $_dataStoreId)';
    } else {
      final missing = <String>[];
      final projectId = _projectId;
      final dataStoreId = _dataStoreId;
      final accessToken = _accessToken;
      
      if (projectId == null || projectId.isEmpty) missing.add('VERTEX_PROJECT_ID');
      if (dataStoreId == null || dataStoreId.isEmpty) missing.add('VERTEX_DATASTORE_ID');
      if (accessToken == null || accessToken.isEmpty) missing.add('VERTEX_ACCESS_TOKEN');
      
      return 'Vertex AI Search not configured. Missing: ${missing.join(", ")}. '
             'See VERTEX_AI_SETUP.md for OAuth2 setup instructions.';
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
  final String? uri;

  SearchResult({
    required this.id,
    required this.document,
    this.title,
    this.snippet,
    this.uri,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final document = json['document'] as Map<String, dynamic>? ?? {};
    final structData = document['structData'] as Map<String, dynamic>? ?? {};
    final derivedStructData = document['derivedStructData'] as Map<String, dynamic>? ?? {};
    
    // Extract URI from various possible locations
    String? uri = structData['url'] as String? ?? 
                  structData['uri'] as String? ??
                  derivedStructData['link'] as String? ??
                  document['name'] as String?;
    
    // Convert gs:// to https:// if needed
    if (uri != null && uri.startsWith('gs://')) {
      uri = uri.replaceFirst('gs://', 'https://storage.googleapis.com/');
    }

    return SearchResult(
      id: json['id'] as String? ?? '',
      document: document,
      title: structData['title'] as String?,
      snippet: structData['snippet'] as String? ?? 
               structData['extractiveSegments']?[0]?['content'] as String?,
      uri: uri,
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
  final String? uri;

  CitationSource({
    required this.referenceId,
    this.title,
    this.uri,
  });

  factory CitationSource.fromJson(Map<String, dynamic> json) {
    // Extract URI from referenceId or separate uri field
    String? uri = json['uri'] as String?;
    final refId = json['referenceId'] as String? ?? '';
    
    // If referenceId looks like a GCS path, format it as a URL
    if (uri == null && refId.isNotEmpty) {
      uri = _convertGcsToHttps(refId);
    } else if (uri != null && uri.startsWith('gs://')) {
      uri = _convertGcsToHttps(uri);
    }
    
    return CitationSource(
      referenceId: refId,
      title: json['title'] as String?,
      uri: uri,
    );
  }
  
  /// Convert gs:// GCS path to https:// URL
  static String _convertGcsToHttps(String path) {
    if (path.startsWith('gs://')) {
      // Convert gs://bucket/path to https://storage.googleapis.com/bucket/path
      return path.replaceFirst('gs://', 'https://storage.googleapis.com/');
    }
    return path;
  }
}
