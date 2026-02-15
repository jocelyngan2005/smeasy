import 'package:uuid/uuid.dart';
import '../models/invoice_model.dart';
import '../models/invoice_adapter.dart';
import '../../../utils/constants.dart';

class InvoiceService {
  final List<Invoice> _mockInvoices = [];
  final _uuid = const Uuid();

  // Get all invoices for current user
  Future<List<Invoice>> getInvoices() async {
    await Future.delayed(const Duration(seconds: 1));

    // Generate mock data if empty
    if (_mockInvoices.isEmpty) {
      _generateMockInvoices();
    }

    return _mockInvoices;
  }

  // Get invoice by ID
  Future<Invoice?> getInvoiceById(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockInvoices.firstWhere((inv) => inv.id == id);
  }

  // Create new invoice
  Future<Invoice> createInvoice(Invoice invoice) async {
    await Future.delayed(const Duration(seconds: 1));
    _mockInvoices.add(invoice);
    return invoice;
  }

  // Update invoice
  Future<Invoice> updateInvoice(Invoice invoice) async {
    await Future.delayed(const Duration(seconds: 1));
    final index = _mockInvoices.indexWhere((inv) => inv.id == invoice.id);
    if (index != -1) {
      _mockInvoices[index] = invoice;
    }
    return invoice;
  }

  // Delete invoice
  Future<bool> deleteInvoice(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockInvoices.removeWhere((inv) => inv.id == id);
    return true;
  }

  // Submit to MyInvois (Mock)
  Future<Map<String, dynamic>> submitToMyInvois(String invoiceId) async {
    await Future.delayed(const Duration(seconds: 3)); // Simulate API call

    final invoice = await getInvoiceById(invoiceId);
    if (invoice == null) {
      throw Exception('Invoice not found');
    }

    // Mock MyInvois response
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

  // Generate mock invoices
  void _generateMockInvoices() {
    final lineItems1 = [
      InvoiceLineItemHelper.createSimple(
        description: 'Product A',
        quantity: 10,
        unitPrice: 1200.00,
      ),
    ];

    final lineItems2 = [
      InvoiceLineItemHelper.createSimple(
        description: 'Service Package',
        quantity: 1,
        unitPrice: 5500.00,
      ),
    ];

    final lineItems3 = [
      InvoiceLineItemHelper.createSimple(
        description: 'Consulting Services',
        quantity: 20,
        unitPrice: 800.00,
      ),
    ];

    _mockInvoices.addAll([
      InvoiceBuilder.fromSimpleData(
        id: _uuid.v4(),
        invoiceNumber: 'INV-2026-001',
        sellerId: 'user123',
        sellerName: 'SME Trading Sdn Bhd',
        sellerTin: 'C12345678900',
        buyerId: 'buyer1',
        buyerName: 'ABC Corporation',
        buyerTin: 'C98765432100',
        buyerAddress1: 'Petaling Jaya',
        buyerCity: 'Petaling Jaya',
        buyerState: 'Selangor',
        buyerPostalCode: '47400',
        issueDate: DateTime.now().subtract(const Duration(days: 5)),
        lineItems: lineItems1,
        subtotal: 12000.00,
        taxAmount: 0.0,
        totalAmount: 12000.00,
        status: AppConstants.statusSubmitted,
        createdBy: 'user123',
      ).copyWith(
        myInvoisReferenceId: 'MYI1234567890',
        submissionDate: DateTime.now().subtract(const Duration(days: 4)),
      ),
      InvoiceBuilder.fromSimpleData(
        id: _uuid.v4(),
        invoiceNumber: 'INV-2026-002',
        sellerId: 'user123',
        sellerName: 'SME Trading Sdn Bhd',
        sellerTin: 'C12345678900',
        buyerId: 'buyer2',
        buyerName: 'XYZ Enterprise',
        buyerTin: 'C11223344556',
        buyerAddress1: 'Shah Alam',
        buyerCity: 'Shah Alam',
        buyerState: 'Selangor',
        buyerPostalCode: '40000',
        issueDate: DateTime.now().subtract(const Duration(days: 2)),
        lineItems: lineItems2,
        subtotal: 5500.00,
        taxAmount: 0.0,
        totalAmount: 5500.00,
        status: AppConstants.statusDraft,
        createdBy: 'user123',
      ),
      InvoiceBuilder.fromSimpleData(
        id: _uuid.v4(),
        invoiceNumber: 'INV-2026-003',
        sellerId: 'user123',
        sellerName: 'SME Trading Sdn Bhd',
        sellerTin: 'C12345678900',
        buyerId: 'buyer3',
        buyerName: 'Tech Solutions Ltd',
        buyerTin: 'C55667788990',
        buyerAddress1: 'Cyberjaya',
        buyerCity: 'Cyberjaya',
        buyerState: 'Selangor',
        buyerPostalCode: '63000',
        issueDate: DateTime.now(),
        lineItems: lineItems3,
        subtotal: 16000.00,
        taxAmount: 0.0,
        totalAmount: 16000.00,
        status: AppConstants.statusPending,
        createdBy: 'user123',
      ),
    ]);
  }
}
