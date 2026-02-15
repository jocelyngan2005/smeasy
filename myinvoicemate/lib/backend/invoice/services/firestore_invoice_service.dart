import '../models/invoice_model.dart';
import '../models/invoice_draft.dart';

/// Mock service for managing invoices (in-memory storage until Firebase is configured)
class FirestoreInvoiceService {
  // Mock in-memory storage
  static final List<Invoice> _mockInvoices = [];
  static final Map<String, _DraftWithMetadata> _mockDrafts = {};
  
  // Collection names
  static const String invoicesCollection = 'invoices';
  static const String draftsCollection = 'invoice_drafts';
  static const String vendorsCollection = 'vendors';
  static const String buyersCollection = 'buyers';

  FirestoreInvoiceService({dynamic firestore});

  // ==================== INVOICE OPERATIONS ====================

  /// Save a finalized invoice to mock storage
  Future<String> saveInvoice(Invoice invoice) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      _mockInvoices.removeWhere((inv) => inv.id == invoice.id);
      _mockInvoices.add(invoice);
      return invoice.id;
    } catch (e) {
      throw Exception('Failed to save invoice: $e');
    }
  }

  /// Update an existing invoice
  Future<void> updateInvoice(Invoice invoice) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final index = _mockInvoices.indexWhere((inv) => inv.id == invoice.id);
      if (index != -1) {
        final updatedInvoice = invoice.copyWith(updatedAt: DateTime.now());
        _mockInvoices[index] = updatedInvoice;
      }
    } catch (e) {
      throw Exception('Failed to update invoice: $e');
    }
  }

  /// Get invoice by ID
  Future<Invoice?> getInvoice(String invoiceId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      return _mockInvoices.firstWhere(
        (inv) => inv.id == invoiceId,
        orElse: () => throw Exception('Invoice not found'),
      );
    } catch (e) {
      if (e.toString().contains('Invoice not found')) return null;
      throw Exception('Failed to get invoice: $e');
    }
  }

  /// Get all invoices for a user
  Future<List<Invoice>> getInvoicesByUser(String userId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      return _mockInvoices
          .where((inv) => inv.createdBy == userId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      throw Exception('Failed to get invoices: $e');
    }
  }

  /// Get invoices by date range
  Future<List<Invoice>> getInvoicesByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      return _mockInvoices
          .where((inv) => 
              inv.createdBy == userId &&
              !inv.issueDate.isBefore(startDate) &&
              !inv.issueDate.isAfter(endDate))
          .toList()
        ..sort((a, b) => b.issueDate.compareTo(a.issueDate));
    } catch (e) {
      throw Exception('Failed to get invoices by date range: $e');
    }
  }

  /// Get invoices by compliance status
  Future<List<Invoice>> getInvoicesByStatus({
    required String userId,
    required ComplianceStatus status,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      return _mockInvoices
          .where((inv) => 
              inv.createdBy == userId &&
              inv.complianceStatus == status)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      throw Exception('Failed to get invoices by status: $e');
    }
  }

  /// Get invoices requiring submission (total >= RM10k)
  Future<List<Invoice>> getInvoicesRequiringSubmission(String userId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      return _mockInvoices
          .where((inv) => 
              inv.createdBy == userId &&
              inv.requiresSubmission &&
              (inv.complianceStatus == ComplianceStatus.draft ||
               inv.complianceStatus == ComplianceStatus.validated))
          .toList()
        ..sort((a, b) => b.issueDate.compareTo(a.issueDate));
    } catch (e) {
      throw Exception('Failed to get invoices requiring submission: $e');
    }
  }

  /// Delete invoice
  Future<void> deleteInvoice(String invoiceId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      _mockInvoices.removeWhere((inv) => inv.id == invoiceId);
    } catch (e) {
      throw Exception('Failed to delete invoice: $e');
    }
  }

  /// Update invoice compliance status
  Future<void> updateComplianceStatus({
    required String invoiceId,
    required ComplianceStatus status,
    String? myInvoisReferenceId,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final index = _mockInvoices.indexWhere((inv) => inv.id == invoiceId);
      if (index != -1) {
        var invoice = _mockInvoices[index];
        invoice = invoice.copyWith(
          complianceStatus: status,
          updatedAt: DateTime.now(),
        );
        
        if (status == ComplianceStatus.submitted && myInvoisReferenceId != null) {
          invoice = invoice.copyWith(
            myInvoisReferenceId: myInvoisReferenceId,
          );
        }
        
        _mockInvoices[index] = invoice;
      }
    } catch (e) {
      throw Exception('Failed to update compliance status: $e');
    }
  }

  // ==================== DRAFT OPERATIONS ====================

  /// Save invoice draft
  Future<String> saveDraft(InvoiceDraft draft, String userId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final draftId = DateTime.now().millisecondsSinceEpoch.toString();
      _mockDrafts[draftId] = _DraftWithMetadata(
        id: draftId,
        userId: userId,
        createdAt: DateTime.now(),
        draft: draft,
      );
      return draftId;
    } catch (e) {
      throw Exception('Failed to save draft: $e');
    }
  }

  /// Get draft by ID
  Future<InvoiceDraft?> getDraft(String draftId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      return _mockDrafts[draftId]?.draft;
    } catch (e) {
      throw Exception('Failed to get draft: $e');
    }
  }

  /// Get all drafts for a user
  Future<List<InvoiceDraft>> getDraftsByUser(String userId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final userDrafts = _mockDrafts.values
          .where((metadata) => metadata.userId == userId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return userDrafts.map((m) => m.draft).toList();
    } catch (e) {
      throw Exception('Failed to get drafts: $e');
    }
  }

  /// Delete draft
  Future<void> deleteDraft(String draftId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      _mockDrafts.remove(draftId);
    } catch (e) {
      throw Exception('Failed to delete draft: $e');
    }
  }

  // ==================== ANALYTICS & REPORTING ====================

  /// Get total revenue for a period
  Future<double> getTotalRevenue({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final invoices = await getInvoicesByDateRange(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );

      return invoices.fold<double>(0.0, (sum, invoice) => sum + invoice.totalAmount);
    } catch (e) {
      throw Exception('Failed to calculate total revenue: $e');
    }
  }

  /// Get invoice count by status
  Future<Map<ComplianceStatus, int>> getInvoiceCountByStatus(String userId) async {
    try {
      final invoices = await getInvoicesByUser(userId);
      final countMap = <ComplianceStatus, int>{};

      for (final status in ComplianceStatus.values) {
        countMap[status] = invoices
            .where((invoice) => invoice.complianceStatus == status)
            .length;
      }

      return countMap;
    } catch (e) {
      throw Exception('Failed to get invoice count by status: $e');
    }
  }

  /// Get compliance readiness statistics
  Future<Map<String, dynamic>> getComplianceStats(String userId) async {
    try {
      final invoices = await getInvoicesByUser(userId);
      
      final requiresSubmission = invoices
          .where((inv) => inv.requiresSubmission)
          .length;
      
      final submitted = invoices
          .where((inv) => inv.complianceStatus == ComplianceStatus.submitted || 
                         inv.complianceStatus == ComplianceStatus.accepted)
          .length;

      final pending = invoices
          .where((inv) => inv.requiresSubmission && 
                         inv.complianceStatus != ComplianceStatus.submitted &&
                         inv.complianceStatus != ComplianceStatus.accepted)
          .length;

      final totalValue = invoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);

      return {
        'totalInvoices': invoices.length,
        'requiresSubmission': requiresSubmission,
        'submitted': submitted,
        'pending': pending,
        'totalValue': totalValue,
        'complianceRate': requiresSubmission > 0 
            ? (submitted / requiresSubmission * 100) 
            : 100.0,
      };
    } catch (e) {
      throw Exception('Failed to get compliance stats: $e');
    }
  }

  // ==================== SEARCH & FILTER ====================

  /// Search invoices by buyer name
  Future<List<Invoice>> searchInvoicesByBuyer({
    required String userId,
    required String buyerName,
  }) async {
    try {
      final invoices = await getInvoicesByUser(userId);
      
      return invoices
          .where((invoice) => 
              invoice.buyer.name.toLowerCase().contains(buyerName.toLowerCase()))
          .toList();
    } catch (e) {
      throw Exception('Failed to search invoices: $e');
    }
  }

  /// Search invoices by invoice number
  Future<Invoice?> searchByInvoiceNumber({
    required String userId,
    required String invoiceNumber,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      return _mockInvoices.firstWhere(
        (inv) => inv.createdBy == userId && inv.invoiceNumber == invoiceNumber,
        orElse: () => throw Exception('Invoice not found'),
      );
    } catch (e) {
      if (e.toString().contains('Invoice not found')) return null;
      throw Exception('Failed to search by invoice number: $e');
    }
  }

  // ==================== BATCH OPERATIONS ====================

  /// Batch update invoices
  Future<void> batchUpdateInvoices(List<Invoice> invoices) async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      for (final invoice in invoices) {
        final index = _mockInvoices.indexWhere((inv) => inv.id == invoice.id);
        if (index != -1) {
          _mockInvoices[index] = invoice;
        }
      }
    } catch (e) {
      throw Exception('Failed to batch update invoices: $e');
    }
  }

  /// Stream invoices (real-time updates) - Mock version returns snapshot
  Stream<List<Invoice>> streamInvoices(String userId) async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 1));
      yield _mockInvoices
          .where((inv) => inv.createdBy == userId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }
}

// Helper class to store draft with metadata
class _DraftWithMetadata {
  final String id;
  final String userId;
  final DateTime createdAt;
  final InvoiceDraft draft;

  _DraftWithMetadata({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.draft,
  });
}
