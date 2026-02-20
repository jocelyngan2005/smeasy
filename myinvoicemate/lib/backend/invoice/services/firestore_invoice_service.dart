import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firestore_collections.dart';
import '../models/invoice_model.dart';
import '../models/invoice_draft.dart';

/// Real Firestore-backed service for /invoices and /invoice_drafts collections.
///
/// All invoices are user-isolated via the [createdBy] field (indexed in Firestore).
/// Soft-delete is enforced: documents are never hard-deleted; [isDeleted] = true instead.
class FirestoreInvoiceService {
  FirestoreInvoiceService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _invoices =>
      _db.collection(FirestoreCollections.invoices);

  CollectionReference<Map<String, dynamic>> get _drafts =>
      _db.collection(FirestoreCollections.invoiceDrafts);

  // =========================================================================
  // INVOICE OPERATIONS
  // =========================================================================

  /// Save a finalized invoice. Returns the Firestore document ID.
  Future<String> saveInvoice(Invoice invoice) async {
    final doc = _invoices.doc(invoice.id.isEmpty ? null : invoice.id);
    await doc.set(_toFirestoreMap(invoice.toJson()..['id'] = doc.id));
    return doc.id;
  }

  /// Update an existing invoice in place.
  Future<void> updateInvoice(Invoice invoice) async {
    final data = _toFirestoreMap(invoice.toJson())
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _invoices.doc(invoice.id).update(data);
  }

  /// Fetch a single invoice by ID, or null if not found / soft-deleted.
  Future<Invoice?> getInvoice(String invoiceId) async {
    final doc = await _invoices.doc(invoiceId).get();
    if (!doc.exists) return null;
    final data = _fromFirestoreMap(doc.data()!);
    if (data['isDeleted'] == true) return null;
    return Invoice.fromJson(data..['id'] = doc.id);
  }

