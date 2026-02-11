class SupportLocation {
  final String id;
  final String name;
  final String type; // 'lhdn_office', 'sme_center', 'tax_support'
  final String address;
  final double latitude;
  final double longitude;
  final String phone;
  final String? website;
  final List<String> services;
  final String? openingHours;

  SupportLocation({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
    this.website,
    required this.services,
    this.openingHours,
  });

  factory SupportLocation.fromJson(Map<String, dynamic> json) {
    return SupportLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      phone: json['phone'] ?? '',
      website: json['website'],
      services: List<String>.from(json['services'] ?? []),
      openingHours: json['openingHours'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'website': website,
      'services': services,
      'openingHours': openingHours,
    };
  }
}
