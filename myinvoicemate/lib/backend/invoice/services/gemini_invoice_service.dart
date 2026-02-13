import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice_draft.dart';
import '../models/invoice_model.dart';

/// Service for generating invoices from voice/text input using Gemini AI
class GeminiInvoiceService {
  final GenerativeModel _model;
  final String _apiKey;
  final Uuid _uuid = const Uuid();

  GeminiInvoiceService({required String apiKey})
      : _apiKey = apiKey,
        _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
        );

  /// Generate invoice draft from voice/text input
  /// 
  /// Example input: "Create invoice for ABC Company, 3 laptops at RM3500 each, 
  /// delivered to 123 Jalan Bukit Bintang KL"
  Future<InvoiceDraft> generateInvoiceFromText({
    required String input,
    String? vendorContext, // Pre-filled vendor info if available
  }) async {
    try {
      // Construct detailed prompt for Gemini
      final prompt = _buildInvoiceGenerationPrompt(input, vendorContext);

      // Call Gemini API
      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('No response from Gemini AI');
      }

      // Parse the JSON response
      final jsonResponse = _extractJsonFromResponse(response.text!);
      final parsedData = jsonDecode(jsonResponse);

      // Create invoice draft
      final draft = _createDraftFromAIResponse(
        parsedData,
        input,
        InvoiceSource.voice,
      );

      return draft;
    } catch (e) {
      throw Exception('Failed to generate invoice from text: $e');
    }
  }

  /// Build the prompt for Gemini to extract invoice information
  String _buildInvoiceGenerationPrompt(String input, String? vendorContext) {
    return '''
You are an AI assistant specialized in Malaysian e-invoice generation for LHDN MyInvois compliance.

Extract invoice information from the following input and return a structured JSON response.

INPUT: "$input"

${vendorContext != null ? 'VENDOR CONTEXT: $vendorContext\n' : ''}

INSTRUCTIONS:
1. Extract all invoice-related information from the input
2. For Malaysian businesses, identify TIN (Tax Identification Number) if mentioned
3. Infer SST (6% or 10%) if applicable to the product/service
4. Use MYR as currency
5. Generate line items with descriptions, quantities, and prices
6. Calculate subtotals and tax amounts
7. Identify buyer information (company name, address, contact)
8. Mark fields as null if not mentioned in input

IMPORTANT MALAYSIAN CONTEXT:
- Standard SST rates: 6% (most goods) or 10% (luxury/service)
- Currency: MYR (Malaysian Ringgit)
- TIN format: C 1234567890 (for companies)
- Common states: Kuala Lumpur, Selangor, Penang, Johor, etc.

Return ONLY valid JSON in this exact structure:
{
  "buyer": {
    "name": "string or null",
    "tin": "string or null",
    "email": "string or null",
    "phone": "string or null",
    "address": {
      "line1": "string or null",
      "city": "string or null",
      "state": "string or null",
      "postalCode": "string or null",
      "country": "MY"
    }
  },
  "lineItems": [
    {
      "description": "string",
      "quantity": number,
      "unit": "pcs|kg|hours|etc",
      "unitPrice": number,
      "taxRate": 6 or 10 or null,
      "taxType": "none|sst_6|sst_10|exempt"
    }
  ],
  "issueDate": "ISO date string or null",
  "dueDate": "ISO date string or null",
  "notes": "string or null",
  "extractedEntities": ["entity1", "entity2"],
  "confidence": 0.0 to 1.0
}

Do not include any markdown formatting, code blocks, or explanations. Return only the JSON object.
''';
  }

  /// Extract JSON from Gemini response (handles markdown code blocks)
  String _extractJsonFromResponse(String response) {
    // Remove markdown code blocks if present
    String cleaned = response.trim();
    
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    
    return cleaned.trim();
  }

  /// Create InvoiceDraft from AI response
  InvoiceDraft _createDraftFromAIResponse(
    Map<String, dynamic> data,
    String originalInput,
    InvoiceSource source,
  ) {
    // Parse buyer info
    final buyerData = data['buyer'] as Map<String, dynamic>?;
    PartyInfoDraft? buyer;
    if (buyerData != null) {
      final addressData = buyerData['address'] as Map<String, dynamic>?;
      buyer = PartyInfoDraft(
        name: buyerData['name'] as String?,
        tin: buyerData['tin'] as String?,
        email: buyerData['email'] as String?,
        phone: buyerData['phone'] as String?,
        address: addressData != null
            ? AddressDraft(
                line1: addressData['line1'] as String?,
                line2: addressData['line2'] as String?,
                city: addressData['city'] as String?,
                state: addressData['state'] as String?,
                postalCode: addressData['postalCode'] as String?,
                country: addressData['country'] as String? ?? 'MY',
              )
            : null,
      );
    }

    // Parse line items
    final lineItemsData = data['lineItems'] as List<dynamic>? ?? [];
    final lineItems = lineItemsData.map((item) {
      final itemMap = item as Map<String, dynamic>;
      final taxRate = itemMap['taxRate'] as num?;
      final taxTypeStr = itemMap['taxType'] as String? ?? 'none';
      
      TaxType taxType = TaxType.none;
      if (taxTypeStr == 'sst_6') taxType = TaxType.sst6;
      else if (taxTypeStr == 'sst_10') taxType = TaxType.sst10;
      else if (taxTypeStr == 'exempt') taxType = TaxType.exempt;
      
      return InvoiceLineItemDraft(
        id: _uuid.v4(),
        description: itemMap['description'] as String,
        quantity: (itemMap['quantity'] as num).toDouble(),
        unit: itemMap['unit'] as String? ?? 'pcs',
        unitPrice: (itemMap['unitPrice'] as num).toDouble(),
        taxRate: taxRate?.toDouble(),
        taxType: taxType,
      );
    }).toList();

    // Calculate totals
    double subtotal = 0;
    double taxAmount = 0;
    for (final item in lineItems) {
      final lineSubtotal = item.quantity * item.unitPrice;
      subtotal += lineSubtotal;
      if (item.taxRate != null) {
        taxAmount += lineSubtotal * (item.taxRate! / 100);
      }
    }
    final total = subtotal + taxAmount;

    // Validate and identify missing fields
    final missingFields = <String>[];
    final warnings = <String>[];

    if (buyer == null || buyer.name == null) missingFields.add('buyer.name');
    if (buyer?.address == null || buyer!.address!.line1 == null) {
      missingFields.add('buyer.address');
    }
    if (lineItems.isEmpty) missingFields.add('lineItems');

    // Check if ready for finalization
    final isReady = missingFields.isEmpty;

    return InvoiceDraft(
      type: InvoiceType.invoice,
      issueDate: data['issueDate'] != null 
          ? DateTime.parse(data['issueDate'] as String) 
          : DateTime.now(),
      dueDate: data['dueDate'] != null 
          ? DateTime.parse(data['dueDate'] as String) 
          : null,
      buyer: buyer,
      lineItems: lineItems,
      subtotal: subtotal,
      taxAmount: taxAmount,
      totalAmount: total,
      originalInput: originalInput,
      confidenceScore: (data['confidence'] as num?)?.toDouble() ?? 0.7,
      extractedEntities: (data['extractedEntities'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      rawAIResponse: data,
      source: source,
      missingFields: missingFields,
      warnings: warnings,
      isReadyForFinalization: isReady,
    );
  }

  /// Refine draft with additional information
  Future<InvoiceDraft> refineInvoiceDraft({
    required InvoiceDraft draft,
    required String additionalInput,
  }) async {
    try {
      final prompt = _buildRefinementPrompt(draft, additionalInput);
      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('No response from Gemini AI');
      }

      final jsonResponse = _extractJsonFromResponse(response.text!);
      final parsedData = jsonDecode(jsonResponse);

      // Merge with existing draft
      return _mergeDrafts(draft, parsedData);
    } catch (e) {
      throw Exception('Failed to refine invoice draft: $e');
    }
  }

  String _buildRefinementPrompt(InvoiceDraft draft, String additionalInput) {
    return '''
You are refining an existing invoice draft with new information.

EXISTING DRAFT:
${jsonEncode(draft.toJson())}

NEW INFORMATION:
"$additionalInput"

MISSING FIELDS:
${draft.missingFields.join(", ")}

Update the draft with the new information. Return the complete updated JSON in the same structure as before.
Focus on filling in the missing fields if the new information provides them.

Return ONLY valid JSON without markdown formatting.
''';
  }

  InvoiceDraft _mergeDrafts(InvoiceDraft existing, Map<String, dynamic> updates) {
    // Implementation of merging logic
    // This is a simplified version - you'd want more sophisticated merging
    final updatedDraft = _createDraftFromAIResponse(
      updates,
      existing.originalInput ?? '',
      existing.source,
    );

    return updatedDraft;
  }
}
