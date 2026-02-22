// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Invoice _$InvoiceFromJson(Map<String, dynamic> json) => Invoice(
  id: json['id'] as String,
  invoiceNumber: json['invoiceNumber'] as String,
  type: $enumDecode(_$InvoiceTypeEnumMap, json['type']),
  issueDate: DateTime.parse(json['issueDate'] as String),
  dueDate: json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String),
  currency: json['currency'] as String? ?? 'MYR',
  vendor: PartyInfo.fromJson(json['vendor'] as Map<String, dynamic>),
  buyer: PartyInfo.fromJson(json['buyer'] as Map<String, dynamic>),
  lineItems: (json['lineItems'] as List<dynamic>)
      .map((e) => InvoiceLineItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  subtotal: (json['subtotal'] as num).toDouble(),
  taxAmount: (json['taxAmount'] as num).toDouble(),
  totalAmount: (json['totalAmount'] as num).toDouble(),
  discountAmount: (json['discountAmount'] as num?)?.toDouble(),
  tin: json['tin'] as String?,
  sst: json['sst'] as String?,
  complianceStatus:
      $enumDecodeNullable(
        _$ComplianceStatusEnumMap,
        json['complianceStatus'],
      ) ??
      ComplianceStatus.draft,
  myInvoisReferenceId: json['myInvoisReferenceId'] as String?,
  submissionDate: json['submissionDate'] == null
      ? null
      : DateTime.parse(json['submissionDate'] as String),
  isWithinRelaxationPeriod: json['isWithinRelaxationPeriod'] as bool? ?? false,
  requiresSubmission: json['requiresSubmission'] as bool? ?? true,
  shippingRecipient: json['shippingRecipient'] == null
      ? null
      : PartyInfo.fromJson(json['shippingRecipient'] as Map<String, dynamic>),
  notes: json['notes'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  createdBy: json['createdBy'] as String,
  source:
      $enumDecodeNullable(_$InvoiceSourceEnumMap, json['source']) ??
      InvoiceSource.manual,
);

Map<String, dynamic> _$InvoiceToJson(Invoice instance) => <String, dynamic>{
  'id': instance.id,
  'invoiceNumber': instance.invoiceNumber,
  'type': _$InvoiceTypeEnumMap[instance.type]!,
  'issueDate': instance.issueDate.toIso8601String(),
  'dueDate': instance.dueDate?.toIso8601String(),
  'currency': instance.currency,
  'vendor': instance.vendor.toJson(),
  'buyer': instance.buyer.toJson(),
  'lineItems': instance.lineItems.map((e) => e.toJson()).toList(),
  'subtotal': instance.subtotal,
  'taxAmount': instance.taxAmount,
  'totalAmount': instance.totalAmount,
  'discountAmount': instance.discountAmount,
  'tin': instance.tin,
  'sst': instance.sst,
  'complianceStatus': _$ComplianceStatusEnumMap[instance.complianceStatus]!,
  'myInvoisReferenceId': instance.myInvoisReferenceId,
  'submissionDate': instance.submissionDate?.toIso8601String(),
  'isWithinRelaxationPeriod': instance.isWithinRelaxationPeriod,
  'requiresSubmission': instance.requiresSubmission,
  'shippingRecipient': instance.shippingRecipient?.toJson(),
  'notes': instance.notes,
  'metadata': instance.metadata,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'createdBy': instance.createdBy,
  'source': _$InvoiceSourceEnumMap[instance.source]!,
};

const _$InvoiceTypeEnumMap = {
  InvoiceType.invoice: 'invoice',
  InvoiceType.creditNote: 'credit_note',
  InvoiceType.debitNote: 'debit_note',
  InvoiceType.refund: 'refund',
};

const _$ComplianceStatusEnumMap = {
  ComplianceStatus.draft: 'draft',
  ComplianceStatus.submitted: 'submitted',
  ComplianceStatus.valid: 'valid',
  ComplianceStatus.invalid: 'invalid',
  ComplianceStatus.cancelled: 'cancelled',
};

const _$InvoiceSourceEnumMap = {
  InvoiceSource.manual: 'manual',
  InvoiceSource.voice: 'voice',
  InvoiceSource.receiptScan: 'receipt_scan',
  InvoiceSource.import: 'import',
};

PartyInfo _$PartyInfoFromJson(Map<String, dynamic> json) => PartyInfo(
  name: json['name'] as String,
  tin: json['tin'] as String?,
  registrationNumber: json['registrationNumber'] as String?,
  identificationNumber: json['identificationNumber'] as String?,
  contactNumber: json['contactNumber'] as String?,
  sstNumber: json['sstNumber'] as String?,
  email: json['email'] as String?,
  phone: json['phone'] as String?,
  address: Address.fromJson(json['address'] as Map<String, dynamic>),
  contactPerson: json['contactPerson'] as String?,
);

Map<String, dynamic> _$PartyInfoToJson(PartyInfo instance) => <String, dynamic>{
  'name': instance.name,
  'tin': instance.tin,
  'registrationNumber': instance.registrationNumber,
  'identificationNumber': instance.identificationNumber,
  'contactNumber': instance.contactNumber,
  'sstNumber': instance.sstNumber,
  'email': instance.email,
  'phone': instance.phone,
  'address': instance.address,
  'contactPerson': instance.contactPerson,
};

Address _$AddressFromJson(Map<String, dynamic> json) => Address(
  line1: json['line1'] as String,
  line2: json['line2'] as String?,
  line3: json['line3'] as String?,
  city: json['city'] as String,
  state: json['state'] as String,
  postalCode: json['postalCode'] as String,
  country: json['country'] as String? ?? 'MY',
);

Map<String, dynamic> _$AddressToJson(Address instance) => <String, dynamic>{
  'line1': instance.line1,
  'line2': instance.line2,
  'line3': instance.line3,
  'city': instance.city,
  'state': instance.state,
  'postalCode': instance.postalCode,
  'country': instance.country,
};

InvoiceLineItem _$InvoiceLineItemFromJson(Map<String, dynamic> json) =>
    InvoiceLineItem(
      id: json['id'] as String,
      description: json['description'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'pcs',
      unitPrice: (json['unitPrice'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble(),
      taxRate: (json['taxRate'] as num?)?.toDouble(),
      taxAmount: (json['taxAmount'] as num?)?.toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      productCode: json['productCode'] as String?,
      taxType:
          $enumDecodeNullable(_$TaxTypeEnumMap, json['taxType']) ??
          TaxType.none,
    );

Map<String, dynamic> _$InvoiceLineItemToJson(InvoiceLineItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'description': instance.description,
      'quantity': instance.quantity,
      'unit': instance.unit,
      'unitPrice': instance.unitPrice,
      'subtotal': instance.subtotal,
      'discountAmount': instance.discountAmount,
      'taxRate': instance.taxRate,
      'taxAmount': instance.taxAmount,
      'totalAmount': instance.totalAmount,
      'productCode': instance.productCode,
      'taxType': _$TaxTypeEnumMap[instance.taxType]!,
    };

const _$TaxTypeEnumMap = {
  TaxType.none: 'none',
  TaxType.sst6: 'sst_6',
  TaxType.sst10: 'sst_10',
  TaxType.exempt: 'exempt',
  TaxType.zeroRated: 'zero_rated',
};
