import 'package:cloud_firestore/cloud_firestore.dart';
import '../compliance/models/compliance_model.dart';
import '../compliance/services/compliance_service.dart';
import '../firestore_collections.dart';
import '../invoice/models/invoice_model.dart';

// ignore_for_file: avoid_catches_without_on_clauses

/// Scans live Firestore invoice data and generates actionable compliance,
/// financial, and audit notifications.  Uses deterministic document IDs so
/// the same alert is never written twice.
///
/// ─────────────────────────────────────────────────────────
/// ID convention   │ Trigger
/// ─────────────────────────────────────────────────────────
/// lhdn_validated_{inv}      validation success
/// lhdn_rejected_{inv}       invoice rejected by LHDN
/// lhdn_pending_{inv}        submitted but silent > 48 h
/// lhdn_deadline_{inv}       draft ≥ RM 10 k, due within 24 h
/// financial_overdue_{inv}   dueDate passed, not cancelled
/// financial_due3d_{inv}     dueDate within 3 days
/// financial_summary_{uid}_{yyyy}_{mm}   monthly report
/// audit_edited_{inv}        invoice updated after submission
/// ─────────────────────────────────────────────────────────
class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    ComplianceService? complianceService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _compliance = complianceService ?? ComplianceService();

  final FirebaseFirestore _db;
  final ComplianceService _compliance;

  // -------------------------------------------------------------------------
  // Streams — delegated to ComplianceService
  // -------------------------------------------------------------------------

  Stream<List<ComplianceAlert>> watchAlerts(String userId) =>
      _compliance.watchAlerts(userId);

  Stream<int> watchUnreadCount(String userId) =>
      _compliance.watchUnreadCount(userId);

  // -------------------------------------------------------------------------
  // Mark / clear helpers
  // -------------------------------------------------------------------------

  Future<void> markAlertRead(String alertId) =>
      _compliance.markAlertRead(alertId);

  Future<void> markAllRead(String userId) => _compliance.markAllRead(userId);

  Future<void> deleteAlert(String alertId) => _compliance.deleteAlert(alertId);

  Future<void> clearReadAlerts(String userId) =>
      _compliance.clearReadAlerts(userId);

  Future<void> clearAllAlerts(String userId) =>
      _compliance.clearAllAlerts(userId);

  // -------------------------------------------------------------------------
  // Core sync — scans all invoices and writes missing alerts
  // -------------------------------------------------------------------------

  /// Scan every invoice owned by [userId] and write any missing alerts to
  /// Firestore.  Already-existing alert IDs are fetched first so we never
  /// create duplicates.  All writes go through a single WriteBatch (≤ 500 ops).
  Future<void> syncNotifications(String userId) async {
    final now = DateTime.now();
    final existingIds = await _compliance.getExistingAlertIds(userId);

    final invoiceSnap = await _db
        .collection(FirestoreCollections.invoices)
        .where('createdBy', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .get();

    final invoices = invoiceSnap.docs.map((d) {
      final data = _fromFirestoreMap(d.data());
      return Invoice.fromJson(data..['id'] = d.id);
    }).toList();

    // Aggregate totals for financial summary.
    double monthRevenue = 0;
    double lastMonthRevenue = 0;
    double totalOutstanding = 0;
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    final batch = _db.batch();
    int ops = 0;

    // -- Per-invoice alerts --------------------------------------------------
    for (final inv in invoices) {
      // ── LHDN: validated ───────────────────────────────────────────────────
      final validatedId = 'lhdn_validated_${inv.id}';
      if (inv.complianceStatus == ComplianceStatus.valid &&
          !existingIds.contains(validatedId)) {
        _queueAlert(
          batch: batch,
          alertId: validatedId,
          userId: userId,
          alert: ComplianceAlert(
            id: validatedId,
            title: '${inv.invoiceNumber} Validated by LHDN ✓',
            message:
                'Invoice ${inv.invoiceNumber} (${_fmt(inv.totalAmount)}) has been '
                'successfully validated by MyInvois. Reference: '
                '${inv.myInvoisReferenceId ?? "—"}.',
            type: 'success',
            category: AlertCategory.lhdn,
            severity: AlertSeverity.low,
            deadline: inv.submissionDate ?? now,
          ),
          existingIds: existingIds,
        );
        ops++;
      }

      // ── LHDN: rejected ────────────────────────────────────────────────────
      final rejectedId = 'lhdn_rejected_${inv.id}';
      if (inv.complianceStatus == ComplianceStatus.invalid &&
          !existingIds.contains(rejectedId)) {
        final meta = inv.metadata ?? {};
        final reason = meta['rejectionReason'] as String? ?? 'See invoice details';
        final code = meta['rejectionCode'] as String? ?? '';
        _queueAlert(
          batch: batch,
          alertId: rejectedId,
          userId: userId,
          alert: ComplianceAlert(
            id: rejectedId,
            title: '${inv.invoiceNumber} Rejected by LHDN',
            message:
                'MyInvois rejected ${inv.invoiceNumber}${code.isNotEmpty ? " (Error $code)" : ""}. '
                'Reason: $reason. Correct and resubmit within 72 hours.',
            type: 'error',
            category: AlertCategory.lhdn,
            severity: AlertSeverity.critical,
            deadline: (inv.submissionDate ?? now).add(const Duration(hours: 72)),
            relatedInvoiceId: inv.id,
            metadata: meta.isEmpty ? null : Map<String, dynamic>.from(meta),
          ),
          existingIds: existingIds,
        );
        ops++;
      }

      // ── LHDN: submission pending > 48 h ───────────────────────────────────
      final pendingId = 'lhdn_pending_${inv.id}';
      if (inv.complianceStatus == ComplianceStatus.submitted &&
          inv.submissionDate != null &&
          now.difference(inv.submissionDate!).inHours > 48 &&
          !existingIds.contains(pendingId)) {
        final elapsed = now.difference(inv.submissionDate!).inHours;
        _queueAlert(
          batch: batch,
          alertId: pendingId,
          userId: userId,
          alert: ComplianceAlert(
            id: pendingId,
            title: '${inv.invoiceNumber} Pending Validation (${elapsed}h)',
            message:
                'Invoice ${inv.invoiceNumber} submitted to MyInvois ${elapsed} hours ago '
                'with no response yet. Check your MyInvois dashboard or contact LHDN support.',
            type: 'warning',
            category: AlertCategory.lhdn,
            severity: AlertSeverity.high,
            deadline: (inv.submissionDate ?? now).add(const Duration(hours: 72)),
            relatedInvoiceId: inv.id,
          ),
          existingIds: existingIds,
        );
        ops++;
      }

      // ── LHDN: submission deadline within 24 h ─────────────────────────────
      final deadlineId = 'lhdn_deadline_${inv.id}';
      if (inv.requiresSubmission &&
          inv.complianceStatus == ComplianceStatus.draft) {
        final submitDeadline = inv.issueDate.add(const Duration(hours: 72));
        final hoursLeft = submitDeadline.difference(now).inHours;
        if (hoursLeft <= 24 && hoursLeft >= 0 && !existingIds.contains(deadlineId)) {
          _queueAlert(
            batch: batch,
            alertId: deadlineId,
            userId: userId,
            alert: ComplianceAlert(
              id: deadlineId,
              title: 'Submit ${inv.invoiceNumber} Now — ${hoursLeft}h Left',
              message:
                  '${inv.invoiceNumber} (${_fmt(inv.totalAmount)}) must be submitted '
                  'to MyInvois within $hoursLeft hours or you may incur penalties. '
                  'Invoices ≥ RM 10,000 must be submitted within 72 hours of issuance.',
              type: 'deadline',
              category: AlertCategory.lhdn,
              severity: AlertSeverity.critical,
              deadline: submitDeadline,
              relatedInvoiceId: inv.id,
            ),
            existingIds: existingIds,
          );
          ops++;
        }
      }

      // ── LHDN: API submission failed (metadata flag) ────────────────────────
      final apiFailId = 'lhdn_apifail_${inv.id}';
      if ((inv.metadata?['submissionError'] != null) &&
          !existingIds.contains(apiFailId)) {
        final err = inv.metadata!['submissionError'] as String? ?? 'Network error';
        _queueAlert(
          batch: batch,
          alertId: apiFailId,
          userId: userId,
          alert: ComplianceAlert(
            id: apiFailId,
            title: 'API Submission Failed — ${inv.invoiceNumber}',
            message:
                'The MyInvois API submission for ${inv.invoiceNumber} failed: $err. '
                'Please retry the submission from the invoice detail screen.',
            type: 'error',
            category: AlertCategory.lhdn,
            severity: AlertSeverity.critical,
            deadline: now.add(const Duration(hours: 24)),
            relatedInvoiceId: inv.id,
          ),
          existingIds: existingIds,
        );
        ops++;
      }

      // ── Financial: overdue ────────────────────────────────────────────────
      final overdueId = 'financial_overdue_${inv.id}';
      if (inv.dueDate != null &&
          inv.dueDate!.isBefore(now) &&
          inv.complianceStatus != ComplianceStatus.cancelled &&
          !existingIds.contains(overdueId)) {
        final daysOverdue = now.difference(inv.dueDate!).inDays;
        _queueAlert(
          batch: batch,
          alertId: overdueId,
          userId: userId,
          alert: ComplianceAlert(
            id: overdueId,
            title: '${inv.invoiceNumber} Overdue by ${daysOverdue}d',
            message:
                'Invoice ${inv.invoiceNumber} for ${inv.buyer.name} '
                '(${_fmt(inv.totalAmount)}) was due ${_fmtDate(inv.dueDate!)} '
                'and is now $daysOverdue day${daysOverdue == 1 ? "" : "s"} overdue.',
            type: 'warning',
            category: AlertCategory.financial,
            severity: daysOverdue > 7 ? AlertSeverity.critical : AlertSeverity.high,
            deadline: now,
            relatedInvoiceId: inv.id,
          ),
          existingIds: existingIds,
        );
        ops++;
        totalOutstanding += inv.totalAmount;
      }

      // ── Financial: due within 3 days ──────────────────────────────────────
      final due3dId = 'financial_due3d_${inv.id}';
      if (inv.dueDate != null && !existingIds.contains(due3dId)) {
        final daysUntilDue = inv.dueDate!.difference(now).inDays;
        if (daysUntilDue >= 0 &&
            daysUntilDue <= 3 &&
            inv.complianceStatus != ComplianceStatus.cancelled) {
          _queueAlert(
            batch: batch,
            alertId: due3dId,
            userId: userId,
            alert: ComplianceAlert(
              id: due3dId,
              title:
                  '${inv.invoiceNumber} Due in $daysUntilDue Day${daysUntilDue == 1 ? "" : "s"}',
              message:
                  'Payment of ${_fmt(inv.totalAmount)} from ${inv.buyer.name} '
                  'is due on ${_fmtDate(inv.dueDate!)}. Follow up now to ensure '
                  'on-time collection.',
              type: 'warning',
              category: AlertCategory.financial,
              severity: daysUntilDue == 0 ? AlertSeverity.critical : AlertSeverity.high,
              deadline: inv.dueDate!,
              relatedInvoiceId: inv.id,
            ),
            existingIds: existingIds,
          );
          ops++;
        }
      }

      // ── Audit: edited after validation ────────────────────────────────────
      if (inv.submissionDate != null) {
        final auditEditId = 'audit_edited_${inv.id}';
        final wasEditedAfterSubmit =
            inv.updatedAt.isAfter(inv.submissionDate!.add(const Duration(minutes: 5)));
        if (wasEditedAfterSubmit &&
            (inv.complianceStatus == ComplianceStatus.submitted ||
                inv.complianceStatus == ComplianceStatus.valid) &&
            !existingIds.contains(auditEditId)) {
          _queueAlert(
            batch: batch,
            alertId: auditEditId,
            userId: userId,
            alert: ComplianceAlert(
              id: auditEditId,
              title: '${inv.invoiceNumber} Edited After Submission',
              message:
                  'Invoice ${inv.invoiceNumber} was modified on '
                  '${_fmtDate(inv.updatedAt)} after it was submitted to MyInvois. '
                  'If the changes affect taxable amounts, a cancellation and '
                  'resubmission may be required.',
              type: 'warning',
              category: AlertCategory.audit,
              severity: AlertSeverity.high,
              deadline: inv.updatedAt.add(const Duration(hours: 72)),
              relatedInvoiceId: inv.id,
            ),
            existingIds: existingIds,
          );
          ops++;
        }
      }

      // ── Accumulate monthly revenue ─────────────────────────────────────────
      if (!inv.issueDate.isBefore(thisMonthStart)) {
        monthRevenue += inv.totalAmount;
      } else if (!inv.issueDate.isBefore(lastMonthStart) &&
          inv.issueDate.isBefore(thisMonthStart)) {
        lastMonthRevenue += inv.totalAmount;
      }
    }

    // -- User-level financial alerts -----------------------------------------

    // Monthly summary (once per calendar month).
    final summaryId =
        'financial_summary_${userId}_${now.year}_${_pad(now.month)}';
    if (!existingIds.contains(summaryId)) {
      final revMsg = lastMonthRevenue > 0
          ? 'Revenue this month: ${_fmt(monthRevenue)} '
              '(${monthRevenue >= lastMonthRevenue ? "+" : ""}${_fmt(monthRevenue - lastMonthRevenue)} vs last month).'
          : 'Revenue recorded so far this month: ${_fmt(monthRevenue)}.';
      _queueAlert(
        batch: batch,
        alertId: summaryId,
        userId: userId,
        alert: ComplianceAlert(
          id: summaryId,
          title: 'Monthly Financial Summary — ${_monthName(now.month)} ${now.year}',
          message: '$revMsg Review outstanding invoices and ensure all '
              'qualifying transactions (≥ RM 10,000) have been submitted to MyInvois.',
          type: 'info',
          category: AlertCategory.financial,
          severity: AlertSeverity.low,
          deadline: DateTime(now.year, now.month + 1, 1)
              .subtract(const Duration(seconds: 1)),
        ),
        existingIds: existingIds,
      );
      ops++;
    }

    // Outstanding exceeds RM 50k threshold.
    const outstandingThreshold = 50000.0;
    final outstandingId = 'financial_outstanding_${userId}_${now.year}_${_pad(now.month)}';
    if (totalOutstanding >= outstandingThreshold &&
        !existingIds.contains(outstandingId)) {
      _queueAlert(
        batch: batch,
        alertId: outstandingId,
        userId: userId,
        alert: ComplianceAlert(
          id: outstandingId,
          title: 'Outstanding Receivables Exceed RM 50,000',
          message:
              'You have ${_fmt(totalOutstanding)} in overdue receivables this month. '
              'Consider issuing payment reminders or engaging a collections process.',
          type: 'warning',
          category: AlertCategory.financial,
          severity: AlertSeverity.high,
          deadline: DateTime(now.year, now.month + 1, 1),
        ),
        existingIds: existingIds,
      );
      ops++;
    }

    if (ops > 0) await batch.commit();
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Queue a single alert onto [batch] only when its ID is not already in [existingIds].
  void _queueAlert({
    required WriteBatch batch,
    required String alertId,
    required String userId,
    required ComplianceAlert alert,
    required Set<String> existingIds,
  }) {
    if (existingIds.contains(alertId)) return;
    batch.set(
      _db.collection(FirestoreCollections.complianceAlerts).doc(alertId),
      {
        'userId': userId,
        'title': alert.title,
        'message': alert.message,
        'type': alert.type,
        'category': alert.category.name,
        'severity': alert.severity.name,
        'deadline': Timestamp.fromDate(alert.deadline),
        'isRead': false,
        if (alert.relatedInvoiceId != null) 'relatedInvoiceId': alert.relatedInvoiceId,
        if (alert.metadata != null) 'metadata': alert.metadata,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }

  static String _fmt(double amount) =>
      'RM ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _pad(int v) => v.toString().padLeft(2, '0');

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static String _monthName(int m) => _months[m - 1];

  /// Mirror of [FirestoreInvoiceService._fromFirestoreMap] — converts
  /// [Timestamp] values to ISO strings so [Invoice.fromJson] works correctly.
  static Map<String, dynamic> _fromFirestoreMap(Map<String, dynamic> map) {
    Map<String, dynamic> _convert(Map<String, dynamic> src) {
      return src.map((k, v) {
        if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
        if (v is Map<String, dynamic>) return MapEntry(k, _convert(v));
        if (v is List) {
          return MapEntry(
            k,
            v.map((e) => e is Map<String, dynamic> ? _convert(e) : e).toList(),
          );
        }
        return MapEntry(k, v);
      });
    }

    return _convert(map);
  }
}