  /// All non-deleted invoices for [userId], newest first.
  Future<List<Invoice>> getInvoicesByUser(String userId) async {
    final snap = await _invoices
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => Invoice.fromJson(_fromFirestoreMap(d.data())..['id'] = d.id))
        .toList();
  }

  /// Invoices within a date range (inclusive), for [userId].
  Future<List<Invoice>> getInvoicesByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final snap = await _invoices
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('issueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('issueDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('issueDate', descending: true)
        .get();
    return snap.docs
        .map((d) => Invoice.fromJson(_fromFirestoreMap(d.data())..['id'] = d.id))
        .toList();
  }

  /// Invoices with a specific [ComplianceStatus] for [userId].
  Future<List<Invoice>> getInvoicesByStatus(
    String userId,
    ComplianceStatus status,
  ) async {
    final snap = await _invoices
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('complianceStatus', isEqualTo: status.name)
        .get();
    return snap.docs
        .map((d) => Invoice.fromJson(_fromFirestoreMap(d.data())..['id'] = d.id))
        .toList();
  }

  /// Invoices that need MyInvois submission (amount ≥ RM10 000).
  Future<List<Invoice>> getInvoicesRequiringSubmission(String userId) async {
    final snap = await _invoices
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('requiresSubmission', isEqualTo: true)
        .where('complianceStatus', isEqualTo: ComplianceStatus.validated.name)
        .get();
    return snap.docs
        .map((d) => Invoice.fromJson(_fromFirestoreMap(d.data())..['id'] = d.id))
        .toList();
  }

  /// Soft-delete: sets [isDeleted] = true and records [deletedAt].
  Future<void> deleteInvoice(String invoiceId) async {
    await _invoices.doc(invoiceId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update only the [complianceStatus] field (and optionally the LHDN reference).
  Future<void> updateComplianceStatus(
    String invoiceId,
    ComplianceStatus status, {
    String? myInvoisReferenceId,
    DateTime? submissionDate,
  }) async {
    final update = <String, dynamic>{
      'complianceStatus': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (myInvoisReferenceId != null) {
      update['myInvoisReferenceId'] = myInvoisReferenceId;
    }
    if (submissionDate != null) {
      update['submissionDate'] = Timestamp.fromDate(submissionDate);
    }
    await _invoices.doc(invoiceId).update(update);
  }

  // =========================================================================
  // DRAFT OPERATIONS
  // =========================================================================

  /// Save (or overwrite) a draft. Returns the document ID.
  /// Pass [draftId] to upsert an existing draft, omit to auto-generate.
  Future<String> saveDraft(InvoiceDraft draft, String userId, {String? draftId}) async {
    final now = FieldValue.serverTimestamp();
    final data = _toFirestoreMap(draft.toJson())
      ..['userId'] = userId
      ..['updatedAt'] = now;

    if (draftId != null && draftId.isNotEmpty) {
      await _drafts.doc(draftId).set(data..['createdAt'] = now, SetOptions(merge: true));
      return draftId;
    } else {
      final doc = _drafts.doc();
      await doc.set(data..['createdAt'] = now);
      return doc.id;
    }
  }

  /// Fetch a draft by ID.
  Future<InvoiceDraft?> getDraft(String draftId) async {
    final doc = await _drafts.doc(draftId).get();
    if (!doc.exists) return null;
    return InvoiceDraft.fromJson(_fromFirestoreMap(doc.data()!));
  }

  /// All drafts for [userId], newest first.
  Future<List<InvoiceDraft>> getDraftsByUser(String userId) async {
    final snap = await _drafts
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .get();
    return snap.docs
        .map((d) => InvoiceDraft.fromJson(_fromFirestoreMap(d.data())))
        .toList();
  }

  /// Delete a draft permanently.
  Future<void> deleteDraft(String draftId) async {
    await _drafts.doc(draftId).delete();
  }

  // =========================================================================
  // ANALYTICS (aggregated queries)
  // =========================================================================

  /// Total revenue for [userId] across all accepted invoices.
  Future<double> getTotalRevenue(String userId) async {
    final snap = await _invoices
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('complianceStatus', isEqualTo: ComplianceStatus.accepted.name)
        .get();
    return snap.docs.fold<double>(
      0.0,
      (sum, d) => sum + ((d.data()['totalAmount'] as num?) ?? 0).toDouble(),
    );
  }

  /// Count of invoices per [ComplianceStatus] for [userId].
  Future<Map<ComplianceStatus, int>> getInvoiceCountByStatus(
      String userId) async {
    final snap = await _invoices
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .get();
    final counts = <ComplianceStatus, int>{};
    for (final doc in snap.docs) {
      final statusStr = doc.data()['complianceStatus'] as String?;
      final status = ComplianceStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => ComplianceStatus.draft,
      );
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  /// Compliance statistics map for [userId].
  Future<Map<String, dynamic>> getComplianceStats(String userId) async {
    final snap = await _invoices
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .get();
    int total = snap.docs.length;
    int pending = 0;
    int submitted = 0;
    double revenue = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final status = data['complianceStatus'] as String?;
      if (status == ComplianceStatus.validated.name) pending++;
      if (status == ComplianceStatus.submitted.name ||
          status == ComplianceStatus.accepted.name) submitted++;
      revenue += ((data['totalAmount'] as num?) ?? 0).toDouble();
    }

    return {
      'totalInvoices': total,
      'pendingSubmissions': pending,
      'submittedThisMonth': submitted,
      'totalRevenue': revenue,
    };
  }

  // =========================================================================
  // SEARCH
  // =========================================================================

  /// Search invoices by buyer name (case-sensitive prefix; use lowercase field for better UX).
  Future<List<Invoice>> searchInvoicesByBuyer(
      String userId, String buyerName) async {
    // Firestore doesn't support full-text search; use range query on buyer.name.
    final snap = await _invoices
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('buyer.name', isGreaterThanOrEqualTo: buyerName)
        .where('buyer.name', isLessThan: '${buyerName}z')
        .get();
    return snap.docs
        .map((d) => Invoice.fromJson(_fromFirestoreMap(d.data())..['id'] = d.id))
        .toList();
  }

  /// Exact match search by invoice number for [userId].
  Future<Invoice?> searchByInvoiceNumber(
      String userId, String invoiceNumber) async {
    final snap = await _invoices
        .where('createdBy', isEqualTo: userId)
        .where('invoiceNumber', isEqualTo: invoiceNumber)
        .where('isDeleted', isEqualTo: false)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Invoice.fromJson(_fromFirestoreMap(d.data())..['id'] = d.id);
  }

  // =========================================================================
  // BATCH & STREAMING
  // =========================================================================

  /// Apply [updater] to a list of invoices in a single Firestore batch write.
  Future<void> batchUpdateInvoices(
    List<String> invoiceIds,
    Invoice Function(Invoice) updater,
  ) async {
    final batch = _db.batch();
    for (final id in invoiceIds) {
      final doc = await _invoices.doc(id).get();
      if (!doc.exists) continue;
      final invoice =
          Invoice.fromJson(_fromFirestoreMap(doc.data()!)..['id'] = id);
      final updated = updater(invoice);
      batch.update(
        _invoices.doc(id),
        _toFirestoreMap(updated.toJson())
          ..['updatedAt'] = FieldValue.serverTimestamp(),
      );
    }
    await batch.commit();
  }

  /// Real-time stream of all non-deleted invoices for [userId].
  Stream<List<Invoice>> streamInvoices(String userId) {
    return _invoices
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                Invoice.fromJson(_fromFirestoreMap(d.data())..['id'] = d.id))
            .toList());
  }

  // =========================================================================
  // PRIVATE HELPERS — DateTime ↔ Timestamp conversion
  // =========================================================================

  /// Recursively converts [DateTime] ISO strings produced by json_annotation
  /// into Firestore [Timestamp] objects.
  static Map<String, dynamic> _toFirestoreMap(Map<String, dynamic> json) {
    return json.map((key, value) {
      if (value is String) {
        final dt = _tryParseDateTime(key, value);
        if (dt != null) return MapEntry(key, Timestamp.fromDate(dt));
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, _toFirestoreMap(value));
      } else if (value is List) {
        return MapEntry(
          key,
          value
              .map((e) =>
                  e is Map<String, dynamic> ? _toFirestoreMap(e) : e)
              .toList(),
        );
      }
      return MapEntry(key, value);
    });
  }

  /// Inverse of [_toFirestoreMap]: converts Firestore [Timestamp] objects back
  /// to ISO 8601 strings so the json_annotation fromJson constructors work.
  static Map<String, dynamic> _fromFirestoreMap(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, _fromFirestoreMap(value));
      } else if (value is List) {
        return MapEntry(
          key,
          value
              .map((e) =>
                  e is Map<String, dynamic> ? _fromFirestoreMap(e) : e)
              .toList(),
        );
      }
      return MapEntry(key, value);
    });
  }

  /// Returns a [DateTime] if [value] is an ISO string AND [key] looks like a
  /// date/timestamp field. Avoids false positives on arbitrary strings.
  static DateTime? _tryParseDateTime(String key, String value) {
    const dateKeys = {
      'issueDate', 'dueDate', 'submissionDate', 'createdAt', 'updatedAt',
      'deletedAt', 'lastInvoiceDate',
    };
    if (!dateKeys.contains(key)) return null;
    return DateTime.tryParse(value);
  }
}