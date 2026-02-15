// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Customer _$CustomerFromJson(Map<String, dynamic> json) => Customer(
  id: json['id'] as String,
  name: json['name'] as String,
  tin: json['tin'] as String?,
  registrationNumber: json['registrationNumber'] as String?,
  identificationNumber: json['identificationNumber'] as String?,
  contactNumber: json['contactNumber'] as String?,
  sstNumber: json['sstNumber'] as String?,
  email: json['email'] as String?,
  addresses: (json['addresses'] as List<dynamic>)
      .map((e) => CustomerAddress.fromJson(e as Map<String, dynamic>))
      .toList(),
  contactPerson: json['contactPerson'] as String?,
  invoiceCount: (json['invoiceCount'] as num?)?.toInt() ?? 0,
  totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
  lastInvoiceDate: json['lastInvoiceDate'] == null
      ? null
      : DateTime.parse(json['lastInvoiceDate'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  createdBy: json['createdBy'] as String,
  isFavorite: json['isFavorite'] as bool? ?? false,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$CustomerToJson(Customer instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'tin': instance.tin,
  'registrationNumber': instance.registrationNumber,
  'identificationNumber': instance.identificationNumber,
  'contactNumber': instance.contactNumber,
  'sstNumber': instance.sstNumber,
  'email': instance.email,
  'addresses': instance.addresses.map((e) => e.toJson()).toList(),
  'contactPerson': instance.contactPerson,
  'invoiceCount': instance.invoiceCount,
  'totalRevenue': instance.totalRevenue,
  'lastInvoiceDate': instance.lastInvoiceDate?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'createdBy': instance.createdBy,
  'isFavorite': instance.isFavorite,
  'notes': instance.notes,
};

CustomerAddress _$CustomerAddressFromJson(Map<String, dynamic> json) =>
    CustomerAddress(
      id: json['id'] as String,
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      line3: json['line3'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postalCode'] as String,
      country: json['country'] as String? ?? 'MY',
      isPrimary: json['isPrimary'] as bool? ?? false,
      label: json['label'] as String?,
    );

Map<String, dynamic> _$CustomerAddressToJson(CustomerAddress instance) =>
    <String, dynamic>{
      'id': instance.id,
      'line1': instance.line1,
      'line2': instance.line2,
      'line3': instance.line3,
      'city': instance.city,
      'state': instance.state,
      'postalCode': instance.postalCode,
      'country': instance.country,
      'isPrimary': instance.isPrimary,
      'label': instance.label,
    };
