import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer_model.dart';
import '../../services/customer_service.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? customer; // For editing existing customer

  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerService = CustomerService();

  // Controllers
  final _nameController = TextEditingController();
  final _tinController = TextEditingController();
  final _icController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _sstNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _notesController = TextEditingController();

  // Address controllers
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _line3Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _loadCustomerData();
    }
  }

  void _loadCustomerData() {
    final customer = widget.customer!;
    _nameController.text = customer.name;
    _tinController.text = customer.tin ?? '';
    _icController.text = customer.identificationNumber ?? '';
    _registrationNumberController.text = customer.registrationNumber ?? '';
    _contactNumberController.text = customer.contactNumber ?? '';
    _sstNumberController.text = customer.sstNumber ?? '';
    _emailController.text = customer.email ?? '';
    _contactPersonController.text = customer.contactPerson ?? '';
    _notesController.text = customer.notes ?? '';
    _isFavorite = customer.isFavorite;

    if (customer.primaryAddress != null) {
      final addr = customer.primaryAddress!;
      _line1Controller.text = addr.line1;
      _line2Controller.text = addr.line2 ?? '';
      _line3Controller.text = addr.line3 ?? '';
      _cityController.text = addr.city;
      _stateController.text = addr.state;
      _postalCodeController.text = addr.postalCode;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tinController.dispose();
    _icController.dispose();
    _registrationNumberController.dispose();
    _contactNumberController.dispose();
    _sstNumberController.dispose();
    _emailController.dispose();
    _contactPersonController.dispose();
    _notesController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _line3Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      final addressId = widget.customer?.primaryAddress?.id ??
          '${DateTime.now().millisecondsSinceEpoch}_addr_1';

      final address = CustomerAddress(
        id: addressId,
        line1: _line1Controller.text.trim(),
        line2: _line2Controller.text.trim().isEmpty
            ? null
            : _line2Controller.text.trim(),
        line3: _line3Controller.text.trim().isEmpty
            ? null
            : _line3Controller.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        isPrimary: true,
        label: 'Primary',
      );

      final customer = Customer(
        id: widget.customer?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        tin: _tinController.text.trim().isEmpty
            ? null
            : _tinController.text.trim(),
        identificationNumber: _icController.text.trim().isEmpty
            ? null
            : _icController.text.trim(),
        registrationNumber: _registrationNumberController.text.trim().isEmpty
            ? null
            : _registrationNumberController.text.trim(),
        contactNumber: _contactNumberController.text.trim().isEmpty
            ? null
            : _contactNumberController.text.trim(),
        sstNumber: _sstNumberController.text.trim().isEmpty
            ? null
            : _sstNumberController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        contactPerson: _contactPersonController.text.trim().isEmpty
            ? null
            : _contactPersonController.text.trim(),
        addresses: [address],
        invoiceCount: widget.customer?.invoiceCount ?? 0,
        totalRevenue: widget.customer?.totalRevenue ?? 0,
        lastInvoiceDate: widget.customer?.lastInvoiceDate,
        createdAt: widget.customer?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        isFavorite: _isFavorite,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      bool success;
      if (widget.customer != null) {
        success = await _customerService.updateCustomer(customer);
      } else {
        final result = await _customerService.createCustomer(customer);
        success = result != null;
      }

      if (success) {
        if (mounted) {
          Navigator.pop(context, true);
          Helpers.showSuccessSnackbar(
            context,
            widget.customer != null
                ? 'Customer updated successfully'
                : 'Customer added successfully',
          );
        }
      } else {
        throw Exception('Failed to save customer');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorSnackbar(context, 'Failed to save customer: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        title: Text(
          widget.customer != null ? 'Edit Customer' : 'Add Customer',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Information
            _buildSectionTitle('Basic Information'),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name *',
                        hintText: 'Enter customer name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter customer name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tinController,
                      decoration: const InputDecoration(
                        labelText: 'TIN (Tax ID)',
                        hintText: 'e.g., C12345678901',
                        prefixIcon: Icon(Icons.business),
                        helperText: 'For companies/businesses',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _icController,
                      decoration: const InputDecoration(
                        labelText: 'IC/Passport Number',
                        hintText: 'e.g., 123456-78-9012',
                        prefixIcon: Icon(Icons.badge),
                        helperText: 'For individuals',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _registrationNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Registration Number',
                        hintText: 'Company registration number',
                        prefixIcon: Icon(Icons.app_registration),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Contact Information
            _buildSectionTitle('Contact Information'),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _contactNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        hintText: '+60123456789',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'customer@example.com',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Person',
                        hintText: 'Name of contact person',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sstNumberController,
                      decoration: const InputDecoration(
                        labelText: 'SST Number',
                        hintText: 'Enter NA if not registered',
                        prefixIcon: Icon(Icons.receipt),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Address
            _buildSectionTitle('Address'),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _line1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Address Line 1 *',
                        hintText: 'Street address',
                        prefixIcon: Icon(Icons.home),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _line2Controller,
                      decoration: const InputDecoration(
                        labelText: 'Address Line 2',
                        hintText: 'Apartment, suite, etc.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _line3Controller,
                      decoration: const InputDecoration(
                        labelText: 'Address Line 3',
                        hintText: 'Additional address info',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'City *',
                              hintText: 'City',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _postalCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Postal Code *',
                              hintText: '12345',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State *',
                        hintText: 'e.g., Selangor',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter state';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Notes
            _buildSectionTitle('Notes (Optional)'),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    hintText: 'Add any notes about this customer...',
                    border: InputBorder.none,
                  ),
                  maxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.customer != null
                            ? 'Update Customer'
                            : 'Save Customer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
