/// Adapter/Helper functions to convert between old frontend model structure
/// and new backend model structure during migration period
///
/// Use these helpers in frontend code until full migration to backend models

import 'invoice_model.dart';

/// Helper extension to create Invoice from simple flat structure
/// (Compatibility layer for old frontend code)
extension InvoiceBuilder on Invoice {
  /// Create Invoice using simplified parameters (old frontend style)
  static Invoice fromSimpleData({
    required String id,
    required String invoiceNumber,
    required String sellerId,
    required String sellerName,
    required String sellerTin,
    String? sellerEmail,
    String? sellerPhone,
    String? sellerAddress1,
    String? sellerAddress2,
    String? sellerCity,
    String? sellerState,
    String? sellerPostalCode,
    required String buyerId,
    required String buyerName,
    required String buyerTin,
    String? buyerEmail,
    String? buyerPhone,
    String? buyerAddress1,
    String? buyerAddress2,
    String? buyerCity,
    String? buyerState,
    String? buyerPostalCode,
    required DateTime issueDate,
    DateTime? dueDate,
    required List<InvoiceLineItem> lineItems,
    required double subtotal,
    required double taxAmount,
    required double totalAmount,
    String status = 'draft',
    required String createdBy,
    InvoiceSource source = InvoiceSource.manual,
    String? notes,
  }) {
    // Map status string to ComplianceStatus enum
    ComplianceStatus complianceStatus;
    switch (status.toLowerCase()) {
      case 'submitted':
        complianceStatus = ComplianceStatus.submitted;
        break;
      case 'accepted':
        complianceStatus = ComplianceStatus.accepted;
        break;
      case 'rejected':
        complianceStatus = ComplianceStatus.rejected;
        break;
      case 'validated':
        complianceStatus = ComplianceStatus.validated;
        break;
      default:
        complianceStatus = ComplianceStatus.draft;
    }

    // Create vendor PartyInfo
    final vendor = PartyInfo(
      name: sellerName,
      tin: sellerTin,
      registrationNumber: sellerId != 'user123' ? sellerId : null,
      email: sellerEmail,
      phone: sellerPhone,
      address: Address(
        line1: sellerAddress1 ?? 'N/A',
        line2: sellerAddress2,
        city: sellerCity ?? 'Unknown',
        state: sellerState ?? 'Unknown',
        postalCode: sellerPostalCode ?? '00000',
      ),
    );

    // Create buyer PartyInfo
    final buyer = PartyInfo(
      name: buyerName,
      tin: buyerTin,
      registrationNumber: buyerId.isNotEmpty ? buyerId : null,
      email: buyerEmail,
      phone: buyerPhone,
      address: Address(
        line1: buyerAddress1 ?? 'N/A',
        line2: buyerAddress2,
        city: buyerCity ?? 'Unknown',
        state: buyerState ?? 'Unknown',
        postalCode: buyerPostalCode ?? '00000',
      ),
    );

    final now = DateTime.now();
    final requiresSubmission = totalAmount >= 10000.0;

    return Invoice(
      id: id,
      invoiceNumber: invoiceNumber,
      type: InvoiceType.invoice,
      issueDate: issueDate,
      dueDate: dueDate,
      vendor: vendor,
      buyer: buyer,
      lineItems: lineItems,
      subtotal: subtotal,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      tin: sellerTin,
      complianceStatus: complianceStatus,
      requiresSubmission: requiresSubmission,
      isWithinRelaxationPeriod: false,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
      source: source,
    );
  }
}

/// Helper to create InvoiceLineItem with simplified parameters
class InvoiceLineItemHelper {
  /// Create line item with automatic calculation
  static InvoiceLineItem createSimple({
    required String description,
    required double quantity,
    required double unitPrice,
    double? taxRate,
    String unit = 'pcs',
    String? productCode,
  }) {
    final id = 'item_${DateTime.now().millisecondsSinceEpoch}';
    final subtotal = quantity * unitPrice;
    final taxAmount = taxRate != null ? subtotal * (taxRate / 100) : 0.0;
    final totalAmount = subtotal + taxAmount;

    TaxType taxType = TaxType.none;
    if (taxRate == 6.0) {
      taxType = TaxType.sst6;
    } else if (taxRate == 10.0) {
      taxType = TaxType.sst10;
    } else if (taxRate == 0.0) {
      taxType = TaxType.zeroRated;
    }

    return InvoiceLineItem(
      id: id,
      description: description,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      productCode: productCode,
      taxType: taxType,
    );
  }
}

/// Extension methods to extract old-style flat data from Invoice
extension InvoiceCompat on Invoice {
  // Seller (Vendor) getters for backwards compatibility
  String get sellerId => vendor.registrationNumber ?? createdBy;
  String get sellerName => vendor.name;
  String get sellerTin => vendor.tin ?? tin ?? '';
  String? get sellerEmail => vendor.email;
  String? get sellerPhone => vendor.phone;
  String get sellerAddress => 
      '${vendor.address.line1}${vendor.address.line2 != null ? ', ${vendor.address.line2}' : ''}';
  
  // Buyer getters for backwards compatibility
  String get buyerId => buyer.registrationNumber ?? '';
  String get buyerName => buyer.name;
  String get buyerTin => buyer.tin ?? '';
  String? get buyerEmail => buyer.email;
  String? get buyerPhone => buyer.phone;
  String get buyerAddress => 
      '${buyer.address.line1}${buyer.address.line2 != null ? ', ${buyer.address.line2}' : ''}, ${buyer.address.city}, ${buyer.address.state} ${buyer.address.postalCode}';
  
  // Status for backwards compatibility
  String get status {
    switch (complianceStatus) {
      case ComplianceStatus.draft:
        return 'draft';
      case ComplianceStatus.validated:
        return 'validated';
      case ComplianceStatus.submitted:
        return 'submitted';
      case ComplianceStatus.accepted:
        return 'accepted';
      case ComplianceStatus.rejected:
        return 'rejected';
      case ComplianceStatus.cancelled:
        return 'cancelled';
    }
  }
  
  // Submission status
  DateTime? get submittedAt => submissionDate;
  String? get myInvoisId => myInvoisReferenceId;
}
