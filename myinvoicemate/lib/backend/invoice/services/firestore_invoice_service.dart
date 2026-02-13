import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice_model.dart';
import '../models/invoice_draft.dart';

/// Service for managing invoices in Firestore
class FirestoreInvoiceService {
  final FirebaseFirestore _firestore;
  
  // Collection names
  static const String invoicesCollection = 'invoices';
  static const String draftsCollection = 'invoice_drafts';
  static const String vendorsCollection = 'vendors';
  static const String buyersCollection = 'buyers';

  FirestoreInvoiceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==================== INVOICE OPERATIONS ====================

  /// Save a finalized invoice to Firestore
  Future<String> saveInvoice(Invoice invoice) async {
    try {
      final docRef = _firestore.collection(invoicesCollection).doc(invoice.id);
      await docRef.set(invoice.toJson());
      return invoice.id;
    } catch (e) {
      throw Exception('Failed to save invoice: $e');
    }
  }

  /// Update an existing invoice
  Future<void> updateInvoice(Invoice invoice) async {
    try {
      final docRef = _firestore.collection(invoicesCollection).doc(invoice.id);
      final updatedInvoice = invoice.copyWith(updatedAt: DateTime.now());
      await docRef.update(updatedInvoice.toJson());
    } catch (e) {
      throw Exception('Failed to update invoice: $e');
    }
  }

  /// Get invoice by ID
  Future<Invoice?> getInvoice(String invoiceId) async {
    try {
      final doc = await _firestore
          .collection(invoicesCollection)
          .doc(invoiceId)
          .get();
      
      if (!doc.exists) return null;
      
      return Invoice.fromJson(doc.data()!);
    } catch (e) {
      throw Exception('Failed to get invoice: $e');
    }
  }

  /// Get all invoices for a user
  Future<List<Invoice>> getInvoicesByUser(String userId) async {
    try {
      final query = await _firestore
          .collection(invoicesCollection)
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => Invoice.fromJson(doc.data()))
          .toList();
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
      final query = await _firestore
          .collection(invoicesCollection)
          .where('createdBy', isEqualTo: userId)
          .where('issueDate', isGreaterThanOrEqualTo: startDate)
          .where('issueDate', isLessThanOrEqualTo: endDate)
          .orderBy('issueDate', descending: true)
          .get();

      return query.docs
          .map((doc) => Invoice.fromJson(doc.data()))
          .toList();
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
      final query = await _firestore
          .collection(invoicesCollection)
          .where('createdBy', isEqualTo: userId)
          .where('complianceStatus', isEqualTo: status.name)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => Invoice.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get invoices by status: $e');
    }
  }

  /// Get invoices requiring submission (total >= RM10k)
  Future<List<Invoice>> getInvoicesRequiringSubmission(String userId) async {
    try {
      final query = await _firestore
          .collection(invoicesCollection)
          .where('createdBy', isEqualTo: userId)
          .where('requiresSubmission', isEqualTo: true)
          .where('complianceStatus', whereIn: [
            ComplianceStatus.draft.name,
            ComplianceStatus.validated.name
          ])
          .orderBy('issueDate', descending: true)
          .get();

      return query.docs
          .map((doc) => Invoice.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get invoices requiring submission: $e');
    }
  }

  /// Delete invoice
  Future<void> deleteInvoice(String invoiceId) async {
    try {
      await _firestore.collection(invoicesCollection).doc(invoiceId).delete();
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
      final updates = <String, dynamic>{
        'complianceStatus': status.name,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (status == ComplianceStatus.submitted && myInvoisReferenceId != null) {
        updates['myInvoisReferenceId'] = myInvoisReferenceId;
        updates['submissionDate'] = DateTime.now().toIso8601String();
      }

      await _firestore
          .collection(invoicesCollection)
          .doc(invoiceId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update compliance status: $e');
    }
  }

  // ==================== DRAFT OPERATIONS ====================

  /// Save invoice draft
  Future<String> saveDraft(InvoiceDraft draft, String userId) async {
    try {
      final draftId = DateTime.now().millisecondsSinceEpoch.toString();
      final draftData = {
        ...draft.toJson(),
        'id': draftId,
        'createdBy': userId,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _firestore
          .collection(draftsCollection)
          .doc(draftId)
          .set(draftData);

      return draftId;
    } catch (e) {
      throw Exception('Failed to save draft: $e');
    }
  }

  /// Get draft by ID
  Future<InvoiceDraft?> getDraft(String draftId) async {
    try {
      final doc = await _firestore
          .collection(draftsCollection)
          .doc(draftId)
          .get();

      if (!doc.exists) return null;

      return InvoiceDraft.fromJson(doc.data()!);
    } catch (e) {
      throw Exception('Failed to get draft: $e');
    }
  }

  /// Get all drafts for a user
  Future<List<InvoiceDraft>> getDraftsByUser(String userId) async {
    try {
      final query = await _firestore
          .collection(draftsCollection)
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => InvoiceDraft.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get drafts: $e');
    }
  }

  /// Delete draft
  Future<void> deleteDraft(String draftId) async {
    try {
      await _firestore.collection(draftsCollection).doc(draftId).delete();
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
      final query = await _firestore
          .collection(invoicesCollection)
          .where('createdBy', isEqualTo: userId)
          .where('invoiceNumber', isEqualTo: invoiceNumber)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      return Invoice.fromJson(query.docs.first.data());
    } catch (e) {
      throw Exception('Failed to search by invoice number: $e');
    }
  }

  // ==================== BATCH OPERATIONS ====================

  /// Batch update invoices
  Future<void> batchUpdateInvoices(List<Invoice> invoices) async {
    try {
      final batch = _firestore.batch();

      for (final invoice in invoices) {
        final docRef = _firestore.collection(invoicesCollection).doc(invoice.id);
        batch.update(docRef, invoice.toJson());
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to batch update invoices: $e');
    }
  }

  /// Stream invoices (real-time updates)
  Stream<List<Invoice>> streamInvoices(String userId) {
    return _firestore
        .collection(invoicesCollection)
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Invoice.fromJson(doc.data()))
            .toList());
  }
}
