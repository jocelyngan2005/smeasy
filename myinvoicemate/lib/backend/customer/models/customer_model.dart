import 'package:json_annotation/json_annotation.dart';
import '../../invoice/models/invoice_model.dart';

part 'customer_model.g.dart';

@JsonSerializable(explicitToJson: true)
class Customer {
  final String id;
  final String name;
  final String? tin; // Tax Identification Number
  final String? registrationNumber; // Company registration number
  final String? identificationNumber; // MyKad/MyTentera/Passport/MyPR/MyKAS
  final String? contactNumber;
  final String? sstNumber;
  final String? email;
  final List<CustomerAddress> addresses; // Can have multiple addresses
  final String? contactPerson;
  final int invoiceCount; // Number of invoices for this customer
  final double totalRevenue; // Total revenue from this customer
  final DateTime? lastInvoiceDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy; // User ID
  final bool isFavorite;
  final String? notes;

  Customer({
    required this.id,
    required this.name,
    this.tin,
    this.registrationNumber,
    this.identificationNumber,
    this.contactNumber,
    this.sstNumber,
    this.email,
    required this.addresses,
    this.contactPerson,
    this.invoiceCount = 0,
    this.totalRevenue = 0,
    this.lastInvoiceDate,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.isFavorite = false,
    this.notes,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerToJson(this);

  /// Convert customer to PartyInfo for invoice creation
  PartyInfo toPartyInfo({CustomerAddress? address}) {
    final addr = address ?? (addresses.isNotEmpty ? addresses.first : null);
    if (addr == null) {
      throw Exception('Customer must have at least one address');
    }

    return PartyInfo(
      name: name,
      tin: tin,
      registrationNumber: registrationNumber,
      identificationNumber: identificationNumber,
      contactNumber: contactNumber,
      sstNumber: sstNumber,
      email: email,
      phone: contactNumber,
      address: Address(
        line1: addr.line1,
        line2: addr.line2,
        line3: addr.line3,
        city: addr.city,
        state: addr.state,
        postalCode: addr.postalCode,
        country: addr.country,
      ),
      contactPerson: contactPerson,
    );
  }

  /// Create customer from PartyInfo
  static Customer fromPartyInfo({
    required PartyInfo partyInfo,
    required String userId,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return Customer(
      id: id,
      name: partyInfo.name,
      tin: partyInfo.tin,
      registrationNumber: partyInfo.registrationNumber,
      identificationNumber: partyInfo.identificationNumber,
      contactNumber: partyInfo.contactNumber,
      sstNumber: partyInfo.sstNumber,
      email: partyInfo.email,
      addresses: [
        CustomerAddress(
          id: '${id}_addr_1',
          line1: partyInfo.address.line1,
          line2: partyInfo.address.line2,
          line3: partyInfo.address.line3,
          city: partyInfo.address.city,
          state: partyInfo.address.state,
          postalCode: partyInfo.address.postalCode,
          country: partyInfo.address.country,
          isPrimary: true,
          label: 'Primary',
        ),
      ],
      contactPerson: partyInfo.contactPerson,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: userId,
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? tin,
    String? registrationNumber,
    String? identificationNumber,
    String? contactNumber,
    String? sstNumber,
    String? email,
    List<CustomerAddress>? addresses,
    String? contactPerson,
    int? invoiceCount,
    double? totalRevenue,
    DateTime? lastInvoiceDate,
    DateTime? updatedAt,
    bool? isFavorite,
    String? notes,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      tin: tin ?? this.tin,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      identificationNumber: identificationNumber ?? this.identificationNumber,
      contactNumber: contactNumber ?? this.contactNumber,
      sstNumber: sstNumber ?? this.sstNumber,
      email: email ?? this.email,
      addresses: addresses ?? this.addresses,
      contactPerson: contactPerson ?? this.contactPerson,
      invoiceCount: invoiceCount ?? this.invoiceCount,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      lastInvoiceDate: lastInvoiceDate ?? this.lastInvoiceDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: createdBy,
      isFavorite: isFavorite ?? this.isFavorite,
      notes: notes ?? this.notes,
    );
  }

  /// Get primary address
  CustomerAddress? get primaryAddress {
    try {
      return addresses.firstWhere((addr) => addr.isPrimary);
    } catch (e) {
      return addresses.isNotEmpty ? addresses.first : null;
    }
  }

  /// Validate if customer has the required information
  bool get isValid {
    return name.isNotEmpty &&
        addresses.isNotEmpty &&
        (tin?.isNotEmpty ?? false || identificationNumber!.isNotEmpty);
  }
}

@JsonSerializable()
class CustomerAddress {
  final String id;
  final String line1;
  final String? line2;
  final String? line3;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final bool isPrimary;
  final String? label; // e.g., "Primary", "Billing", "Shipping"

  CustomerAddress({
    required this.id,
    required this.line1,
    this.line2,
    this.line3,
    required this.city,
    required this.state,
    required this.postalCode,
    this.country = 'MY',
    this.isPrimary = false,
    this.label,
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) => 
      _$CustomerAddressFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerAddressToJson(this);

  String get fullAddress {
    final parts = [line1, line2, line3, city, state, postalCode]
        .where((part) => part != null && part.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  CustomerAddress copyWith({
    String? id,
    String? line1,
    String? line2,
    String? line3,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    bool? isPrimary,
    String? label,
  }) {
    return CustomerAddress(
      id: id ?? this.id,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      line3: line3 ?? this.line3,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      isPrimary: isPrimary ?? this.isPrimary,
      label: label ?? this.label,
    );
  }
}
