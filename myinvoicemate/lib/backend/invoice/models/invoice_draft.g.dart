// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_draft.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvoiceDraft _$InvoiceDraftFromJson(Map<String, dynamic> json) => InvoiceDraft(
  invoiceNumber: json['invoiceNumber'] as String?,
  type:
      $enumDecodeNullable(_$InvoiceTypeEnumMap, json['type']) ??
      InvoiceType.invoice,
  issueDate: json['issueDate'] == null
      ? null
      : DateTime.parse(json['issueDate'] as String),
  dueDate: json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String),
  vendor: json['vendor'] == null
      ? null
      : PartyInfoDraft.fromJson(json['vendor'] as Map<String, dynamic>),
  buyer: json['buyer'] == null
      ? null
      : PartyInfoDraft.fromJson(json['buyer'] as Map<String, dynamic>),
  shippingRecipient: json['shippingRecipient'] == null
      ? null
      : PartyInfoDraft.fromJson(
          json['shippingRecipient'] as Map<String, dynamic>,
        ),
  lineItems:
      (json['lineItems'] as List<dynamic>?)
          ?.map((e) => InvoiceLineItemDraft.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  subtotal: (json['subtotal'] as num?)?.toDouble(),
  taxAmount: (json['taxAmount'] as num?)?.toDouble(),
  totalAmount: (json['totalAmount'] as num?)?.toDouble(),
  originalInput: json['originalInput'] as String?,
  confidenceScore: (json['confidenceScore'] as num?)?.toDouble(),
  extractedEntities: (json['extractedEntities'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  rawAIResponse: json['rawAIResponse'] as Map<String, dynamic>?,
  source:
      $enumDecodeNullable(_$InvoiceSourceEnumMap, json['source']) ??
      InvoiceSource.manual,
  missingFields:
      (json['missingFields'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  isReadyForFinalization: json['isReadyForFinalization'] as bool? ?? false,
);

Map<String, dynamic> _$InvoiceDraftToJson(InvoiceDraft instance) =>
    <String, dynamic>{
      'invoiceNumber': instance.invoiceNumber,
      'type': _$InvoiceTypeEnumMap[instance.type]!,
      'issueDate': instance.issueDate?.toIso8601String(),
      'dueDate': instance.dueDate?.toIso8601String(),
      'vendor': instance.vendor?.toJson(),
      'buyer': instance.buyer?.toJson(),
      'shippingRecipient': instance.shippingRecipient?.toJson(),
      'lineItems': instance.lineItems.map((e) => e.toJson()).toList(),
      'subtotal': instance.subtotal,
      'taxAmount': instance.taxAmount,
      'totalAmount': instance.totalAmount,
      'originalInput': instance.originalInput,
      'confidenceScore': instance.confidenceScore,
      'extractedEntities': instance.extractedEntities,
      'rawAIResponse': instance.rawAIResponse,
      'source': _$InvoiceSourceEnumMap[instance.source]!,
      'missingFields': instance.missingFields,
      'warnings': instance.warnings,
      'isReadyForFinalization': instance.isReadyForFinalization,
    };

const _$InvoiceTypeEnumMap = {
  InvoiceType.invoice: 'invoice',
  InvoiceType.creditNote: 'credit_note',
  InvoiceType.debitNote: 'debit_note',
  InvoiceType.refund: 'refund',
};

const _$InvoiceSourceEnumMap = {
  InvoiceSource.manual: 'manual',
  InvoiceSource.voice: 'voice',
  InvoiceSource.receiptScan: 'receipt_scan',
  InvoiceSource.import: 'import',
};

PartyInfoDraft _$PartyInfoDraftFromJson(Map<String, dynamic> json) =>
    PartyInfoDraft(
      name: json['name'] as String?,
      tin: json['tin'] as String?,
      registrationNumber: json['registrationNumber'] as String?,
      identificationNumber: json['identificationNumber'] as String?,
      contactNumber: json['contactNumber'] as String?,
      sstNumber: json['sstNumber'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] == null
          ? null
          : AddressDraft.fromJson(json['address'] as Map<String, dynamic>),
      contactPerson: json['contactPerson'] as String?,
    );

Map<String, dynamic> _$PartyInfoDraftToJson(PartyInfoDraft instance) =>
    <String, dynamic>{
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

AddressDraft _$AddressDraftFromJson(Map<String, dynamic> json) => AddressDraft(
  line1: json['line1'] as String?,
  line2: json['line2'] as String?,
  line3: json['line3'] as String?,
  city: json['city'] as String?,
  state: json['state'] as String?,
  postalCode: json['postalCode'] as String?,
  country: json['country'] as String? ?? 'MY',
);

Map<String, dynamic> _$AddressDraftToJson(AddressDraft instance) =>
    <String, dynamic>{
      'line1': instance.line1,
      'line2': instance.line2,
      'line3': instance.line3,
      'city': instance.city,
      'state': instance.state,
      'postalCode': instance.postalCode,
      'country': instance.country,
    };

InvoiceLineItemDraft _$InvoiceLineItemDraftFromJson(
  Map<String, dynamic> json,
) => InvoiceLineItemDraft(
  id: json['id'] as String,
  description: json['description'] as String,
  quantity: (json['quantity'] as num).toDouble(),
  unit: json['unit'] as String? ?? 'pcs',
  unitPrice: (json['unitPrice'] as num).toDouble(),
  discountAmount: (json['discountAmount'] as num?)?.toDouble(),
  taxRate: (json['taxRate'] as num?)?.toDouble(),
  productCode: json['productCode'] as String?,
  taxType:
      $enumDecodeNullable(_$TaxTypeEnumMap, json['taxType']) ?? TaxType.none,
);

Map<String, dynamic> _$InvoiceLineItemDraftToJson(
  InvoiceLineItemDraft instance,
) => <String, dynamic>{
  'id': instance.id,
  'description': instance.description,
  'quantity': instance.quantity,
  'unit': instance.unit,
  'unitPrice': instance.unitPrice,
  'discountAmount': instance.discountAmount,
  'taxRate': instance.taxRate,
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
