import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firestore_collections.dart';
import '../models/support_location_model.dart';

/// Firestore-backed service for the /support_locations collection.
///
/// Support locations are static reference data seeded once (e.g. by admin or
/// a seed script). The service queries Firestore and optionally filters by
/// proximity or type.
class SupportService {
  SupportService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _locations =>
      _db.collection(FirestoreCollections.supportLocations);

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Return all support locations sorted by distance to [latitude]/[longitude].
  ///
  /// Proximity filtering is done client-side because Firestore's native
  /// geo-queries are limited. For production, consider geoflutterfire2.
  Future<List<SupportLocation>> getNearbyLocations(
    double latitude,
    double longitude, {
    double radiusKm = 50,
  }) async {
    final all = await _fetchAll();
    all.sort((a, b) {
      final da = _distanceKm(latitude, longitude, a.latitude, a.longitude);
      final db = _distanceKm(latitude, longitude, b.latitude, b.longitude);
      return da.compareTo(db);
    });
    if (latitude == 0 && longitude == 0) return all;
    return all
        .where((l) =>
            _distanceKm(latitude, longitude, l.latitude, l.longitude) <=
            radiusKm)
        .toList();
  }

  /// Return locations matching a specific [type].
  Future<List<SupportLocation>> getLocationsByType(String type) async {
    final snap = await _locations
        .where('type', isEqualTo: type)
        .orderBy('name')
        .get();
    return snap.docs
        .map((d) => SupportLocation.fromJson(d.data()..['id'] = d.id))
        .toList();
  }

  /// Search by name, address, or services (client-side after full fetch).
  Future<List<SupportLocation>> searchLocations(String query) async {
    final all = await _fetchAll();
    final q = query.toLowerCase();
    return all.where((loc) {
      return loc.name.toLowerCase().contains(q) ||
          loc.address.toLowerCase().contains(q) ||
          loc.services.any((s) => s.toLowerCase().contains(q));
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Seeding helper (run once, e.g. from admin panel or migration script)
  // ---------------------------------------------------------------------------

  /// Write the default Malaysian support locations to Firestore.
  /// Safe to call multiple times — uses [SetOptions.merge].
  Future<void> seedDefaultLocations() async {
    final defaults = _defaultLocations();
    final batch = _db.batch();
    for (final loc in defaults) {
      batch.set(_locations.doc(loc.id), loc.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<List<SupportLocation>> _fetchAll() async {
    final snap = await _locations.orderBy('name').get();
    return snap.docs
        .map((d) => SupportLocation.fromJson(d.data()..['id'] = d.id))
        .toList();
  }

  // Haversine distance in km (simplified, sufficient for hundreds of km).
  static double _distanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dlat = (lat2 - lat1) * 3.14159265358979 / 180;
    final dlon = (lon2 - lon1) * 3.14159265358979 / 180;
    final a = _sq(_sin(dlat / 2)) +
        _sq(_sin(dlon / 2)) *
            _cos(lat1 * 3.14159265358979 / 180) *
            _cos(lat2 * 3.14159265358979 / 180);
    return 2 * r * _asin(_sqrtApprox(a));
  }

  static double _sin(double x) =>
      x - x * x * x / 6.0 + x * x * x * x * x / 120.0;
  static double _cos(double x) {
    final s = _sin(x);
    return _sqrtApprox(1 - s * s);
  }

  static double _sq(double x) => x * x;
  static double _asin(double x) => x + x * x * x / 6.0;
  static double _sqrtApprox(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 10; i++) r = (r + x / r) / 2;
    return r;
  }

  List<SupportLocation> _defaultLocations() => [
        SupportLocation(
          id: 'lhdn_cyberjaya',
          name: 'LHDN Kuala Lumpur (Cyberjaya)',
          type: 'lhdn_office',
          address:
              'Menara Hasil, Persiaran Rimba Permai, Cyber 8, 63000 Cyberjaya, Selangor',
          latitude: 2.9221,
          longitude: 101.6551,
          phone: '03-8911 1000',
          website: 'https://www.hasil.gov.my',
          services: [
            'E-Invoice Support',
            'Tax Consultation',
            'Document Verification'
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'sme_bangsar_south',
          name: 'SME Digital Centre KL',
          type: 'sme_center',
          address: 'Bangsar South, Kuala Lumpur',
          latitude: 3.1159,
          longitude: 101.6660,
          phone: '03-2775 6000',
          website: 'https://www.smeinfo.com.my',
          services: [
            'Digital Training',
            'Compliance Workshops',
            'Business Advisory'
          ],
          openingHours: 'Mon–Fri: 9:00 AM – 6:00 PM',
        ),
        SupportLocation(
          id: 'tax_support_pj',
          name: 'Tax Support Centre Petaling Jaya',
          type: 'tax_support',
          address: 'Jalan Utara, Petaling Jaya, Selangor',
          latitude: 3.1068,
          longitude: 101.6398,
          phone: '03-7956 5000',
          services: [
            'Tax Filing Assistance',
            'MyInvois Registration',
            'Audit Support'
          ],
          openingHours: 'Mon–Sat: 9:00 AM – 5:30 PM',
        ),
      ];
}
