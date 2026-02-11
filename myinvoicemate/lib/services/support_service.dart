import '../models/support_location_model.dart';

class SupportService {
  // Get nearby support locations
  Future<List<SupportLocation>> getNearbyLocations(
    double latitude,
    double longitude,
  ) async {
    await Future.delayed(const Duration(seconds: 1));

    // Mock support locations
    return [
      SupportLocation(
        id: 'loc1',
        name: 'LHDN Kuala Lumpur',
        type: 'lhdn_office',
        address: 'Menara Hasil, Persiaran Rimba Permai, Cyber 8, 63000 Cyberjaya, Selangor',
        latitude: 2.9221,
        longitude: 101.6551,
        phone: '03-8911 1000',
        website: 'https://www.hasil.gov.my',
        services: ['E-Invoice Support', 'Tax Consultation', 'Document Verification'],
        openingHours: 'Mon-Fri: 8:00 AM - 5:00 PM',
      ),
      SupportLocation(
        id: 'loc2',
        name: 'SME Digital Centre KL',
        type: 'sme_center',
        address: 'Bangsar South, Kuala Lumpur',
        latitude: 3.1159,
        longitude: 101.6660,
        phone: '03-2775 6000',
        website: 'https://www.smeinfo.com.my',
        services: ['Digital Training', 'Compliance Workshops', 'Business Advisory'],
        openingHours: 'Mon-Fri: 9:00 AM - 6:00 PM',
      ),
      SupportLocation(
        id: 'loc3',
        name: 'Tax Support Centre Petaling Jaya',
        type: 'tax_support',
        address: 'Jalan Utara, Petaling Jaya, Selangor',
        latitude: 3.1068,
        longitude: 101.6398,
        phone: '03-7956 5000',
        services: ['Tax Filing Assistance', 'MyInvois Registration', 'Audit Support'],
        openingHours: 'Mon-Sat: 9:00 AM - 5:30 PM',
      ),
    ];
  }

  // Get support center by type
  Future<List<SupportLocation>> getLocationsByType(String type) async {
    final allLocations = await getNearbyLocations(0, 0);
    return allLocations.where((loc) => loc.type == type).toList();
  }

  // Search support locations
  Future<List<SupportLocation>> searchLocations(String query) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final allLocations = await getNearbyLocations(0, 0);
    
    return allLocations.where((loc) {
      return loc.name.toLowerCase().contains(query.toLowerCase()) ||
             loc.address.toLowerCase().contains(query.toLowerCase()) ||
             loc.services.any((s) => s.toLowerCase().contains(query.toLowerCase()));
    }).toList();
  }
}
