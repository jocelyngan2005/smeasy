class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String sellerId;
  final String sellerName;
  final String sellerTin;
  final String buyerId;
  final String buyerName;
  final String buyerTin;
  // Buyer's Registration / Identification Number / Passport Number
  // For Malaysian: MyKad/MyTentera, For non-Malaysian: Passport/MyPR/MyKAS
  // Input "000000000000" if only TIN provided
  final String buyerRegistrationNumber;
  final String buyerAddress;
  // Buyer's Contact Number
  final String buyerContactNumber;
  // Buyer's SST Registration Number (input "NA" if not registered)
  final String buyerSstNumber;

  // Shipping Recipient Details (optional, for Annexure to e-Invoice)
  final String? shippingRecipientName;
  final String? shippingRecipientTin;
  // Shipping Recipient's Registration / Identification Number / Passport Number
  final String? shippingRecipientRegistrationNumber;
  final String? shippingRecipientAddress;

  final DateTime issueDate;
  final List<InvoiceLineItem> lineItems;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final String status;
  final String? myInvoisId;
  final String? qrCode;
  final DateTime createdAt;
  final DateTime? submittedAt;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.sellerId,
    required this.sellerName,
    required this.sellerTin,
    required this.buyerId,
    required this.buyerName,
    required this.buyerTin,
    required this.buyerRegistrationNumber,
    required this.buyerAddress,
    required this.buyerContactNumber,
    required this.buyerSstNumber,
    this.shippingRecipientName,
    this.shippingRecipientTin,
    this.shippingRecipientRegistrationNumber,
    this.shippingRecipientAddress,
    required this.issueDate,
    required this.lineItems,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.status,
    this.myInvoisId,
    this.qrCode,
    required this.createdAt,
    this.submittedAt,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      sellerId: json['sellerId'] ?? '',
      sellerName: json['sellerName'] ?? '',
      sellerTin: json['sellerTin'] ?? '',
      buyerId: json['buyerId'] ?? '',
      buyerName: json['buyerName'] ?? '',
      buyerTin: json['buyerTin'] ?? '',
      buyerRegistrationNumber:
          json['buyerRegistrationNumber'] ?? '000000000000',
      buyerAddress: json['buyerAddress'] ?? '',
      buyerContactNumber: json['buyerContactNumber'] ?? '',
      buyerSstNumber: json['buyerSstNumber'] ?? 'NA',
      shippingRecipientName: json['shippingRecipientName'],
      shippingRecipientTin: json['shippingRecipientTin'],
      shippingRecipientRegistrationNumber:
          json['shippingRecipientRegistrationNumber'],
      shippingRecipientAddress: json['shippingRecipientAddress'],
      issueDate: DateTime.parse(
        json['issueDate'] ?? DateTime.now().toIso8601String(),
      ),
      lineItems:
          (json['lineItems'] as List?)
              ?.map((item) => InvoiceLineItem.fromJson(item))
              .toList() ??
          [],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      taxAmount: (json['taxAmount'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      status: json['status'] ?? 'draft',
      myInvoisId: json['myInvoisId'],
      qrCode: json['qrCode'],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerTin': sellerTin,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerTin': buyerTin,
      'buyerRegistrationNumber': buyerRegistrationNumber,
      'buyerAddress': buyerAddress,
      'buyerContactNumber': buyerContactNumber,
      'buyerSstNumber': buyerSstNumber,
      'shippingRecipientName': shippingRecipientName,
      'shippingRecipientTin': shippingRecipientTin,
      'shippingRecipientRegistrationNumber':
          shippingRecipientRegistrationNumber,
      'shippingRecipientAddress': shippingRecipientAddress,
      'issueDate': issueDate.toIso8601String(),
      'lineItems': lineItems.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'status': status,
      'myInvoisId': myInvoisId,
      'qrCode': qrCode,
      'createdAt': createdAt.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
    };
  }

  bool get requiresMyInvoisSubmission => totalAmount >= 10000.0;

  /// Validates if buyer information meets e-Invoice requirements
  bool get hasValidBuyerInfo {
    return buyerName.isNotEmpty &&
        buyerTin.isNotEmpty &&
        buyerRegistrationNumber.isNotEmpty &&
        buyerAddress.isNotEmpty &&
        buyerContactNumber.isNotEmpty &&
        buyerSstNumber.isNotEmpty;
  }

  /// Validates if shipping recipient information is complete (when provided)
  bool get hasValidShippingRecipient {
    if (shippingRecipientName == null) return true; // Optional field
    return shippingRecipientName!.isNotEmpty &&
        (shippingRecipientTin?.isNotEmpty ?? false) &&
        (shippingRecipientRegistrationNumber?.isNotEmpty ?? false) &&
        (shippingRecipientAddress?.isNotEmpty ?? false);
  }

  /// Helper to create invoice with default e-Invoice values
  /// For Malaysian individuals who only provide MyKad/MyTentera
  static String getDefaultTinForMyKad() => 'EI00000000010';

  /// Helper to create invoice with default registration number
  /// When only TIN is provided
  static String getDefaultRegistrationNumber() => '000000000000';
}

class InvoiceLineItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double taxRate;
  final double amount;

  InvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.taxRate = 0.0,
    required this.amount,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      description: json['description'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      taxRate: (json['taxRate'] ?? 0).toDouble(),
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'taxRate': taxRate,
      'amount': amount,
    };
  }
}
