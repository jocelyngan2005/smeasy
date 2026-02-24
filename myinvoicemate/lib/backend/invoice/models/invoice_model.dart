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
  
  // Shipping Recipient (optional, for Annexure to e-Invoice)
  final PartyInfo? shippingRecipient;
  
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
    this.shippingRecipient,
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
    PartyInfo? shippingRecipient,
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
      shippingRecipient: shippingRecipient ?? this.shippingRecipient,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: createdBy,
      source: source ?? this.source,
    );
  }
  
  /// Validates if shipping recipient information is complete (when provided)
  bool get hasValidShippingRecipient {
    if (shippingRecipient == null) return true; // Optional field
    return shippingRecipient!.name.isNotEmpty &&
        (shippingRecipient!.tin?.isNotEmpty ?? false) &&
        (shippingRecipient!.identificationNumber?.isNotEmpty ?? false) &&
        shippingRecipient!.address.line1.isNotEmpty;
  }
}

@JsonSerializable(explicitToJson: true)
class PartyInfo {
  final String name;
  final String? tin; // Tax Identification Number
  final String? registrationNumber; // Company registration number
  
  // e-Invoice Compliance Fields (LHDN 4.6)
  final String? identificationNumber; // MyKad/MyTentera/Passport/MyPR/MyKAS (for individuals)
  final String? contactNumber; // Required contact number for buyers
  final String? sstNumber; // SST Registration Number (use "NA" if not registered)
  
  final String? email;
  final String? phone; // Kept for backward compatibility
  final Address address;
  final String? contactPerson;
  final String? msicCode; // Malaysia Standard Industrial Classification Code
  final String? businessActivityDescription; // MSIC business activity description

  PartyInfo({
    required this.name,
    this.tin,
    this.registrationNumber,
    this.identificationNumber,
    this.contactNumber,
    this.sstNumber,
    this.email,
    this.phone,
    required this.address,
    this.contactPerson,
    this.msicCode,
    this.businessActivityDescription,
  });

  factory PartyInfo.fromJson(Map<String, dynamic> json) => _$PartyInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PartyInfoToJson(this);

  PartyInfo copyWith({
    String? name,
    String? tin,
    String? registrationNumber,
    String? identificationNumber,
    String? contactNumber,
    String? sstNumber,
    String? email,
    String? phone,
    Address? address,
    String? contactPerson,
    String? msicCode,
    String? businessActivityDescription,
  }) {
    return PartyInfo(
      name: name ?? this.name,
      tin: tin ?? this.tin,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      identificationNumber: identificationNumber ?? this.identificationNumber,
      contactNumber: contactNumber ?? this.contactNumber,
      sstNumber: sstNumber ?? this.sstNumber,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      msicCode: msicCode ?? this.msicCode,
      businessActivityDescription: businessActivityDescription ?? this.businessActivityDescription,
    );
  }

  /// Validates if buyer information meets e-Invoice requirements
  bool get hasValidBuyerInfo {
    return name.isNotEmpty &&
        (tin?.isNotEmpty ?? false) &&
        (identificationNumber?.isNotEmpty ?? identificationNumber == '000000000000') &&
        address.line1.isNotEmpty &&
        (contactNumber?.isNotEmpty ?? false) &&
        (sstNumber?.isNotEmpty ?? false);
  }

  /// Helper for default identification number when only TIN is provided
  static String getDefaultIdentificationNumber() => '000000000000';
  
  /// Helper for default TIN when only MyKad is provided (Malaysian individuals)
  static String getDefaultTinForMyKad() => 'EI00000000010';
  
  /// Helper for default SST number when not registered
  static String getDefaultSstNumber() => 'NA';
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

  Address copyWith({
    String? line1,
    String? line2,
    String? line3,
    String? city,
    String? state,
    String? postalCode,
    String? country,
  }) {
    return Address(
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      line3: line3 ?? this.line3,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
    );
  }
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
  final String? classification; // IRBM 3-digit classification code (e.g. '022')
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
    this.classification,
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
  @JsonValue('submitted')
  submitted,
  @JsonValue('valid')
  valid,
  @JsonValue('invalid')
  invalid,
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
