import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../models/invoice_model.dart';
import '../models/invoice_draft.dart';
import 'gemini_invoice_service.dart';
import 'gemini_vision_service.dart';
import 'firestore_invoice_service.dart';

/// Main orchestrator for invoice generation workflow
/// Coordinates between Gemini AI services and Firestore storage
class InvoiceGenerationOrchestrator {
  final GeminiInvoiceService _geminiInvoiceService;
  final GeminiVisionReceiptService _geminiVisionService;
  final FirestoreInvoiceService? _firestoreService;
  final Uuid _uuid = const Uuid();

  InvoiceGenerationOrchestrator({
    FirestoreInvoiceService? firestoreService,
  })  : _geminiInvoiceService = GeminiInvoiceService(),
        _geminiVisionService = GeminiVisionReceiptService(),
        _firestoreService = firestoreService;

  // ==================== VOICE/TEXT TO INVOICE ====================

  /// Generate invoice from voice/text input
  /// Returns draft invoice that can be refined or finalized
  Future<InvoiceGenerationResult> generateFromVoiceOrText({
    required String input,
    required String userId,
    String? vendorContext,
    bool saveDraft = true,
  }) async {
    try {
      // Step 1: Generate invoice draft using Gemini
      final draft = await _geminiInvoiceService.generateInvoiceFromText(
        input: input,
        vendorContext: vendorContext,
      );

      // Step 2: Save draft to Firestore if requested
      String? draftId;
      if (saveDraft && _firestoreService != null) {
        try {
          draftId = await _firestoreService.saveDraft(draft, userId);
        } catch (e) {
          // Firestore not available, continue without saving
          print('Warning: Could not save draft to Firestore: $e');
        }
      }

      return InvoiceGenerationResult(
        draft: draft,
        draftId: draftId,
        status: draft.isReadyForFinalization
            ? InvoiceGenerationStatus.readyForFinalization
            : InvoiceGenerationStatus.requiresReview,
        message: _generateStatusMessage(draft),
      );
    } catch (e) {
      return InvoiceGenerationResult(
        status: InvoiceGenerationStatus.failed,
        message: 'Failed to generate invoice: $e',
        error: e.toString(),
      );
    }
  }

  /// Refine existing draft with additional information
  Future<InvoiceGenerationResult> refineDraft({
    required InvoiceDraft draft,
    required String additionalInput,
    required String userId,
  }) async {
    try {
      // Refine draft using Gemini
      final refinedDraft = await _geminiInvoiceService.refineInvoiceDraft(
        draft: draft,
        additionalInput: additionalInput,
      );

      // Save refined draft
      String? draftId;
      if (_firestoreService != null) {
        try {
          draftId = await _firestoreService.saveDraft(refinedDraft, userId);
        } catch (e) {
          print('Warning: Could not save draft to Firestore: $e');
        }
      }

      return InvoiceGenerationResult(
        draft: refinedDraft,
        draftId: draftId,
        status: refinedDraft.isReadyForFinalization
            ? InvoiceGenerationStatus.readyForFinalization
            : InvoiceGenerationStatus.requiresReview,
        message: _generateStatusMessage(refinedDraft),
      );
    } catch (e) {
      return InvoiceGenerationResult(
        status: InvoiceGenerationStatus.failed,
        message: 'Failed to refine draft: $e',
        error: e.toString(),
      );
    }
  }

  // ==================== RECEIPT SCANNING ====================

  /// Generate invoice from receipt image (File)
  Future<InvoiceGenerationResult> generateFromReceiptFile({
    required File imageFile,
    required String userId,
    bool saveDraft = true,
  }) async {
    try {
      // Scan receipt using Gemini Vision
      final draft = await _geminiVisionService.scanReceipt(
        imageFile: imageFile,
      );

      // Save draft if requested
      String? draftId;
      if (saveDraft && _firestoreService != null) {
        try {
          draftId = await _firestoreService.saveDraft(draft, userId);
        } catch (e) {
          // Firestore not available, continue without saving
          print('Warning: Could not save draft to Firestore: $e');
        }
      }

      return InvoiceGenerationResult(
        draft: draft,
        draftId: draftId,
        status: draft.isReadyForFinalization
            ? InvoiceGenerationStatus.readyForFinalization
            : InvoiceGenerationStatus.requiresReview,
        message: _generateStatusMessage(draft),
      );
    } catch (e) {
      return InvoiceGenerationResult(
        status: InvoiceGenerationStatus.failed,
        message: 'Failed to scan receipt: $e',
        error: e.toString(),
      );
    }
  }

