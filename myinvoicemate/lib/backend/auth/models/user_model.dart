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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      businessName: json['businessName'] ?? '',
      businessType: json['businessType'],
      ssmNumber: json['ssmNumber'],
      tin: json['tin'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isVerified: json['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'businessName': businessName,
      'businessType': businessType,
      'ssmNumber': ssmNumber,
      'tin': tin,
      'phone': phone,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'isVerified': isVerified,
    };
  }
}
