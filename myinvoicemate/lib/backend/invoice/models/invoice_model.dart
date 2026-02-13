import 'package:json_annotation/json_annotation.dart';

part 'invoice_model.g.dart';

/// MyInvois e-Invoice Model based on LHDN requirements
@JsonSerializable(explicitToJson: true)
class Invoice {
  final String id; // Unique invoice ID
  final String invoiceNumber; // Sequential invoice number
  final InvoiceType type; // Invoice, Credit Note, Debit Note, etc.
  final DateTime issueDate;
  final DateTime? dueDate;
  final String currency; // MYR by default
  
  // Vendor (Supplier) Information
  final PartyInfo vendor;
  
  // Buyer (Customer) Information
  final PartyInfo buyer;
  
  // Line Items
  final List<InvoiceLineItem> lineItems;
  
  // Totals
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final double? discountAmount;
  
  // MyInvois Specific
  final String? tin; // Tax Identification Number
  final String? sst; // Sales and Service Tax ID
  final ComplianceStatus complianceStatus;
  final String? myInvoisReferenceId; // Reference from MyInvois system
  final DateTime? submissionDate;
  final bool isWithinRelaxationPeriod;
  final bool requiresSubmission; // Based on RM10k threshold
  
  // Metadata
  final String? notes;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy; // User ID
  final InvoiceSource source; // Voice, Receipt Scan, Manual

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.type,
    required this.issueDate,
    this.dueDate,
    this.currency = 'MYR',
    required this.vendor,
    required this.buyer,
    required this.lineItems,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    this.discountAmount,
    this.tin,
    this.sst,
    this.complianceStatus = ComplianceStatus.draft,
    this.myInvoisReferenceId,
    this.submissionDate,
    this.isWithinRelaxationPeriod = false,
    this.requiresSubmission = true,
    this.notes,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.source = InvoiceSource.manual,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) => _$InvoiceFromJson(json);
  Map<String, dynamic> toJson() => _$InvoiceToJson(this);

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    InvoiceType? type,
    DateTime? issueDate,
    DateTime? dueDate,
    String? currency,
    PartyInfo? vendor,
    PartyInfo? buyer,
    List<InvoiceLineItem>? lineItems,
    double? subtotal,
    double? taxAmount,
    double? totalAmount,
    double? discountAmount,
    String? tin,
    String? sst,
    ComplianceStatus? complianceStatus,
    String? myInvoisReferenceId,
    DateTime? submissionDate,
    bool? isWithinRelaxationPeriod,
    bool? requiresSubmission,
    String? notes,
    Map<String, dynamic>? metadata,
    DateTime? updatedAt,
    InvoiceSource? source,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      type: type ?? this.type,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      currency: currency ?? this.currency,
      vendor: vendor ?? this.vendor,
      buyer: buyer ?? this.buyer,
      lineItems: lineItems ?? this.lineItems,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      tin: tin ?? this.tin,
      sst: sst ?? this.sst,
      complianceStatus: complianceStatus ?? this.complianceStatus,
      myInvoisReferenceId: myInvoisReferenceId ?? this.myInvoisReferenceId,
      submissionDate: submissionDate ?? this.submissionDate,
      isWithinRelaxationPeriod: isWithinRelaxationPeriod ?? this.isWithinRelaxationPeriod,
      requiresSubmission: requiresSubmission ?? this.requiresSubmission,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: createdBy,
      source: source ?? this.source,
    );
  }
}

@JsonSerializable()
class PartyInfo {
  final String name;
  final String? tin; // Tax Identification Number
  final String? registrationNumber;
  final String? email;
  final String? phone;
  final Address address;
  final String? contactPerson;

  PartyInfo({
    required this.name,
    this.tin,
    this.registrationNumber,
    this.email,
    this.phone,
    required this.address,
    this.contactPerson,
  });

  factory PartyInfo.fromJson(Map<String, dynamic> json) => _$PartyInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PartyInfoToJson(this);
}

@JsonSerializable()
class Address {
  final String line1;
  final String? line2;
  final String? line3;
  final String city;
  final String state;
  final String postalCode;
  final String country; // MY for Malaysia

  Address({
    required this.line1,
    this.line2,
    this.line3,
    required this.city,
    required this.state,
    required this.postalCode,
    this.country = 'MY',
  });

  factory Address.fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);
  Map<String, dynamic> toJson() => _$AddressToJson(this);
}

@JsonSerializable()
class InvoiceLineItem {
  final String id;
  final String description;
  final double quantity;
  final String unit; // pcs, kg, hours, etc.
  final double unitPrice;
  final double subtotal;
  final double? discountAmount;
  final double? taxRate; // SST rate if applicable
  final double? taxAmount;
  final double totalAmount;
  final String? productCode;
  final TaxType taxType;

  InvoiceLineItem({
    required this.id,
    required this.description,
    required this.quantity,
    this.unit = 'pcs',
    required this.unitPrice,
    required this.subtotal,
    this.discountAmount,
    this.taxRate,
    this.taxAmount,
    required this.totalAmount,
    this.productCode,
    this.taxType = TaxType.none,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) => _$InvoiceLineItemFromJson(json);
  Map<String, dynamic> toJson() => _$InvoiceLineItemToJson(this);
}

enum InvoiceType {
  @JsonValue('invoice')
  invoice,
  @JsonValue('credit_note')
  creditNote,
  @JsonValue('debit_note')
  debitNote,
  @JsonValue('refund')
  refund,
}

enum ComplianceStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('validated')
  validated,
  @JsonValue('submitted')
  submitted,
  @JsonValue('accepted')
  accepted,
  @JsonValue('rejected')
  rejected,
  @JsonValue('cancelled')
  cancelled,
}

enum InvoiceSource {
  @JsonValue('manual')
  manual,
  @JsonValue('voice')
  voice,
  @JsonValue('receipt_scan')
  receiptScan,
  @JsonValue('import')
  import,
}

enum TaxType {
  @JsonValue('none')
  none,
  @JsonValue('sst_6')
  sst6, // 6% SST
  @JsonValue('sst_10')
  sst10, // 10% SST
  @JsonValue('exempt')
  exempt,
  @JsonValue('zero_rated')
  zeroRated,
}
