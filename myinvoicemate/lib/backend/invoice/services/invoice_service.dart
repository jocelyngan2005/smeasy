import 'package:uuid/uuid.dart';
import '../models/invoice_model.dart';
import 'firestore_invoice_service.dart';
import '../../../backend/auth/services/auth_service.dart';

/// Thin wrapper around [FirestoreInvoiceService] that resolves the current
/// user automatically. All persistent operations go to Firestore.
class InvoiceService {
  InvoiceService() : _firestore = FirestoreInvoiceService();

  final FirestoreInvoiceService _firestore;
  final _uuid = const Uuid();

  String get _uid => AuthService.instance.currentUserId ?? '';

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  Future<List<Invoice>> getInvoices() => _firestore.getInvoicesByUser(_uid);

  Future<Invoice?> getInvoiceById(String id) => _firestore.getInvoice(id);

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  Future<Invoice> createInvoice(Invoice invoice) async {
    await _firestore.saveInvoice(invoice);
    return invoice;
  }

  Future<Invoice> updateInvoice(Invoice invoice) async {
    await _firestore.updateInvoice(invoice);
    return invoice;
  }

  Future<bool> deleteInvoice(String id) async {
    await _firestore.deleteInvoice(id);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Submit to MyInvois (mocked — LHDN API not yet integrated)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> submitToMyInvois(String invoiceId) async {
    await Future.delayed(const Duration(seconds: 3)); // Simulate API call

    final invoice = await getInvoiceById(invoiceId);
    if (invoice == null) throw Exception('Invoice not found');

    final updatedInvoice = invoice.copyWith(
      complianceStatus: ComplianceStatus.submitted,
      myInvoisReferenceId: 'MYI${DateTime.now().millisecondsSinceEpoch}',
      submissionDate: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await updateInvoice(updatedInvoice);

    return {
      'success': true,
      'myInvoisId': updatedInvoice.myInvoisReferenceId,
      'qrCode': 'QR_${_uuid.v4()}',
      'message': 'Invoice successfully submitted to MyInvois',
    };
  }
}
