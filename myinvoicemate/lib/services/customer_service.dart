import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';
import '../backend/invoice/models/invoice_model.dart';

class CustomerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all customers for the current user
  Future<List<Customer>> getCustomers({String? userId}) async {
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('customers')
          .where('createdBy', isEqualTo: userId)
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => Customer.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching customers: $e');
      return [];
    }
  }

  /// Search customers by name, TIN, or IC
  Future<List<Customer>> searchCustomers({
    required String query,
    String? userId,
  }) async {
    if (userId == null || query.isEmpty) return [];

    try {
      final allCustomers = await getCustomers(userId: userId);
      final lowerQuery = query.toLowerCase();

      return allCustomers.where((customer) {
        return customer.name.toLowerCase().contains(lowerQuery) ||
            (customer.tin?.toLowerCase().contains(lowerQuery) ?? false) ||
            (customer.identificationNumber?.toLowerCase().contains(lowerQuery) ?? false) ||
            (customer.email?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    } catch (e) {
      print('Error searching customers: $e');
      return [];
    }
  }

  /// Get a single customer by ID
  Future<Customer?> getCustomer(String customerId) async {
    try {
      final doc = await _firestore.collection('customers').doc(customerId).get();
      if (!doc.exists) return null;
      return Customer.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      print('Error fetching customer: $e');
      return null;
    }
  }

  /// Create a new customer
  Future<Customer?> createCustomer(Customer customer) async {
    try {
      final docRef = await _firestore.collection('customers').add(customer.toJson());
      final doc = await docRef.get();
      return Customer.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      print('Error creating customer: $e');
      return null;
    }
  }

  /// Update an existing customer
  Future<bool> updateCustomer(Customer customer) async {
    try {
      await _firestore
          .collection('customers')
          .doc(customer.id)
          .update(customer.copyWith(updatedAt: DateTime.now()).toJson());
      return true;
    } catch (e) {
      print('Error updating customer: $e');
      return false;
    }
  }

  /// Delete a customer
  Future<bool> deleteCustomer(String customerId) async {
    try {
      await _firestore.collection('customers').doc(customerId).delete();
      return true;
    } catch (e) {
      print('Error deleting customer: $e');
      return false;
    }
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite(String customerId, bool isFavorite) async {
    try {
      await _firestore.collection('customers').doc(customerId).update({
        'isFavorite': isFavorite,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error toggling favorite: $e');
      return false;
    }
  }

  /// Get favorite customers
  Future<List<Customer>> getFavoriteCustomers({String? userId}) async {
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('customers')
          .where('createdBy', isEqualTo: userId)
          .where('isFavorite', isEqualTo: true)
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => Customer.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching favorite customers: $e');
      return [];
    }
  }

  /// Get top customers by revenue
  Future<List<Customer>> getTopCustomers({String? userId, int limit = 5}) async {
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('customers')
          .where('createdBy', isEqualTo: userId)
          .orderBy('totalRevenue', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Customer.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching top customers: $e');
      return [];
    }
  }

  /// Update customer statistics (called when an invoice is created)
  Future<void> updateCustomerStats({
    required String customerId,
    required double invoiceAmount,
  }) async {
    try {
      final customer = await getCustomer(customerId);
      if (customer == null) return;

      await _firestore.collection('customers').doc(customerId).update({
        'invoiceCount': customer.invoiceCount + 1,
        'totalRevenue': customer.totalRevenue + invoiceAmount,
        'lastInvoiceDate': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating customer stats: $e');
    }
  }

  /// Find or create customer from PartyInfo
  /// This helps auto-save customers when creating invoices
  Future<Customer?> findOrCreateFromPartyInfo({
    required PartyInfo partyInfo,
    required String userId,
  }) async {
    try {
      // Try to find existing customer by TIN or IC
      final allCustomers = await getCustomers(userId: userId);
      
      final existing = allCustomers.where((customer) {
        if (partyInfo.tin != null && customer.tin == partyInfo.tin) {
          return true;
        }
        if (partyInfo.identificationNumber != null && 
            customer.identificationNumber == partyInfo.identificationNumber) {
          return true;
        }
        // Exact name match
        if (customer.name.toLowerCase() == partyInfo.name.toLowerCase()) {
          return true;
        }
        return false;
      }).toList();

      if (existing.isNotEmpty) {
        return existing.first;
      }

      // Create new customer
      final newCustomer = Customer.fromPartyInfo(
        partyInfo: partyInfo,
        userId: userId,
      );
      return await createCustomer(newCustomer);
    } catch (e) {
      print('Error finding or creating customer: $e');
      return null;
    }
  }

  /// Get suggested addresses for a customer (returns all addresses)
  List<CustomerAddress> getSuggestedAddresses(Customer customer) {
    return customer.addresses;
  }

  /// Add a new address to a customer
  Future<bool> addAddress({
    required String customerId,
    required CustomerAddress address,
  }) async {
    try {
      final customer = await getCustomer(customerId);
      if (customer == null) return false;

      final updatedAddresses = [...customer.addresses, address];
      await updateCustomer(customer.copyWith(addresses: updatedAddresses));
      return true;
    } catch (e) {
      print('Error adding address: $e');
      return false;
    }
  }

  /// Update an address for a customer
  Future<bool> updateAddress({
    required String customerId,
    required CustomerAddress address,
  }) async {
    try {
      final customer = await getCustomer(customerId);
      if (customer == null) return false;

      final updatedAddresses = customer.addresses.map((addr) {
        return addr.id == address.id ? address : addr;
      }).toList();

      await updateCustomer(customer.copyWith(addresses: updatedAddresses));
      return true;
    } catch (e) {
      print('Error updating address: $e');
      return false;
    }
  }

  /// Delete an address from a customer
  Future<bool> deleteAddress({
    required String customerId,
    required String addressId,
  }) async {
    try {
      final customer = await getCustomer(customerId);
      if (customer == null) return false;

      final updatedAddresses = customer.addresses
          .where((addr) => addr.id != addressId)
          .toList();

      if (updatedAddresses.isEmpty) {
        // Can't delete the last address
        return false;
      }

      await updateCustomer(customer.copyWith(addresses: updatedAddresses));
      return true;
    } catch (e) {
      print('Error deleting address: $e');
      return false;
    }
  }

  /// Get recent customers (by last invoice date)
  Future<List<Customer>> getRecentCustomers({
    String? userId,
    int limit = 10,
  }) async {
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('customers')
          .where('createdBy', isEqualTo: userId)
          .where('lastInvoiceDate', isNull: false)
          .orderBy('lastInvoiceDate', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Customer.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching recent customers: $e');
      return [];
    }
  }
}