  /// Generate invoice from receipt image bytes (for mobile/web)
  Future<InvoiceGenerationResult> generateFromReceiptBytes({
    required Uint8List imageBytes,
    required String userId,
    String mimeType = 'image/jpeg',
    bool saveDraft = true,
  }) async {
    try {
      // Scan receipt using Gemini Vision
      final draft = await _geminiVisionService.scanReceiptFromBytes(
        imageBytes: imageBytes,
        mimeType: mimeType,
      );

      // Save draft if requested
      String? draftId;
      if (saveDraft && _firestoreService != null) {
        try {
          draftId = await _firestoreService.saveDraft(draft, userId);
        } catch (e) {
          print('Warning: Could not save draft to Firestore: $e');
        }
      }

      return InvoiceGenerationResult(
        draft: draft,
        draftId: draftId,
        status: draft.isReadyForFinalization
            ? InvoiceGenerationStatus.readyForFinalization
            : InvoiceGenerationStatus.requiresReview,
        message: _generateStatusMessage(draft),
      );
    } catch (e) {
      return InvoiceGenerationResult(
        status: InvoiceGenerationStatus.failed,
        message: 'Failed to scan receipt: $e',
        error: e.toString(),
      );
    }
  }

  // ==================== FINALIZATION ====================

  /// Finalize draft and create actual invoice
  Future<InvoiceFinalizationResult> finalizeDraft({
    required InvoiceDraft draft,
    required String userId,
    String? invoiceNumber,
    PartyInfoDraft? vendorOverride,
  }) async {
    try {
      // Validate draft
      if (!draft.isReadyForFinalization) {
        return InvoiceFinalizationResult(
          success: false,
          message: 'Draft is not ready for finalization. Missing: ${draft.missingFields.join(", ")}',
        );
      }

      // Apply vendor override if provided
      final finalDraft = vendorOverride != null
          ? InvoiceDraft(
              invoiceNumber: draft.invoiceNumber,
              type: draft.type,
              issueDate: draft.issueDate,
              dueDate: draft.dueDate,
              vendor: vendorOverride,
              buyer: draft.buyer,
              lineItems: draft.lineItems,
              subtotal: draft.subtotal,
              taxAmount: draft.taxAmount,
              totalAmount: draft.totalAmount,
              originalInput: draft.originalInput,
              confidenceScore: draft.confidenceScore,
              extractedEntities: draft.extractedEntities,
              rawAIResponse: draft.rawAIResponse,
              source: draft.source,
              missingFields: [],
              warnings: draft.warnings,
              isReadyForFinalization: true,
            )
          : draft;

      // Generate invoice ID and number
      final invoiceId = _uuid.v4();
      final finalInvoiceNumber = invoiceNumber ?? 
          _generateInvoiceNumber(userId);

      // Convert draft to invoice
      final invoice = finalDraft.toInvoice(
        id: invoiceId,
        createdBy: userId,
      ).copyWith(
        invoiceNumber: finalInvoiceNumber,
      );

      // Save to Firestore
      if (_firestoreService != null) {
        try {
          await _firestoreService.saveInvoice(invoice);
        } catch (e) {
          print('Warning: Could not save invoice to Firestore: $e');
        }
      }

      return InvoiceFinalizationResult(
        success: true,
        invoice: invoice,
        message: 'Invoice created successfully: $finalInvoiceNumber',
      );
    } catch (e) {
      return InvoiceFinalizationResult(
        success: false,
        message: 'Failed to finalize invoice: $e',
        error: e.toString(),
      );
    }
  }

