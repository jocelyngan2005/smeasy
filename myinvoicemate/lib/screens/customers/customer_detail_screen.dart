import 'package:flutter/material.dart';
import '../../backend/customer/models/customer_model.dart';
import '../../backend/customer/services/customer_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'add_customer_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _customerService = CustomerService();
  Customer? _customer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoading = true);
    try {
      final customer = await _customerService.getCustomer(widget.customerId);
      setState(() {
        _customer = customer;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Helpers.showErrorSnackbar(context, 'Failed to load customer');
      }
    }
  }

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text(
          'Are you sure you want to delete this customer? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _customerService.deleteCustomer(widget.customerId);
      if (success && mounted) {
        Navigator.pop(context, true);
        Helpers.showSuccessSnackbar(context, 'Customer deleted successfully');
      } else if (mounted) {
        Helpers.showErrorSnackbar(context, 'Failed to delete customer');
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_customer == null) return;

    final success = await _customerService.toggleFavorite(
      _customer!.id,
      !_customer!.isFavorite,
    );

    if (success) {
      await _loadCustomer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Customer Details',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          if (_customer != null) ...[
            IconButton(
              icon: Icon(
                _customer!.isFavorite ? Icons.star : Icons.star_border,
                color: _customer!.isFavorite ? Colors.amber : Colors.grey,
              ),
              onPressed: _toggleFavorite,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddCustomerScreen(customer: _customer),
                  ),
                );
                if (result == true) {
                  _loadCustomer();
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteCustomer();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Delete Customer'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customer == null
              ? const Center(child: Text('Customer not found'))
              : RefreshIndicator(
                  onRefresh: _loadCustomer,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header Card
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.1),
                                child: Text(
                                  _customer!.name.isNotEmpty
                                      ? _customer!.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _customer!.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_customer!.contactPerson != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Contact: ${_customer!.contactPerson}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Statistics
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.receipt_long,
                              label: 'Invoices',
                              value: _customer!.invoiceCount.toString(),
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.attach_money,
                              label: 'Total Revenue',
                              value: Helpers.formatCurrency(
                                _customer!.totalRevenue,
                              ),
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Tax Information
                      _buildSectionTitle('Tax Information'),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (_customer!.tin != null)
                                _buildInfoRow('TIN', _customer!.tin!),
                              if (_customer!.identificationNumber != null)
                                _buildInfoRow(
                                  'IC/Passport',
                                  _customer!.identificationNumber!,
                                ),
                              if (_customer!.registrationNumber != null)
                                _buildInfoRow(
                                  'Registration No.',
                                  _customer!.registrationNumber!,
                                ),
                              if (_customer!.sstNumber != null)
                                _buildInfoRow(
                                  'SST Number',
                                  _customer!.sstNumber!,
                                ),
                              if (_customer!.tin == null &&
                                  _customer!.identificationNumber == null)
                                Text(
                                  'No tax information available',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Contact Information
                      _buildSectionTitle('Contact Information'),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (_customer!.email != null)
                                _buildInfoRow('Email', _customer!.email!),
                              if (_customer!.contactNumber != null)
                                _buildInfoRow(
                                  'Phone',
                                  _customer!.contactNumber!,
                                ),
                              if (_customer!.email == null &&
                                  _customer!.contactNumber == null)
                                Text(
                                  'No contact information available',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Addresses
                      _buildSectionTitle(
                        'Address${_customer!.addresses.length > 1 ? 'es' : ''}',
                      ),
                      const SizedBox(height: 8),
                      ..._customer!.addresses.map((address) {
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: address.isPrimary
                                          ? AppColors.primary
                                          : Colors.grey[600],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      address.label ?? 'Address',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: address.isPrimary
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (address.isPrimary) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Primary',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  address.fullAddress,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 24),

                      // Notes
                      if (_customer!.notes != null) ...[
                        _buildSectionTitle('Notes'),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _customer!.notes!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Metadata
                      _buildSectionTitle('Details'),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildInfoRow(
                                'Created',
                                Helpers.formatDate(_customer!.createdAt),
                              ),
                              _buildInfoRow(
                                'Last Updated',
                                Helpers.formatDate(_customer!.updatedAt),
                              ),
                              if (_customer!.lastInvoiceDate != null)
                                _buildInfoRow(
                                  'Last Invoice',
                                  Helpers.formatDate(
                                    _customer!.lastInvoiceDate!,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
