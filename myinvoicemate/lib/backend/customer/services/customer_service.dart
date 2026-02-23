import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firestore_collections.dart';
import '../models/customer_model.dart';
import '../../invoice/models/invoice_model.dart';

/// Real Firestore-backed customer service.
///
/// All customers are user-isolated via [createdBy] (indexed in Firestore).
class CustomerService {
  CustomerService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _customers =>
      _db.collection(FirestoreCollections.customers);

  /// All customers for [userId], sorted alphabetically by name.
  ///
  /// Throws on Firestore errors (e.g. missing index, permission denied) so
  /// callers can surface a meaningful message to the user.
  Future<List<Customer>> getCustomers({String? userId}) async {
    if (userId == null) return [];
    final snap = await _customers
        .where('createdBy', isEqualTo: userId)
        .orderBy('name')
        .get();
    return snap.docs
        .map((d) => Customer.fromJson(_fromFirestore(d.data())..['id'] = d.id))
        .toList();
  }

  /// Search customers by name prefix, or exact TIN / identification number.
  ///
  /// Firestore doesn't support full-text search, so name search is prefix-based.
  /// For richer search, pipe through Algolia or use a cloud function.
  Future<List<Customer>> searchCustomers({
    required String query,
    String? userId,
  }) async {
    if (userId == null || query.isEmpty) return [];
    try {
      // Prefix search on name
      final snap = await _customers
          .where('createdBy', isEqualTo: userId)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '${query}\uF8FF')
          .get();
      final results = snap.docs
          .map((d) => Customer.fromJson(_fromFirestore(d.data())..['id'] = d.id))
          .toList();
      // Also try exact TIN match
      final tinSnap = await _customers
          .where('createdBy', isEqualTo: userId)
          .where('tin', isEqualTo: query)
          .get();
      for (final d in tinSnap.docs) {
        if (!results.any((c) => c.id == d.id)) {
          results.add(Customer.fromJson(_fromFirestore(d.data())..['id'] = d.id));
        }
      }
      return results;
    } catch (e) {
      // ignore: avoid_print
      print('Error searching customers: $e');
      return [];
    }
  }

  /// Fetch a single customer by document ID.
  Future<Customer?> getCustomer(String customerId) async {
    try {
      final doc = await _customers.doc(customerId).get();
      if (!doc.exists) return null;
      return Customer.fromJson(_fromFirestore(doc.data()!)..['id'] = doc.id);
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching customer: $e');
      return null;
    }
  }

  /// Generate a customer ID in the format CUST<YYYYMMDD><3-digit sequence>.
  ///
  /// Uses an atomic Firestore counter per date to avoid duplicate IDs
  /// even under concurrent writes.
  Future<String> _generateCustomerId() async {
    final now = DateTime.now();
    final dateStr = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final counterRef =
        _db.collection('_counters').doc('customer_$dateStr');

    int nextNum = 1;
    await _db.runTransaction((txn) async {
      final snap = await txn.get(counterRef);
      if (snap.exists) {
        nextNum = ((snap.data()!['count'] as num).toInt()) + 1;
      }
      txn.set(counterRef, {'count': nextNum});
    });

    return 'CUST$dateStr${nextNum.toString().padLeft(3, '0')}';
  }

  /// Create a new customer document and return it with the assigned ID.
  Future<Customer?> createCustomer(Customer customer) async {
    try {
      final newId = await _generateCustomerId();
      final doc = _customers.doc(newId);
      final data = _toFirestore(customer.toJson()..['id'] = newId);
      await doc.set(data);
      return customer.copyWith(id: newId);
    } catch (e) {
      // ignore: avoid_print
      print('Error creating customer: $e');
      return null;
    }
  }

  /// Update an existing customer document.
  Future<bool> updateCustomer(Customer customer) async {
    try {
      final data = _toFirestore(customer.toJson())
        ..['updatedAt'] = FieldValue.serverTimestamp();
      await _customers.doc(customer.id).update(data);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error updating customer: $e');
      return false;
    }
  }

  /// Permanently delete a customer document.
  Future<bool> deleteCustomer(String customerId) async {
    try {
      await _customers.doc(customerId).delete();
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error deleting customer: $e');
      return false;
    }
  }

  /// Toggle the [isFavorite] flag for a customer.
  Future<bool> toggleFavorite(String customerId, bool isFavorite) async {
    try {
      await _customers.doc(customerId).update({
        'isFavorite': isFavorite,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error toggling favorite: $e');
      return false;
    }
  }

  /// Customers marked as favourite for [userId].
  Future<List<Customer>> getFavoriteCustomers({String? userId}) async {
    if (userId == null) return [];
    try {
      final snap = await _customers
          .where('createdBy', isEqualTo: userId)
          .where('isFavorite', isEqualTo: true)
          .orderBy('name')
          .get();
      return snap.docs
          .map((d) => Customer.fromJson(_fromFirestore(d.data())..['id'] = d.id))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching favorite customers: $e');
      return [];
    }
  }

  /// Top [limit] customers by total revenue for [userId].
  Future<List<Customer>> getTopCustomers({String? userId, int limit = 5}) async {
    if (userId == null) return [];
    try {
      final snap = await _customers
          .where('createdBy', isEqualTo: userId)
          .orderBy('totalRevenue', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => Customer.fromJson(_fromFirestore(d.data())..['id'] = d.id))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching top customers: $e');
      return [];
    }
  }

  /// Atomically increment [invoiceCount]/[totalRevenue] and set [lastInvoiceDate].
  Future<void> updateCustomerStats({
    required String customerId,
    required double invoiceAmount,
  }) async {
    try {
      await _customers.doc(customerId).update({
        'invoiceCount': FieldValue.increment(1),
        'totalRevenue': FieldValue.increment(invoiceAmount),
        'lastInvoiceDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error updating customer stats: $e');
    }
  }

  /// Look up a [Customer] by TIN, then by name; creates one if not found.
  Future<Customer?> findOrCreateFromPartyInfo({
    required PartyInfo partyInfo,
    required String userId,
  }) async {
    try {
      // 1 — exact TIN match
      if (partyInfo.tin != null && partyInfo.tin!.isNotEmpty) {
        final snap = await _customers
            .where('createdBy', isEqualTo: userId)
            .where('tin', isEqualTo: partyInfo.tin)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final d = snap.docs.first;
          return Customer.fromJson(_fromFirestore(d.data())..['id'] = d.id);
        }
      }
      // 2 — exact name match (requires composite index createdBy + name)
      final nameSnap = await _customers
          .where('createdBy', isEqualTo: userId)
          .where('name', isEqualTo: partyInfo.name)
          .limit(1)
          .get();
      if (nameSnap.docs.isNotEmpty) {
        final d = nameSnap.docs.first;
        return Customer.fromJson(_fromFirestore(d.data())..['id'] = d.id);
      }
      // 3 — create new
      final newCustomer = Customer.fromPartyInfo(
        partyInfo: partyInfo,
        userId: userId,
      );
      return await createCustomer(newCustomer);
    } catch (e) {
      // ignore: avoid_print
      print('Error finding or creating customer: $e');
      return null;
    }
  }

  /// Get suggested addresses for a customer (returns all addresses)
  List<CustomerAddress> getSuggestedAddresses(Customer customer) {
    return customer.addresses;
  }

  /// Append an address to a customer's [addresses] array.
  Future<bool> addAddress({
    required String customerId,
    required CustomerAddress address,
  }) async {
    try {
      await _customers.doc(customerId).update({
        'addresses': FieldValue.arrayUnion([address.toJson()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error adding address: $e');
      return false;
    }
  }

  /// Replace an existing address in the [addresses] array.
  Future<bool> updateAddress({
    required String customerId,
    required CustomerAddress address,
  }) async {
    try {
      final customer = await getCustomer(customerId);
      if (customer == null) return false;
      final updatedAddresses =
          customer.addresses.map((a) => a.id == address.id ? address : a).toList();
      await _customers.doc(customerId).update({
        'addresses': updatedAddresses.map((a) => a.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error updating address: $e');
      return false;
    }
  }

  /// Remove an address from the [addresses] array.
  Future<bool> deleteAddress({
    required String customerId,
    required String addressId,
  }) async {
    try {
      final customer = await getCustomer(customerId);
      if (customer == null) return false;
      final updatedAddresses =
          customer.addresses.where((a) => a.id != addressId).toList();
      if (updatedAddresses.isEmpty) return false; // keep at least one
      await _customers.doc(customerId).update({
        'addresses': updatedAddresses.map((a) => a.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error deleting address: $e');
      return false;
    }
  }

  /// Most recently invoiced customers (by [lastInvoiceDate]) for [userId].
  Future<List<Customer>> getRecentCustomers({
    String? userId,
    int limit = 10,
  }) async {
    if (userId == null) return [];
    try {
      final snap = await _customers
          .where('createdBy', isEqualTo: userId)
          .orderBy('lastInvoiceDate', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => Customer.fromJson(_fromFirestore(d.data())..['id'] = d.id))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching recent customers: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers — Timestamp ↔ ISO string conversion
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _toFirestore(Map<String, dynamic> json) {
    return json.map((key, value) {
      if (value is String) {
        final dt = _tryParseDate(key, value);
        if (dt != null) return MapEntry(key, Timestamp.fromDate(dt));
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, _toFirestore(value));
      } else if (value is List) {
        return MapEntry(
          key,
          value
              .map((e) => e is Map<String, dynamic> ? _toFirestore(e) : e)
              .toList(),
        );
      }
      return MapEntry(key, value);
    });
  }

  static Map<String, dynamic> _fromFirestore(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, _fromFirestore(value));
      } else if (value is List) {
        return MapEntry(
          key,
          value
              .map((e) => e is Map<String, dynamic> ? _fromFirestore(e) : e)
              .toList(),
        );
      }
      return MapEntry(key, value);
    });
  }

  static const _dateKeys = {
    'createdAt', 'updatedAt', 'lastInvoiceDate',
  };

  static DateTime? _tryParseDate(String key, String value) {
    if (!_dateKeys.contains(key)) return null;
    return DateTime.tryParse(value);
  }
}
