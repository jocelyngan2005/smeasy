import '../models/invoice_model.dart';

class GeminiService {
  // Mock Voice-to-Invoice conversion
  Future<InvoiceModel> generateInvoiceFromVoice(String transcription) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate AI processing

    // Mock parsing of voice input
    // In real implementation, this would use Gemini AI to extract structured data
    return InvoiceModel(
      id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
      invoiceNumber: 'DRAFT-${DateTime.now().millisecondsSinceEpoch}',
      sellerId: 'user123',
      sellerName: 'SME Trading Sdn Bhd',
      sellerTin: 'C12345678900',
      buyerId: '',
      buyerName: 'Customer Name', // Extracted from voice
      buyerTin: '',
      buyerAddress: '',
      issueDate: DateTime.now(),
      lineItems: [
        InvoiceLineItem(
          description: 'Product/Service', // Extracted from voice
          quantity: 1,
          unitPrice: 1000.00, // Extracted from voice
          taxRate: 0.0,
          amount: 1000.00,
        ),
      ],
      subtotal: 1000.00,
      taxAmount: 0.0,
      totalAmount: 1000.00,
      status: 'draft',
      createdAt: DateTime.now(),
    );
  }

  // Mock Receipt Extraction using Gemini Vision
  Future<Map<String, dynamic>> extractDataFromReceipt(String imagePath) async {
    await Future.delayed(const Duration(seconds: 3)); // Simulate AI processing

    // Mock extracted data from receipt
    return {
      'buyerName': 'ABC Trading Co.',
      'buyerTin': 'C12345678901',
      'buyerAddress': 'Kuala Lumpur, Malaysia',
      'lineItems': [
        {
          'description': 'Office Supplies',
          'quantity': 5.0,
          'unitPrice': 150.00,
          'amount': 750.00,
        },
        {
          'description': 'Stationery',
          'quantity': 10.0,
          'unitPrice': 50.00,
          'amount': 500.00,
        },
      ],
      'totalAmount': 1250.00,
      'date': DateTime.now().toIso8601String(),
      'confidence': 0.95, // AI confidence score
    };
  }

  // Mock Invoice Validation
  Future<Map<String, dynamic>> validateInvoice(InvoiceModel invoice) async {
    await Future.delayed(const Duration(seconds: 1));

    final errors = <String>[];
    final warnings = <String>[];

    // Mock validation rules
    if (invoice.buyerTin.isEmpty) {
      errors.add('Buyer TIN is required');
    }
    if (invoice.lineItems.isEmpty) {
      errors.add('At least one line item is required');
    }
    if (invoice.totalAmount >= 10000 && invoice.myInvoisId == null) {
      warnings.add('Invoice exceeds RM10,000 - MyInvois submission required');
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
      'complianceScore': errors.isEmpty ? 100 : 60,
    };
  }
}
