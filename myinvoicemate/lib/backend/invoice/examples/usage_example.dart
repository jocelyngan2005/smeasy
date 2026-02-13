import 'dart:io';
import '../services/invoice_orchestrator.dart';
import '../config/invoice_config.dart';
import '../models/invoice_draft.dart';

/// Example usage of the Invoice Generation Backend
/// 
/// This demonstrates the complete workflow from voice/receipt to finalized invoice

void main() async {
  // ==================== SETUP ====================
  
  // Initialize configuration
  final config = InvoiceBackendConfig(
    geminiApiKey: 'YOUR_GEMINI_API_KEY_HERE', // Get from Google AI Studio
    defaultVendor: DefaultVendorInfo(
      businessName: 'ABC Tech Solutions Sdn Bhd',
      tin: 'C 1234567890',
      sstNumber: 'W10-1234-56789012',
      registrationNumber: '202301012345',
      email: 'billing@abctech.com.my',
      phone: '+60123456789',
      addressLine1: 'No. 123, Jalan Teknologi',
      addressLine2: 'Taman Industri',
      city: 'Cyberjaya',
      state: 'Selangor',
      postalCode: '63000',
    ),
  );

  // Initialize orchestrator
  final orchestrator = InvoiceGenerationOrchestrator(
    geminiApiKey: config.geminiApiKey,
  );

  // ==================== EXAMPLE 1: VOICE TO INVOICE ====================
  
  print('=== Example 1: Voice/Text to Invoice ===\n');
  
  // Simulate voice input converted to text
  final voiceInput = '''
  Create invoice for Syarikat Maju Jaya, 5 laptops at RM3500 each,
  plus 10 wireless mice at RM85 each. Delivered to 456 Jalan Ampang,
  Kuala Lumpur. Contact person is Ahmad at 012-9876543.
  ''';

  final result1 = await orchestrator.generateFromVoiceOrText(
    input: voiceInput,
    userId: 'user123',
    vendorContext: config.defaultVendor?.toContextString(),
  );

  print('Status: ${result1.status}');
  print('Message: ${result1.message}');
  
  if (result1.draft != null) {
    print('\nDraft Details:');
    print('- Buyer: ${result1.draft!.buyer?.name ?? "Not detected"}');
    print('- Line Items: ${result1.draft!.lineItems.length}');
    print('- Subtotal: RM ${result1.draft!.subtotal?.toStringAsFixed(2)}');
    print('- Total: RM ${result1.draft!.totalAmount?.toStringAsFixed(2)}');
    print('- Missing Fields: ${result1.draft!.missingFields}');
    print('- Ready: ${result1.draft!.isReadyForFinalization}');
    print('- Confidence: ${(result1.draft!.confidenceScore ?? 0) * 100}%');
  }

  // ==================== EXAMPLE 2: RECEIPT SCANNING ====================
  
  print('\n\n=== Example 2: Receipt Scanning ===\n');
  
  // Scan receipt from file
  // final receiptImage = File('path/to/receipt.jpg');
  // final result2 = await orchestrator.generateFromReceiptFile(
  //   imageFile: receiptImage,
  //   userId: 'user123',
  // );

  // For demonstration, using bytes:
  // final imageBytes = await receiptImage.readAsBytes();
  // final result2 = await orchestrator.generateFromReceiptBytes(
  //   imageBytes: imageBytes,
  //   userId: 'user123',
  // );

  print('(Skipped - requires actual image file)');

  // ==================== EXAMPLE 3: REFINING DRAFT ====================
  
  print('\n\n=== Example 3: Refining Draft ===\n');
  
  if (result1.draft != null && !result1.draft!.isReadyForFinalization) {
    // Add missing information
    final refinedResult = await orchestrator.refineDraft(
      draft: result1.draft!,
      additionalInput: 'Buyer postal code is 50450, city is Kuala Lumpur',
      userId: 'user123',
    );

    print('Refined Status: ${refinedResult.status}');
    print('Ready: ${refinedResult.draft?.isReadyForFinalization}');
  }

  // ==================== EXAMPLE 4: FINALIZING INVOICE ====================
  
  print('\n\n=== Example 4: Finalizing Invoice ===\n');
  
  if (result1.draft != null) {
    // If draft needs vendor info, provide it
    final vendorInfo = PartyInfoDraft(
      name: config.defaultVendor!.businessName,
      tin: config.defaultVendor!.tin,
      registrationNumber: config.defaultVendor!.registrationNumber,
      email: config.defaultVendor!.email,
      phone: config.defaultVendor!.phone,
      address: AddressDraft(
        line1: config.defaultVendor!.addressLine1,
        line2: config.defaultVendor!.addressLine2,
        city: config.defaultVendor!.city,
        state: config.defaultVendor!.state,
        postalCode: config.defaultVendor!.postalCode,
        country: config.defaultVendor!.country,
      ),
    );

    // Create complete draft for finalization
    final completeDraft = InvoiceDraft(
      invoiceNumber: null, // Will be auto-generated
      type: result1.draft!.type,
      issueDate: result1.draft!.issueDate,
      dueDate: result1.draft!.dueDate,
      vendor: vendorInfo,
      buyer: result1.draft!.buyer,
      lineItems: result1.draft!.lineItems,
      subtotal: result1.draft!.subtotal,
      taxAmount: result1.draft!.taxAmount,
      totalAmount: result1.draft!.totalAmount,
      originalInput: result1.draft!.originalInput,
      confidenceScore: result1.draft!.confidenceScore,
      source: result1.draft!.source,
      missingFields: [], // All fields provided
      isReadyForFinalization: true,
    );

    final finalizeResult = await orchestrator.finalizeDraft(
      draft: completeDraft,
      userId: 'user123',
      vendorOverride: vendorInfo,
    );

    print('Finalization Success: ${finalizeResult.success}');
    print('Message: ${finalizeResult.message}');
    
    if (finalizeResult.invoice != null) {
      final invoice = finalizeResult.invoice!;
      print('\nInvoice Created:');
      print('- ID: ${invoice.id}');
      print('- Number: ${invoice.invoiceNumber}');
      print('- Total: RM ${invoice.totalAmount.toStringAsFixed(2)}');
      print('- Requires Submission: ${invoice.requiresSubmission}');
      print('- Status: ${invoice.complianceStatus.name}');

      // ==================== EXAMPLE 5: SUBMIT TO MYINVOIS ====================
      
      if (invoice.requiresSubmission) {
        print('\n\n=== Example 5: Submit to MyInvois ===\n');
        
        final submitResult = await orchestrator.submitToMyInvois(
          invoice: invoice,
        );

        print('Submission Success: ${submitResult.success}');
        print('Message: ${submitResult.message}');
        if (submitResult.referenceId != null) {
          print('Reference ID: ${submitResult.referenceId}');
          print('Submitted: ${submitResult.submissionDate}');
        }
      }
    }
  }

  // ==================== EXAMPLE 6: LIST INVOICES ====================
  
  print('\n\n=== Example 6: List User Invoices ===\n');
  
  final invoices = await orchestrator.listInvoices('user123');
  print('Total invoices: ${invoices.length}');
  
  for (final invoice in invoices.take(5)) {
    print('- ${invoice.invoiceNumber}: RM ${invoice.totalAmount.toStringAsFixed(2)} (${invoice.complianceStatus.name})');
  }

  print('\n=== Examples Complete ===');
}
