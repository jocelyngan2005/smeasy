import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../backend/auth/services/auth_service.dart';
import '../../backend/auth/models/user_model.dart';
import '../../utils/helpers.dart';

class ManageProfileScreen extends StatefulWidget {
  const ManageProfileScreen({super.key});

  @override
  State<ManageProfileScreen> createState() => _ManageProfileScreenState();
}

class _ManageProfileScreenState extends State<ManageProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _businessNameController;
  late TextEditingController _businessTypeController;
  late TextEditingController _ssmNumberController;
  late TextEditingController _tinController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    _businessNameController = TextEditingController(text: user?.businessName ?? '');
    _businessTypeController = TextEditingController(text: user?.businessType ?? '');
    _ssmNumberController = TextEditingController(text: user?.ssmNumber ?? '');
    _tinController = TextEditingController(text: user?.tin ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _ssmNumberController.dispose();
    _tinController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) return;

      final updatedUser = UserModel(
        id: currentUser.id,
        email: _emailController.text.trim(),
        businessName: _businessNameController.text.trim(),
        businessType: _businessTypeController.text.trim().isEmpty 
            ? null 
            : _businessTypeController.text.trim(),
        ssmNumber: _ssmNumberController.text.trim().isEmpty 
            ? null 
            : _ssmNumberController.text.trim(),
        tin: _tinController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        createdAt: currentUser.createdAt,
        isVerified: currentUser.isVerified,
      );

      await authService.updateProfile(updatedUser);

      if (mounted) {
        Helpers.showSuccessSnackbar(context, 'Profile updated successfully');
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorSnackbar(context, 'Failed to update profile');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Manage Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            TextButton(
              onPressed: () {
                setState(() => _isEditing = false);
                // Reset controllers to original values
                _businessNameController.text = user?.businessName ?? '';
                _businessTypeController.text = user?.businessType ?? '';
                _ssmNumberController.text = user?.ssmNumber ?? '';
                _tinController.text = user?.tin ?? '';
                _emailController.text = user?.email ?? '';
                _phoneController.text = user?.phone ?? '';
                _addressController.text = user?.address ?? '';
              },
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Business Registration Section
            _buildSectionHeader('Business Registration'),
            const SizedBox(height: 12),
            _buildCard([
              _buildTextField(
                controller: _businessNameController,
                label: 'Business Name',
                icon: Icons.business,
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Business name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _businessTypeController,
                label: 'Business Type',
                hint: 'e.g., Sole Proprietor, Sdn Bhd',
                icon: Icons.category,
                enabled: _isEditing,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _ssmNumberController,
                label: 'SSM Registration Number',
                hint: 'e.g., 202301012345',
                icon: Icons.business_center,
                enabled: _isEditing,
              ),
            ]),
            const SizedBox(height: 24),

            // Tax Information Section
            _buildSectionHeader('Tax Information'),
            const SizedBox(height: 12),
            _buildCard([
              _buildTextField(
                controller: _tinController,
                label: 'TIN Number',
                hint: 'Tax Identification Number',
                icon: Icons.receipt_long,
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'TIN is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (!_isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        user?.isVerified == true
                            ? Icons.verified
                            : Icons.pending,
                        size: 16,
                        color: user?.isVerified == true
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user?.isVerified == true
                            ? 'Verified'
                            : 'Verification Pending',
                        style: TextStyle(
                          fontSize: 14,
                          color: user?.isVerified == true
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
            const SizedBox(height: 24),

            // Contact Information Section
            _buildSectionHeader('Contact Information'),
            const SizedBox(height: 12),
            _buildCard([
              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email,
                enabled: _isEditing,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Contact Number',
                hint: 'e.g., 0123456789',
                icon: Icons.phone,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _addressController,
                label: 'Business Address',
                hint: 'Full address including city and state',
                icon: Icons.location_on,
                enabled: _isEditing,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Address is required';
                  }
                  return null;
                },
              ),
            ]),
            const SizedBox(height: 24),

            // e-Invoice Compliance Information
            const SizedBox(height: 32),

            // Save Button
            if (_isEditing)
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: TextStyle(
            fontSize: 15,
            color: enabled ? Colors.black87 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildComplianceItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
