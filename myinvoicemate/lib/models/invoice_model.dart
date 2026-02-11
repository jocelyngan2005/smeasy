class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String sellerId;
  final String sellerName;
  final String sellerTin;
  final String buyerId;
  final String buyerName;
  final String buyerTin;
  final String buyerAddress;
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
    required this.buyerAddress,
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
      buyerAddress: json['buyerAddress'] ?? '',
      issueDate: DateTime.parse(json['issueDate'] ?? DateTime.now().toIso8601String()),
      lineItems: (json['lineItems'] as List?)
              ?.map((item) => InvoiceLineItem.fromJson(item))
              .toList() ??
          [],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      taxAmount: (json['taxAmount'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      status: json['status'] ?? 'draft',
      myInvoisId: json['myInvoisId'],
      qrCode: json['qrCode'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      submittedAt: json['submittedAt'] != null ? DateTime.parse(json['submittedAt']) : null,
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
      'buyerAddress': buyerAddress,
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
