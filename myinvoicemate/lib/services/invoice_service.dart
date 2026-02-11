import 'package:uuid/uuid.dart';
import '../models/invoice_model.dart';
import '../utils/constants.dart';

class InvoiceService {
  final List<InvoiceModel> _mockInvoices = [];
  final _uuid = const Uuid();

  // Get all invoices for current user
  Future<List<InvoiceModel>> getInvoices() async {
    await Future.delayed(const Duration(seconds: 1));

    // Generate mock data if empty
    if (_mockInvoices.isEmpty) {
      _generateMockInvoices();
    }

    return _mockInvoices;
  }

  // Get invoice by ID
  Future<InvoiceModel?> getInvoiceById(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockInvoices.firstWhere((inv) => inv.id == id);
  }

  // Create new invoice
  Future<InvoiceModel> createInvoice(InvoiceModel invoice) async {
    await Future.delayed(const Duration(seconds: 1));
    _mockInvoices.add(invoice);
    return invoice;
  }

  // Update invoice
  Future<InvoiceModel> updateInvoice(InvoiceModel invoice) async {
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
    final updatedInvoice = InvoiceModel(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      sellerId: invoice.sellerId,
      sellerName: invoice.sellerName,
      sellerTin: invoice.sellerTin,
      buyerId: invoice.buyerId,
      buyerName: invoice.buyerName,
      buyerTin: invoice.buyerTin,
      buyerAddress: invoice.buyerAddress,
      issueDate: invoice.issueDate,
      lineItems: invoice.lineItems,
      subtotal: invoice.subtotal,
      taxAmount: invoice.taxAmount,
      totalAmount: invoice.totalAmount,
      status: AppConstants.statusSubmitted,
      myInvoisId: 'MYI${DateTime.now().millisecondsSinceEpoch}',
      qrCode: 'QR_${_uuid.v4()}',
      createdAt: invoice.createdAt,
      submittedAt: DateTime.now(),
    );

    await updateInvoice(updatedInvoice);

    return {
      'success': true,
      'myInvoisId': updatedInvoice.myInvoisId,
      'qrCode': updatedInvoice.qrCode,
      'message': 'Invoice successfully submitted to MyInvois',
    };
  }

  // Generate mock invoices
  void _generateMockInvoices() {
    _mockInvoices.addAll([
      InvoiceModel(
        id: _uuid.v4(),
        invoiceNumber: 'INV-2026-001',
        sellerId: 'user123',
        sellerName: 'SME Trading Sdn Bhd',
        sellerTin: 'C12345678900',
        buyerId: 'buyer1',
        buyerName: 'ABC Corporation',
        buyerTin: 'C98765432100',
        buyerAddress: 'Petaling Jaya, Selangor',
        issueDate: DateTime.now().subtract(const Duration(days: 5)),
        lineItems: [
          InvoiceLineItem(
            description: 'Product A',
            quantity: 10,
            unitPrice: 1200.00,
            taxRate: 0.0,
            amount: 12000.00,
          ),
        ],
        subtotal: 12000.00,
        taxAmount: 0.0,
        totalAmount: 12000.00,
        status: AppConstants.statusSubmitted,
        myInvoisId: 'MYI1234567890',
        qrCode: 'QR_ABC123',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        submittedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      InvoiceModel(
        id: _uuid.v4(),
        invoiceNumber: 'INV-2026-002',
        sellerId: 'user123',
        sellerName: 'SME Trading Sdn Bhd',
        sellerTin: 'C12345678900',
        buyerId: 'buyer2',
        buyerName: 'XYZ Enterprise',
        buyerTin: 'C11223344556',
        buyerAddress: 'Shah Alam, Selangor',
        issueDate: DateTime.now().subtract(const Duration(days: 2)),
        lineItems: [
          InvoiceLineItem(
            description: 'Service Package',
            quantity: 1,
            unitPrice: 5500.00,
            taxRate: 0.0,
            amount: 5500.00,
          ),
        ],
        subtotal: 5500.00,
        taxAmount: 0.0,
        totalAmount: 5500.00,
        status: AppConstants.statusDraft,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      InvoiceModel(
        id: _uuid.v4(),
        invoiceNumber: 'INV-2026-003',
        sellerId: 'user123',
        sellerName: 'SME Trading Sdn Bhd',
        sellerTin: 'C12345678900',
        buyerId: 'buyer3',
        buyerName: 'Tech Solutions Ltd',
        buyerTin: 'C55667788990',
        buyerAddress: 'Cyberjaya, Selangor',
        issueDate: DateTime.now(),
        lineItems: [
          InvoiceLineItem(
            description: 'Consulting Services',
            quantity: 20,
            unitPrice: 800.00,
            taxRate: 0.0,
            amount: 16000.00,
          ),
        ],
        subtotal: 16000.00,
        taxAmount: 0.0,
        totalAmount: 16000.00,
        status: AppConstants.statusPending,
        createdAt: DateTime.now(),
      ),
    ]);
  }
}
