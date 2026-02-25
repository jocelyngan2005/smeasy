import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/invoice_draft.dart';
import '../models/invoice_model.dart';

/// Service for extracting invoice data from receipt images using Gemini Vision
class GeminiVisionReceiptService {
  final GenerativeModel _visionModel;
  final String _apiKey;
  final Uuid _uuid = const Uuid();

  GeminiVisionReceiptService()
      : _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '',
        _visionModel = GenerativeModel(
          model: 'gemini-2.5-flash-lite',
          apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
        ) {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
    print('DEBUG GeminiVision: Service initialized with model: gemini-1.5-flash');
  }

  /// Scan receipt image and extract invoice information
  Future<InvoiceDraft> scanReceipt({
    required File imageFile,
  }) async {
    print('DEBUG GeminiVision: ========== SCAN RECEIPT CALLED ==========');
    print('DEBUG GeminiVision: File path: ${imageFile.path}');
    
    try {
      // Check if file exists
      final exists = await imageFile.exists();
      print('DEBUG GeminiVision: File exists: $exists');
      
      if (!exists) {
        throw Exception('File does not exist: ${imageFile.path}');
      }
      
      // Read image bytes
      print('DEBUG GeminiVision: Reading file bytes...');
      final imageBytes = await imageFile.readAsBytes();
      print('DEBUG GeminiVision: File size: ${imageBytes.length} bytes');
      
      // Determine MIME type based on file extension
      final String mimeType = _getMimeTypeFromFile(imageFile);
      print('DEBUG GeminiVision: Detected MIME type: $mimeType');
      
      // Create image/document part for Gemini
      print('DEBUG GeminiVision: Creating DataPart with MIME type: $mimeType');
      final imagePart = DataPart(mimeType, imageBytes);
      
      // Build prompt for receipt extraction
      print('DEBUG GeminiVision: Building extraction prompt...');
      final prompt = _buildReceiptExtractionPrompt();
      print('DEBUG GeminiVision: Prompt length: ${prompt.length} chars');
      
      // Call Gemini Vision API
      print('DEBUG GeminiVision: Calling Gemini API...');
      final response = await _visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          imagePart,
        ])
      ]);

      print('DEBUG GeminiVision: Response received!');
      
      if (response.text == null || response.text!.isEmpty) {
        print('DEBUG GeminiVision: ERROR - Response is null or empty');
        throw Exception('No response from Gemini Vision');
      }

      print('DEBUG GeminiVision: Response length: ${response.text!.length} chars');
      print('DEBUG GeminiVision: First 500 chars: ${response.text!.substring(0, response.text!.length > 500 ? 500 : response.text!.length)}');
      
      // Parse response
      final jsonResponse = _extractJsonFromResponse(response.text!);
      print('DEBUG GeminiVision: Extracted JSON length: ${jsonResponse.length}');
      
      final parsedData = jsonDecode(jsonResponse);
      print('DEBUG GeminiVision: Parsed data keys: ${parsedData.keys.toList()}');
      
      if (parsedData['vendor'] != null) {
        print('DEBUG GeminiVision: Vendor data: ${parsedData['vendor']}');
      }
      if (parsedData['lineItems'] != null) {
        print('DEBUG GeminiVision: Line items count: ${(parsedData['lineItems'] as List).length}');
      }

      // Create invoice draft
      final draft = _createDraftFromReceiptData(parsedData);
      
      print('DEBUG GeminiVision: Successfully created draft!');
      return draft;
    } catch (e, stackTrace) {
      print('DEBUG GeminiVision: ========== ERROR ==========');
      print('DEBUG GeminiVision: Error: $e');
      print('DEBUG GeminiVision: Stack trace: $stackTrace');
      throw Exception('Failed to scan receipt: $e');
    }
  }

  /// Scan receipt from bytes (for web/mobile)
  Future<InvoiceDraft> scanReceiptFromBytes({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      // Create image part for Gemini
      final imagePart = DataPart(mimeType, imageBytes);
      
      // Build prompt for receipt extraction
      final prompt = _buildReceiptExtractionPrompt();
      
      // Call Gemini Vision API
      final response = await _visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          imagePart,
        ])
      ]);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('No response from Gemini Vision');
      }

      // Parse response
      final jsonResponse = _extractJsonFromResponse(response.text!);
      final parsedData = jsonDecode(jsonResponse);

      // Create invoice draft
      final draft = _createDraftFromReceiptData(parsedData);
      
      return draft;
    } catch (e) {
      throw Exception('Failed to scan receipt from bytes: $e');
    }
  }

  /// Build prompt for receipt extraction
  String _buildReceiptExtractionPrompt() {
    return '''
You are an AI assistant specialized in extracting invoice/receipt information for Malaysian businesses.

Analyze the receipt/invoice image or PDF document and extract all relevant information.

EXTRACTION REQUIREMENTS:
1. **Vendor Information**: Business name, TIN, SST number, address, phone, email
2. **Buyer Information**: Customer name, TIN (if present), address, contact
3. **Line Items**: Product/service descriptions, quantities, unit prices, tax rates
4. **Amounts**: Subtotal, tax amount, total amount
5. **Dates**: Invoice date, due date (if any)
6. **Invoice Number**: Any reference or invoice number
7. **Tax Information**: SST 6% or 10%, tax exempt items

MALAYSIAN SPECIFIC DETAILS:
- TIN format: Usually starts with C followed by 10 digits (e.g., C 1234567890)
- SST rates: 6% (standard), 10% (luxury/service), or exempt
- Currency: MYR (Malaysian Ringgit)
- Common tax terms: SST, Sales Tax, Service Tax
- Look for: "SST Reg No:", "Company No:", "TIN:"

HANDLING HANDWRITTEN RECEIPTS:
- Do your best to read handwritten text
- Mark uncertain values with lower confidence
- Extract phone numbers even if formatted differently

Return ONLY valid JSON in this structure:
{
  "vendor": {
    "name": "string or null",
    "tin": "string or null",
    "registrationNumber": "string or null",
    "identificationNumber": "string or null (MyKad/Passport if individual)",
    "contactNumber": "string or null (phone with country code)",
    "sstNumber": "string or null (use 'NA' if not registered)",
    "email": "string or null",
    "phone": "string or null",
    "address": {
      "line1": "string or null",
      "line2": "string or null",
      "city": "string or null",
      "state": "string or null",
      "postalCode": "string or null",
      "country": "MY"
    }
  },
  "buyer": {
    "name": "string or null",
    "tin": "string or null",
    "registrationNumber": "string or null",
    "identificationNumber": "string or null (MyKad/Passport/MyPR)",
    "contactNumber": "string or null (phone with country code)",
    "sstNumber": "string or null (use 'NA' if not registered)",
    "email": "string or null",
    "phone": "string or null",
    "address": {
      "line1": "string or null",
      "line2": "string or null",
      "city": "string or null",
      "state": "string or null",
      "postalCode": "string or null"
    }
  },
  "invoiceNumber": "string or null",
  "lineItems": [
    {
      "description": "string",
      "quantity": number,
      "unit": "pcs|kg|hours|etc",
      "unitPrice": number,
      "taxRate": number or null,
      "taxType": "none|sst_6|sst_10|exempt"
    }
  ],
  "subtotal": number,
  "taxAmount": number,
  "totalAmount": number,
  "issueDate": "YYYY-MM-DD or null",
  "dueDate": "YYYY-MM-DD or null",
  "notes": "string or null",
  "confidence": 0.0 to 1.0,
  "ocrQuality": "excellent|good|fair|poor",
  "extractedText": "raw text extracted"
}

Do not include markdown formatting or explanations. Return only the JSON object.
''';
  }

  /// Extract JSON from Gemini response
  String _extractJsonFromResponse(String response) {
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

  /// Create InvoiceDraft from receipt data
  InvoiceDraft _createDraftFromReceiptData(Map<String, dynamic> data) {
    // Parse vendor info
    final vendorData = data['vendor'] as Map<String, dynamic>?;
    PartyInfoDraft? vendor;
    if (vendorData != null) {
      final addressData = vendorData['address'] as Map<String, dynamic>?;
      vendor = PartyInfoDraft(
        name: vendorData['name'] as String?,
        tin: vendorData['tin'] as String?,
        registrationNumber: vendorData['registrationNumber'] as String?,
        identificationNumber: vendorData['identificationNumber'] as String?,
        contactNumber: vendorData['contactNumber'] as String? ?? vendorData['phone'] as String?,
        sstNumber: vendorData['sstNumber'] as String?,
        email: vendorData['email'] as String?,
        phone: vendorData['phone'] as String?,
        address: addressData != null
            ? AddressDraft(
                line1: addressData['line1'] as String?,
                line2: addressData['line2'] as String?,
                line3: addressData['line3'] as String?,
                city: addressData['city'] as String?,
                state: addressData['state'] as String?,
                postalCode: addressData['postalCode'] as String?,
                country: addressData['country'] as String? ?? 'MY',
              )
            : null,
      );
    }

    // Parse buyer info
    final buyerData = data['buyer'] as Map<String, dynamic>?;
    PartyInfoDraft? buyer;
    if (buyerData != null) {
      final addressData = buyerData['address'] as Map<String, dynamic>?;
      buyer = PartyInfoDraft(
        name: buyerData['name'] as String?,
        tin: buyerData['tin'] as String?,
        registrationNumber: buyerData['registrationNumber'] as String?,
        identificationNumber: buyerData['identificationNumber'] as String?,
        contactNumber: buyerData['contactNumber'] as String? ?? buyerData['phone'] as String?,
        sstNumber: buyerData['sstNumber'] as String?,
        email: buyerData['email'] as String?,
        phone: buyerData['phone'] as String?,
        address: addressData != null
            ? AddressDraft(
                line1: addressData['line1'] as String?,
                line2: addressData['line2'] as String?,
                city: addressData['city'] as String?,
                state: addressData['state'] as String?,
                postalCode: addressData['postalCode'] as String?,
                country: 'MY',
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

    // Get amounts from OCR or calculate
    double subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    double taxAmount = (data['taxAmount'] as num?)?.toDouble() ?? 0;
    double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;

    // If amounts not extracted, calculate from line items
    if (subtotal == 0 && lineItems.isNotEmpty) {
      for (final item in lineItems) {
        final lineSubtotal = item.quantity * item.unitPrice;
        subtotal += lineSubtotal;
        if (item.taxRate != null) {
          taxAmount += lineSubtotal * (item.taxRate! / 100);
        }
      }
      totalAmount = subtotal + taxAmount;
    }

    // Parse dates
    DateTime? issueDate;
    DateTime? dueDate;
    
    try {
      if (data['issueDate'] != null) {
        issueDate = DateTime.parse(data['issueDate'] as String);
      }
    } catch (e) {
      issueDate = DateTime.now();
    }

    try {
      if (data['dueDate'] != null) {
        dueDate = DateTime.parse(data['dueDate'] as String);
      }
    } catch (e) {
      // dueDate remains null
    }

    // Validate and identify missing fields
    final missingFields = <String>[];
    final warnings = <String>[];

    if (vendor == null || vendor.name == null) missingFields.add('vendor.name');
    if (buyer == null || buyer.name == null) warnings.add('buyer.name (optional for receipts)');
    if (lineItems.isEmpty) missingFields.add('lineItems');
    if (totalAmount == 0) warnings.add('totalAmount is 0');

    // OCR quality warnings
    final ocrQuality = data['ocrQuality'] as String? ?? 'unknown';
    if (ocrQuality == 'poor' || ocrQuality == 'fair') {
      warnings.add('OCR quality: $ocrQuality - please review extracted data');
    }

    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.6;
    if (confidence < 0.7) {
      warnings.add('Low confidence score: ${(confidence * 100).toStringAsFixed(0)}%');
    }

    return InvoiceDraft(
      invoiceNumber: data['invoiceNumber'] as String?,
      type: InvoiceType.invoice,
      issueDate: issueDate,
      dueDate: dueDate,
      vendor: vendor,
      buyer: buyer,
      lineItems: lineItems,
      subtotal: subtotal,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      originalInput: data['extractedText'] as String?,
      confidenceScore: confidence,
      extractedEntities: ['receipt_scan', ocrQuality],
      rawAIResponse: data,
      source: InvoiceSource.receiptScan,
      missingFields: missingFields,
      warnings: warnings,
      isReadyForFinalization: missingFields.isEmpty,
    );
  }

  /// Extract specific field from receipt (for follow-up queries)
  Future<Map<String, dynamic>> extractSpecificField({
    required File imageFile,
    required String fieldName,
  }) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      
      // Determine MIME type based on file extension
      final String mimeType = _getMimeTypeFromFile(imageFile);
      final imagePart = DataPart(mimeType, imageBytes);
      
      final prompt = '''
From the receipt/invoice image, extract only the following field: "$fieldName"

Return a JSON object with the field name and value:
{
  "field": "$fieldName",
  "value": "extracted value or null",
  "confidence": 0.0 to 1.0
}
''';

      final response = await _visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          imagePart,
        ])
      ]);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('No response from Gemini Vision');
      }

      final jsonResponse = _extractJsonFromResponse(response.text!);
      return jsonDecode(jsonResponse) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to extract field: $e');
    }
  }

  /// Determine MIME type from file extension
  String _getMimeTypeFromFile(File file) {
    final path = file.path.toLowerCase();
    
    if (path.endsWith('.pdf')) {
      return 'application/pdf';
    } else if (path.endsWith('.png')) {
      return 'image/png';
    } else if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (path.endsWith('.webp')) {
      return 'image/webp';
    } else if (path.endsWith('.heic') || path.endsWith('.heif')) {
      return 'image/heic';
    } else {
      // Default to JPEG for unknown image types
      return 'image/jpeg';
    }
  }
}
