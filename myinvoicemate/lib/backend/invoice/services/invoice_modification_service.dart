import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/invoice_model.dart';

/// Service for modifying existing invoices using AI-powered natural language parsing
class InvoiceModificationService {
  late final GenerativeModel _model;

  InvoiceModificationService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        topK: 1,
        topP: 0.95,
        maxOutputTokens: 500,
      ),
    );
  }

  /// Parse a modification request and apply it to an invoice
  Future<InvoiceModificationResult> modifyInvoice({
    required Invoice invoice,
    required String modificationRequest,
  }) async {
    try {
      // Parse the modification request using AI
      final parsedRequest = await _parseModificationRequest(
        invoice: invoice,
        request: modificationRequest,
      );

      // Apply the modification
      final updatedInvoice = _applyModification(
        invoice: invoice,
        field: parsedRequest.field,
        value: parsedRequest.value,
      );

      return InvoiceModificationResult(
        success: true,
        updatedInvoice: updatedInvoice,
        field: parsedRequest.field,
        oldValue: _getFieldValue(invoice, parsedRequest.field),
        newValue: parsedRequest.value,
        confirmationMessage: parsedRequest.confirmation,
      );
    } catch (e) {
      return InvoiceModificationResult(
        success: false,
        updatedInvoice: invoice,
        errorMessage: e.toString(),
      );
    }
  }

  /// Parse modification request using AI
  Future<_ParsedModificationRequest> _parseModificationRequest({
    required Invoice invoice,
    required String request,
  }) async {
    final prompt = '''
You are an invoice field parser. Parse the user's modification request and extract the field to change and its new value.

Current invoice details:
- Buyer Name: ${invoice.buyer.name}
- Buyer TIN: ${invoice.buyer.tin ?? 'N/A'}
- Buyer Email: ${invoice.buyer.email ?? 'N/A'}
- Buyer Phone: ${invoice.buyer.contactNumber ?? 'N/A'}
- Seller Name: ${invoice.vendor.name}
- Seller TIN: ${invoice.vendor.tin ?? 'N/A'}
- Invoice Number: ${invoice.invoiceNumber}
- Subtotal: ${invoice.subtotal}
- Tax: ${invoice.taxAmount}
- Total: ${invoice.totalAmount}

User's modification request: "$request"

Respond ONLY with a JSON object in this exact format:
{
  "field": "buyer_name" or "buyer_tin" or "buyer_email" or "buyer_phone" or "seller_name" or "seller_tin" or "invoice_number" or "subtotal" or "tax" or "total" or "unknown",
  "value": "new value as string",
  "confirmation": "brief confirmation message"
}

Examples:
- "change buyer name to Jane Doe" → {"field": "buyer_name", "value": "Jane Doe", "confirmation": "Changed buyer name to Jane Doe"}
- "update buyer TIN to C12345678901" → {"field": "buyer_tin", "value": "C12345678901", "confirmation": "Updated buyer TIN to C12345678901"}
- "set tax to 50" → {"field": "tax", "value": "50", "confirmation": "Set tax amount to RM 50.00"}
''';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    final responseText = response.text?.trim() ?? '';

    print('DEBUG ModificationService: AI Response: $responseText');

    // Parse JSON response
    final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(responseText);
    if (jsonMatch == null) {
      throw Exception('Could not parse AI response');
    }

    final jsonStr = jsonMatch.group(0)!;

    // Extract fields using regex
    final fieldMatch = RegExp(r'"field"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
    final valueMatch = RegExp(r'"value"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
    final confirmMatch =
        RegExp(r'"confirmation"\s*:\s*"([^"]+)"').firstMatch(jsonStr);

    if (fieldMatch == null || valueMatch == null) {
      throw Exception('Could not extract field or value from AI response');
    }

    final field = fieldMatch.group(1)!;
    final value = valueMatch.group(1)!;
    final confirmation =
        confirmMatch?.group(1) ?? 'Updated $field to $value';

    print('DEBUG ModificationService: Parsed - Field: $field, Value: $value');

    if (field == 'unknown') {
      throw Exception(
          'Could not understand the modification request. Please be more specific.');
    }

    return _ParsedModificationRequest(
      field: field,
      value: value,
      confirmation: confirmation,
    );
  }

  /// Apply modification to invoice
  Invoice _applyModification({
    required Invoice invoice,
    required String field,
    required String value,
  }) {
    switch (field) {
      case 'buyer_name':
        return invoice.copyWith(
          buyer: invoice.buyer.copyWith(name: value),
        );

      case 'buyer_tin':
        return invoice.copyWith(
          buyer: invoice.buyer.copyWith(tin: value),
        );

      case 'buyer_email':
        return invoice.copyWith(
          buyer: invoice.buyer.copyWith(email: value),
        );

      case 'buyer_phone':
        return invoice.copyWith(
          buyer: invoice.buyer.copyWith(contactNumber: value),
        );

      case 'seller_name':
        return invoice.copyWith(
          vendor: invoice.vendor.copyWith(name: value),
        );

      case 'seller_tin':
        return invoice.copyWith(
          vendor: invoice.vendor.copyWith(tin: value),
        );

      case 'invoice_number':
        return invoice.copyWith(invoiceNumber: value);

      case 'subtotal':
        final numValue = double.tryParse(value) ?? invoice.subtotal;
        return invoice.copyWith(
          subtotal: numValue,
          totalAmount: numValue + invoice.taxAmount,
        );

      case 'tax':
        final numValue = double.tryParse(value) ?? invoice.taxAmount;
        return invoice.copyWith(
          taxAmount: numValue,
          totalAmount: invoice.subtotal + numValue,
        );

      case 'total':
        final numValue = double.tryParse(value) ?? invoice.totalAmount;
        return invoice.copyWith(totalAmount: numValue);

      default:
        throw Exception('Unknown field: $field');
    }
  }

  /// Get current value of a field from invoice
  String _getFieldValue(Invoice invoice, String field) {
    switch (field) {
      case 'buyer_name':
        return invoice.buyer.name;
      case 'buyer_tin':
        return invoice.buyer.tin ?? 'N/A';
      case 'buyer_email':
        return invoice.buyer.email ?? 'N/A';
      case 'buyer_phone':
        return invoice.buyer.contactNumber ?? 'N/A';
      case 'seller_name':
        return invoice.vendor.name;
      case 'seller_tin':
        return invoice.vendor.tin ?? 'N/A';
      case 'invoice_number':
        return invoice.invoiceNumber;
      case 'subtotal':
        return invoice.subtotal.toString();
      case 'tax':
        return invoice.taxAmount.toString();
      case 'total':
        return invoice.totalAmount.toString();
      default:
        return 'N/A';
    }
  }
}

/// Internal class for parsed modification request
class _ParsedModificationRequest {
  final String field;
  final String value;
  final String confirmation;

  _ParsedModificationRequest({
    required this.field,
    required this.value,
    required this.confirmation,
  });
}

/// Result of an invoice modification operation
class InvoiceModificationResult {
  final bool success;
  final Invoice updatedInvoice;
  final String? field;
  final String? oldValue;
  final String? newValue;
  final String? confirmationMessage;
  final String? errorMessage;

  InvoiceModificationResult({
    required this.success,
    required this.updatedInvoice,
    this.field,
    this.oldValue,
    this.newValue,
    this.confirmationMessage,
    this.errorMessage,
  });
}
