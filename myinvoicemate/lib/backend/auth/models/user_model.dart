import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String businessName;
  final String? businessType;
  final String? ssmNumber;
  final String tin;
  final String phone;
  final String address;
  final DateTime createdAt;
  final bool isVerified;

  UserModel({
    required this.id,
    required this.email,
    required this.businessName,
    this.businessType,
    this.ssmNumber,
    required this.tin,
    required this.phone,
    required this.address,
    required this.createdAt,
    this.isVerified = false,
  });

  // ---------------------------------------------------------------------------
  // Firestore ↔ model conversion
  // ---------------------------------------------------------------------------

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      businessName: data['businessName'] as String? ?? '',
      businessType: data['businessType'] as String?,
      ssmNumber: data['ssmNumber'] as String?,
      tin: data['tin'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVerified: data['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'businessName': businessName,
      if (businessType != null) 'businessType': businessType,
      if (ssmNumber != null) 'ssmNumber': ssmNumber,
      'tin': tin,
      'phone': phone,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
      'isVerified': isVerified,
    };
  }

  // ---------------------------------------------------------------------------
  // Legacy JSON helpers (kept for compatibility with non-Firestore code)
  // ---------------------------------------------------------------------------

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      businessName: json['businessName'] as String? ?? '',
      businessType: json['businessType'] as String?,
      ssmNumber: json['ssmNumber'] as String?,
      tin: json['tin'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => toFirestore()..['id'] = id;

  UserModel copyWith({
    String? id,
    String? email,
    String? businessName,
    String? businessType,
    String? ssmNumber,
    String? tin,
    String? phone,
    String? address,
    DateTime? createdAt,
    bool? isVerified,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      ssmNumber: ssmNumber ?? this.ssmNumber,
      tin: tin ?? this.tin,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