  /// Submit invoice to MyInvois (mocked for now)
  Future<SubmissionResult> submitToMyInvois({
    required Invoice invoice,
  }) async {
    try {
      // TODO: Implement actual MyInvois API integration
      // For now, this is a mock implementation
      
      // Validate invoice before submission
      if (!invoice.requiresSubmission) {
        return SubmissionResult(
          success: false,
          message: 'Invoice does not meet submission threshold (< RM10,000)',
        );
      }

      if (invoice.complianceStatus == ComplianceStatus.submitted ||
          invoice.complianceStatus == ComplianceStatus.accepted) {
        return SubmissionResult(
          success: false,
          message: 'Invoice already submitted',
        );
      }

      // Mock submission - generate reference ID
      final mockReferenceId = 'MYINV-${DateTime.now().millisecondsSinceEpoch}';

      // Update invoice status
      if (_firestoreService != null) {
        try {
          await _firestoreService.updateComplianceStatus(
            invoiceId: invoice.id,
            status: ComplianceStatus.submitted,
            myInvoisReferenceId: mockReferenceId,
          );
        } catch (e) {
          print('Warning: Could not update status in Firestore: $e');
        }
      }

      return SubmissionResult(
        success: true,
        message: 'Invoice submitted successfully to MyInvois',
        referenceId: mockReferenceId,
        submissionDate: DateTime.now(),
      );
    } catch (e) {
      return SubmissionResult(
        success: false,
        message: 'Failed to submit invoice: $e',
        error: e.toString(),
      );
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Generate invoice number (sequential)
  String _generateInvoiceNumber(String userId) {
    // In production, you'd want to use Firestore transactions
    // to ensure unique sequential numbers
    final timestamp = DateTime.now();
    return 'INV-${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}-${timestamp.millisecondsSinceEpoch.toString().substring(7)}';
  }

  /// Generate status message based on draft state
  String _generateStatusMessage(InvoiceDraft draft) {
    if (draft.isReadyForFinalization) {
      return 'Invoice draft is ready for finalization';
    }

    final missing = draft.missingFields;
    final warnings = draft.warnings;

    String message = 'Draft requires review. ';
    
    if (missing.isNotEmpty) {
      message += 'Missing: ${missing.join(", ")}. ';
    }
    
    if (warnings.isNotEmpty) {
      message += 'Warnings: ${warnings.join("; ")}.';
    }

    return message;
  }

  /// Get draft by ID
  Future<InvoiceDraft?> getDraft(String draftId) async {
    if (_firestoreService == null) return null;
    try {
      return await _firestoreService.getDraft(draftId);
    } catch (e) {
      print('Warning: Could not get draft from Firestore: $e');
      return null;
    }
  }

  /// Get invoice by ID
  Future<Invoice?> getInvoice(String invoiceId) async {
    if (_firestoreService == null) return null;
    try {
      return await _firestoreService.getInvoice(invoiceId);
    } catch (e) {
      print('Warning: Could not get invoice from Firestore: $e');
      return null;
    }
  }

  /// List user's drafts
  Future<List<InvoiceDraft>> listDrafts(String userId) async {
    if (_firestoreService == null) return [];
    try {
      return await _firestoreService.getDraftsByUser(userId);
    } catch (e) {
      print('Warning: Could not list drafts from Firestore: $e');
      return [];
    }
  }

  /// List user's invoices
  Future<List<Invoice>> listInvoices(String userId) async {
    if (_firestoreService == null) return [];
    try {
      return await _firestoreService.getInvoicesByUser(userId);
    } catch (e) {
      print('Warning: Could not list invoices from Firestore: $e');
      return [];
    }
  }
}

// ==================== RESULT MODELS ====================

class InvoiceGenerationResult {
  final InvoiceDraft? draft;
  final String? draftId;
  final InvoiceGenerationStatus status;
  final String message;
  final String? error;

  InvoiceGenerationResult({
    this.draft,
    this.draftId,
    required this.status,
    required this.message,
    this.error,
  });
}

class InvoiceFinalizationResult {
  final bool success;
  final Invoice? invoice;
  final String message;
  final String? error;

  InvoiceFinalizationResult({
    required this.success,
    this.invoice,
    required this.message,
    this.error,
  });
}

class SubmissionResult {
  final bool success;
  final String message;
  final String? referenceId;
  final DateTime? submissionDate;
  final String? error;

  SubmissionResult({
    required this.success,
    required this.message,
    this.referenceId,
    this.submissionDate,
    this.error,
  });
}

enum InvoiceGenerationStatus {
  readyForFinalization,
  requiresReview,
  failed,
}
