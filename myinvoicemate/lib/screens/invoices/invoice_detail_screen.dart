import 'package:flutter/material.dart';
import '../../models/invoice_model.dart';
import '../../services/invoice_service.dart';
import '../../services/gemini_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _invoiceService = InvoiceService();
  final _geminiService = GeminiService();
  bool _isLoading = false;

  Future<void> _submitToMyInvois() async {
    if (!widget.invoice.requiresMyInvoisSubmission) {
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
                  color: validation['isValid'] ? AppColors.success : AppColors.error,
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
                      child: Text('• $error', style: const TextStyle(color: AppColors.error)),
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
                      child: Text('• $warning', style: const TextStyle(color: AppColors.warning)),
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
        title: Text(widget.invoice.invoiceNumber, style: const TextStyle(color: Colors.black)),
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
                  color: Helpers.getStatusColor(widget.invoice.status).withOpacity(0.1),
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
                                color: Helpers.getStatusColor(widget.invoice.status),
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
                  _buildInfoRow('Address', widget.invoice.buyerAddress),
                ]),
                const SizedBox(height: 16),

                // Invoice Details
                _buildSectionTitle('Invoice Details'),
                _buildInfoCard([
                  _buildInfoRow('Invoice Number', widget.invoice.invoiceNumber),
                  _buildInfoRow('Issue Date', Helpers.formatDate(widget.invoice.issueDate)),
                  _buildInfoRow('Created', Helpers.formatDateTime(widget.invoice.createdAt)),
                  if (widget.invoice.submittedAt != null)
                    _buildInfoRow('Submitted', Helpers.formatDateTime(widget.invoice.submittedAt!)),
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
                        ...widget.invoice.lineItems.map((item) => _buildLineItem(item)),
                        const Divider(),
                        _buildTotalRow('Subtotal', widget.invoice.subtotal),
                        _buildTotalRow('Tax', widget.invoice.taxAmount),
                        const Divider(thickness: 2),
                        _buildTotalRow('Total', widget.invoice.totalAmount, isBold: true),
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
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
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
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600]),
            ),
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

  Widget _buildLineItem(InvoiceLineItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.description,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.quantity} × ${Helpers.formatCurrency(item.unitPrice)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              Text(
                Helpers.formatCurrency(item.amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            Helpers.formatCurrency(amount),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
              color: isBold ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _validateInvoice,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.verified_user),
              label: const Text('Validate'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading || widget.invoice.myInvoisId != null
                  ? null
                  : _submitToMyInvois,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.cloud_upload),
              label: Text(
                widget.invoice.myInvoisId != null ? 'Submitted' : 'Submit',
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Icons.send;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.drafts;
    }
  }
}
