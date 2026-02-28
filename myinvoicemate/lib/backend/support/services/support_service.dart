import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firestore_collections.dart';
import '../models/support_location_model.dart';

/// Firestore-backed service for the /support_locations collection.
///
/// Support locations are static reference data seeded once (e.g. by admin or
/// a seed script). The service queries Firestore and optionally filters by
/// proximity or type.
///
/// If Firestore returns an empty collection the service transparently falls
/// back to the bundled static data so the map always shows useful locations.
class SupportService {
  SupportService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _locations =>
      _db.collection(FirestoreCollections.supportLocations);

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Return every support location without any distance filtering.
  Future<List<SupportLocation>> getAllLocations() async {
    var all = await _fetchAll();
    if (all.isEmpty) {
      await seedDefaultLocations();
      all = _defaultLocations();
    }
    return all;
  }

  /// Return all support locations sorted by distance to [latitude]/[longitude].
  ///
  /// Proximity filtering is done client-side because Firestore's native
  /// geo-queries are limited. For production, consider geoflutterfire2.
  Future<List<SupportLocation>> getNearbyLocations(
    double latitude,
    double longitude, {
    double radiusKm = 200,
  }) async {
    var all = await _fetchAll();
    // Auto-seed if collection is empty so the map always has data.
    if (all.isEmpty) {
      await seedDefaultLocations();
      all = _defaultLocations();
    }
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
    final results = snap.docs
        .map((d) => SupportLocation.fromJson(d.data()..['id'] = d.id))
        .toList();
    if (results.isEmpty) {
      return _defaultLocations()
          .where((l) => l.type == type)
          .toList();
    }
    return results;
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
    try {
      final snap = await _locations.orderBy('name').get();
      return snap.docs
          .map((d) => SupportLocation.fromJson(d.data()..['id'] = d.id))
          .toList();
    } catch (_) {
      return _defaultLocations();
    }
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

  // ---------------------------------------------------------------------------
  // Comprehensive Malaysia LHDN / SME / Tax support locations
  // ---------------------------------------------------------------------------

  List<SupportLocation> _defaultLocations() => [
        // ── LHDN Offices ──────────────────────────────────────────────────
        SupportLocation(
          id: 'lhdn_cyberjaya',
          name: 'LHDN Kuala Lumpur (HQ Cyberjaya)',
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
            'Document Verification',
            'MyInvois',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'lhdn_jalan_duta_kl',
          name: 'LHDN Kuala Lumpur (Jalan Duta)',
          type: 'lhdn_office',
          address: 'Kompleks Bangunan Kerajaan Jalan Duta, 50600 Kuala Lumpur',
          latitude: 3.1726,
          longitude: 101.6697,
          phone: '03-6209 7000',
          website: 'https://www.hasil.gov.my',
          services: [
            'Tax Filing',
            'Corporate Tax',
            'E-Invoice Support',
            'Queries & Appeals',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'lhdn_georgetown_penang',
          name: 'LHDN Pulau Pinang (Georgetown)',
          type: 'lhdn_office',
          address:
              'No 66, Jalan Dato Keramat, 10150 Georgetown, Pulau Pinang',
          latitude: 5.4186,
          longitude: 100.3326,
          phone: '04-226 3300',
          website: 'https://www.hasil.gov.my',
          services: [
            'Tax Filing',
            'Business Tax',
            'E-Invoice Support',
            'GST/SST Queries',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'lhdn_jb_johor',
          name: 'LHDN Johor Bahru',
          type: 'lhdn_office',
          address:
              'Wisma LHDN, No 9 Jalan Sungai Chat, 80100 Johor Bahru, Johor',
          latitude: 1.4655,
          longitude: 103.7578,
          phone: '07-222 0400',
          website: 'https://www.hasil.gov.my',
          services: [
            'Personal Tax',
            'Corporate Tax',
            'E-Invoice Support',
            'MyInvois Registration',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'lhdn_ipoh_perak',
          name: 'LHDN Ipoh, Perak',
          type: 'lhdn_office',
          address:
              'Menara Hasil, No.1 Persiaran Greentown 5, 30450 Ipoh, Perak',
          latitude: 4.5975,
          longitude: 101.0901,
          phone: '05-547 3000',
          website: 'https://www.hasil.gov.my',
          services: [
            'Tax Filing',
            'Tax Consultation',
            'E-Invoice Support',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'lhdn_shah_alam',
          name: 'LHDN Shah Alam, Selangor',
          type: 'lhdn_office',
          address:
              'Tingkat 1-4, Wisma Persekutuan Shah Alam, Persiaran Perbandaran, 40000 Shah Alam',
          latitude: 3.0849,
          longitude: 101.5329,
          phone: '03-5510 1700',
          website: 'https://www.hasil.gov.my',
          services: [
            'Personal Tax',
            'Corporate Tax',
            'E-Invoice Support',
            'Stamp Duty',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'lhdn_kota_kinabalu',
          name: 'LHDN Kota Kinabalu, Sabah',
          type: 'lhdn_office',
          address:
              'Wisma LHDN, Jalan Tuanku Abdul Halim, 88200 Kota Kinabalu, Sabah',
          latitude: 5.9788,
          longitude: 116.0753,
          phone: '088-322 300',
          website: 'https://www.hasil.gov.my',
          services: [
            'Tax Filing',
            'Corporate Tax',
            'E-Invoice Support',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'lhdn_kuching_sarawak',
          name: 'LHDN Kuching, Sarawak',
          type: 'lhdn_office',
          address:
              'Menara MAA, No 26, Jalan Bukit Mata Kuching, 93100 Kuching, Sarawak',
          latitude: 1.5533,
          longitude: 110.3456,
          phone: '082-444 022',
          website: 'https://www.hasil.gov.my',
          services: [
            'Tax Filing',
            'Business Tax',
            'E-Invoice Support',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'lhdn_kota_bharu',
          name: 'LHDN Kota Bharu, Kelantan',
          type: 'lhdn_office',
          address:
              'Kompleks Pejabat Persekutuan, Jalan Bayam, 15990 Kota Bharu, Kelantan',
          latitude: 6.1248,
          longitude: 102.2390,
          phone: '09-748 3000',
          website: 'https://www.hasil.gov.my',
          services: [
            'Personal Tax',
            'Corporate Tax',
            'E-Invoice Support',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'lhdn_alor_setar',
          name: 'LHDN Alor Setar, Kedah',
          type: 'lhdn_office',
          address:
              'Wisma Persekutuan, Jalan Kampung Perak, 05000 Alor Setar, Kedah',
          latitude: 6.1256,
          longitude: 100.3673,
          phone: '04-721 1800',
          website: 'https://www.hasil.gov.my',
          services: [
            'Tax Filing',
            'E-Invoice Support',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'lhdn_seremban',
          name: 'LHDN Seremban, Negeri Sembilan',
          type: 'lhdn_office',
          address:
              'Wisma Persekutuan, Jalan Dato Abdul Kadir, 70000 Seremban, Negeri Sembilan',
          latitude: 2.7260,
          longitude: 101.9424,
          phone: '06-766 2200',
          website: 'https://www.hasil.gov.my',
          services: [
            'Personal Tax',
            'Corporate Tax',
            'E-Invoice Support',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),
        SupportLocation(
          id: 'lhdn_kuantan',
          name: 'LHDN Kuantan, Pahang',
          type: 'lhdn_office',
          address:
              'Wisma LHDN, Jalan Gambut, 25000 Kuantan, Pahang',
          latitude: 3.8077,
          longitude: 103.3260,
          phone: '09-515 3000',
          website: 'https://www.hasil.gov.my',
          services: [
            'Tax Filing',
            'E-Invoice Support',
          ],
          openingHours: 'Mon–Fri: 8:00 AM – 5:00 PM',
        ),

        // ── SME Digital Centres ────────────────────────────────────────────
        SupportLocation(
          id: 'sme_bangsar_south',
          name: 'SME Digital Centre KL',
          type: 'sme_center',
          address: 'Level 7, SME Bank HQ, No. 6, Jalan Sultana, Bangsar South, 59200 Kuala Lumpur',
          latitude: 3.1159,
          longitude: 101.6660,
          phone: '03-2775 6000',
          website: 'https://www.smeinfo.com.my',
          services: [
            'Digital Training',
            'Compliance Workshops',
            'Business Advisory',
            'E-Invoice Guidance',
          ],
          openingHours: 'Mon–Fri: 9:00 AM – 6:00 PM',
        ),
        SupportLocation(
          id: 'sme_penang',
          name: 'SME Digital Centre Penang',
          type: 'sme_center',
          address: 'SME Corp Penang Branch, Jalan Penang, 10000 Georgetown, Pulau Pinang',
          latitude: 5.4225,
          longitude: 100.3278,
          phone: '04-261 8600',
          website: 'https://www.smeinfo.com.my',
          services: [
            'Digital Training',
            'Business Advisory',
            'E-Invoice Guidance',
          ],
          openingHours: 'Mon–Fri: 9:00 AM – 5:30 PM',
        ),
        SupportLocation(
          id: 'sme_johor',
          name: 'SME Digital Centre Johor',
          type: 'sme_center',
          address: 'Bangunan JCorp, Jalan Padi Emas, Bandar Baru Uda, 80350 Johor Bahru',
          latitude: 1.5100,
          longitude: 103.7500,
          phone: '07-355 0505',
          website: 'https://www.smeinfo.com.my',
          services: [
            'Digital Training',
            'Business Advisory',
            'E-Invoice Guidance',
          ],
          openingHours: 'Mon–Fri: 9:00 AM – 5:30 PM',
        ),

        // ── Tax Support Centres ────────────────────────────────────────────
        SupportLocation(
          id: 'tax_support_pj',
          name: 'Tax Support Centre Petaling Jaya',
          type: 'tax_support',
          address: 'Jalan Utara, Petaling Jaya, 46200 Selangor',
          latitude: 3.1068,
          longitude: 101.6398,
          phone: '03-7956 5000',
          services: [
            'Tax Filing Assistance',
            'MyInvois Registration',
            'Audit Support',
            'E-Invoice Guidance',
          ],
          openingHours: 'Mon–Sat: 9:00 AM – 5:30 PM',
        ),
        SupportLocation(
          id: 'tax_support_klcc',
          name: 'Tax Support Centre KLCC',
          type: 'tax_support',
          address: 'Jalan Ampang, 50450 Kuala Lumpur',
          latitude: 3.1579,
          longitude: 101.7116,
          phone: '03-2382 0000',
          services: [
            'Tax Filing Assistance',
            'MyInvois Registration',
            'Audit Support',
          ],
          openingHours: 'Mon–Fri: 9:00 AM – 6:00 PM',
        ),
      ];
}
