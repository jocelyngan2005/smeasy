import 'package:flutter/material.dart';
import '../../backend/invoice/models/invoice_model.dart';
import '../../backend/invoice/models/invoice_adapter.dart';
import '../../backend/invoice/services/invoice_service.dart';
import '../../backend/invoice/services/gemini_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _invoiceService = InvoiceService();
  final _geminiService = GeminiService();
  bool _isLoading = false;
  Map<String, dynamic>? _validationResult;

  Future<void> _submitToMyInvois() async {
    if (!widget.invoice.requiresSubmission) {
      Helpers.showInfoSnackbar(
        context,
        'Invoice below RM10,000 - MyInvois submission optional',
      );
      return;
    }

    final confirm = await Helpers.showConfirmDialog(
      context,
      title: 'Submit to MyInvois',
      message: 'Submit this invoice to LHDN MyInvois system?',
      confirmText: 'Submit',
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      final result = await _invoiceService.submitToMyInvois(widget.invoice.id);

      if (mounted) {
        Helpers.showSuccessSnackbar(context, result['message']);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorSnackbar(context, 'Submission failed');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _validateInvoice() async {
    setState(() => _isLoading = true);

    try {
      final validation = await _geminiService.validateInvoice(widget.invoice);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  validation['isValid'] ? Icons.check_circle : Icons.error,
                  color: validation['isValid']
                      ? AppColors.success
                      : AppColors.error,
                ),
                const SizedBox(width: 8),
                const Text('Validation Result'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (validation['errors'].isNotEmpty) ...[
                  const Text(
                    'Errors:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...(validation['errors'] as List).map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        '• $error',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
                if (validation['warnings'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Warnings:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...(validation['warnings'] as List).map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        '• $warning',
                        style: const TextStyle(color: AppColors.warning),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Compliance Score: ${validation['complianceScore']}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Helpers.showErrorSnackbar(context, 'Validation failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          widget.invoice.invoiceNumber,
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Helpers.showInfoSnackbar(context, 'Edit feature coming soon');
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Helpers.showInfoSnackbar(context, 'Share feature coming soon');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card
                Card(
                  elevation: 0,
                  color: Helpers.getStatusColor(
                    widget.invoice.status,
                  ).withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(widget.invoice.status),
                          color: Helpers.getStatusColor(widget.invoice.status),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status: ${widget.invoice.status.toUpperCase()}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Helpers.getStatusColor(
                                  widget.invoice.status,
                                ),
                              ),
                            ),
                            if (widget.invoice.myInvoisId != null)
                              Text(
                                'MyInvois ID: ${widget.invoice.myInvoisId}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Validation Status
                if (_validationResult != null) ...[
                  _buildSectionTitle('Validation Status'),
                  Card(
                    elevation: 0,
                    color: (_validationResult!['isValid'] as bool)
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                (_validationResult!['isValid'] as bool)
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: (_validationResult!['isValid'] as bool)
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (_validationResult!['isValid'] as bool)
                                    ? 'Valid'
                                    : 'Invalid',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: (_validationResult!['isValid'] as bool)
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Score: ${_validationResult!['complianceScore']}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if ((_validationResult!['errors'] as List)
                              .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Errors:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            ...(_validationResult!['errors'] as List).map(
                              (error) => Padding(
                                padding: const EdgeInsets.only(left: 8, top: 4),
                                child: Text(
                                  '• $error',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if ((_validationResult!['warnings'] as List)
                              .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Warnings:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            ...(_validationResult!['warnings'] as List).map(
                              (warning) => Padding(
                                padding: const EdgeInsets.only(left: 8, top: 4),
                                child: Text(
                                  '• $warning',
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Seller Info
                _buildSectionTitle('Seller Information'),
                _buildInfoCard([
                  _buildInfoRow('Business', widget.invoice.sellerName),
                  _buildInfoRow('TIN', widget.invoice.sellerTin),
                ]),
                const SizedBox(height: 16),

                // Buyer Info
                _buildSectionTitle('Buyer Information'),
                _buildInfoCard([
                  _buildInfoRow('Name', widget.invoice.buyerName),
                  _buildInfoRow('TIN', widget.invoice.buyerTin),
                  _buildInfoRow(
                    'Registration/ID/Passport',
                    widget.invoice.buyerRegistrationNumber,
                  ),
                  _buildInfoRow('Address', widget.invoice.buyerAddress),
                  _buildInfoRow(
                    'Contact Number',
                    widget.invoice.buyerContactNumber,
                  ),
                  _buildInfoRow('SST Number', widget.invoice.buyerSstNumber),
                ]),
                const SizedBox(height: 16),

                // Shipping Recipient Info (if available)
                if (widget.invoice.shippingRecipientName != null) ...[
                  _buildSectionTitle('Shipping Recipient'),
                  _buildInfoCard([
                    _buildInfoRow(
                      'Name',
                      widget.invoice.shippingRecipientName!,
                    ),
                    if (widget.invoice.shippingRecipientTin != null)
                      _buildInfoRow(
                        'TIN',
                        widget.invoice.shippingRecipientTin!,
                      ),
                    if (widget.invoice.shippingRecipientRegistrationNumber !=
                        null)
                      _buildInfoRow(
                        'Registration/ID/Passport',
                        widget.invoice.shippingRecipientRegistrationNumber!,
                      ),
                    if (widget.invoice.shippingRecipientAddress != null)
                      _buildInfoRow(
                        'Address',
                        widget.invoice.shippingRecipientAddress!,
                      ),
                  ]),
                  const SizedBox(height: 16),
                ],

                // Invoice Details
                _buildSectionTitle('Invoice Details'),
                _buildInfoCard([
                  _buildInfoRow('Invoice Number', widget.invoice.invoiceNumber),
                  _buildInfoRow(
                    'Issue Date',
                    Helpers.formatDate(widget.invoice.issueDate),
                  ),
                  _buildInfoRow(
                    'Created',
                    Helpers.formatDateTime(widget.invoice.createdAt),
                  ),
                  if (widget.invoice.submittedAt != null)
                    _buildInfoRow(
                      'Submitted',
                      Helpers.formatDateTime(widget.invoice.submittedAt!),
                    ),
                ]),
                const SizedBox(height: 16),

                // Line Items
                _buildSectionTitle('Line Items'),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Column Headers
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Description',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  'Qty',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  'Unit Price\n(RM)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  'Amount\n(RM)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Line Items
                        ...widget.invoice.lineItems.map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.description,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${item.quantity.toInt()}',
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    item.unitPrice.toStringAsFixed(2),
                                    style: const TextStyle(fontSize: 11),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    (item.quantity * item.unitPrice).toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Total Product/Service Price
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Total Product/Service Price',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                Helpers.formatCurrency(
                                  widget.invoice.lineItems.fold(
                                    0.0,
                                    (sum, item) => sum + (item.quantity * item.unitPrice),
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Subtotal
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Subtotal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                Helpers.formatCurrency(widget.invoice.subtotal),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tax
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Tax',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                Helpers.formatCurrency(
                                  widget.invoice.taxAmount,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Total
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(6),
                              bottomRight: Radius.circular(6),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                Helpers.formatCurrency(
                                  widget.invoice.totalAmount,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E3193), Color(0xFF0533F4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _validateInvoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.verified_user),
            label: const Text(
              'Verify',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Icons.send;
      case 'valid':
        return Icons.check_circle;
      case 'invalid':
        return Icons.cancel;
      case 'cancelled':
        return Icons.block;
      default:
        return Icons.drafts;
    }
  }
}
