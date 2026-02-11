import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/gemini_service.dart';
import '../../services/invoice_service.dart';
import '../../models/invoice_model.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../invoices/invoice_detail_screen.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final _geminiService = GeminiService();
  final _invoiceService = InvoiceService();
  final _picker = ImagePicker();
  File? _imageFile;
  bool _isProcessing = false;
  Map<String, dynamic>? _extractedData;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _extractedData = null;
        });
        _processImage();
      }
    } catch (e) {
      Helpers.showErrorSnackbar(context, 'Failed to pick image');
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    setState(() => _isProcessing = true);

    try {
      // Use Gemini Vision to extract data
      final data = await _geminiService.extractDataFromReceipt(_imageFile!.path);
      
      setState(() {
        _extractedData = data;
        _isProcessing = false;
      });

      Helpers.showSuccessSnackbar(
        context,
        'Receipt processed successfully!',
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      Helpers.showErrorSnackbar(
        context,
        'Failed to process receipt. Please try again.',
      );
    }
  }

  Future<void> _createInvoiceFromExtractedData() async {
    if (_extractedData == null) return;

    setState(() => _isProcessing = true);

    try {
      final lineItems = (_extractedData!['lineItems'] as List)
          .map((item) => InvoiceLineItem(
                description: item['description'],
                quantity: item['quantity'],
                unitPrice: item['unitPrice'],
                amount: item['amount'],
              ))
          .toList();

      final invoice = InvoiceModel(
        id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
        invoiceNumber: 'DRAFT-${DateTime.now().millisecondsSinceEpoch}',
        sellerId: 'user123',
        sellerName: 'SME Trading Sdn Bhd',
        sellerTin: 'C12345678900',
        buyerId: '',
        buyerName: _extractedData!['buyerName'] ?? '',
        buyerTin: _extractedData!['buyerTin'] ?? '',
        buyerAddress: _extractedData!['buyerAddress'] ?? '',
        issueDate: DateTime.parse(_extractedData!['date']),
        lineItems: lineItems,
        subtotal: _extractedData!['totalAmount'],
        taxAmount: 0.0,
        totalAmount: _extractedData!['totalAmount'],
        status: AppConstants.statusDraft,
        createdAt: DateTime.now(),
      );

      await _invoiceService.createInvoice(invoice);

      if (mounted) {
        Helpers.showSuccessSnackbar(
          context,
          'Invoice draft created!',
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(invoice: invoice),
          ),
        );
      }
    } catch (e) {
      Helpers.showErrorSnackbar(context, 'Failed to create invoice');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Scanner'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              color: AppColors.accent.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.camera_alt, color: AppColors.accent),
                        SizedBox(width: 8),
                        Text(
                          'AI Receipt Extraction',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Scan receipts and invoices to automatically extract:\n'
                      '• Customer information (TIN, name, address)\n'
                      '• Line items and amounts\n'
                      '• Dates and totals',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Image Preview
            if (_imageFile != null)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _imageFile!,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.image, size: 64, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No image selected',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Camera/Gallery Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            // Processing Indicator
            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Processing with AI...'),
                  ],
                ),
              ),

            // Extracted Data
            if (_extractedData != null && !_isProcessing) ...[
              const SizedBox(height: 24),
              Card(
                color: AppColors.success.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.success),
                          const SizedBox(width: 8),
                          Text(
                            'Extracted Data (${(_extractedData!['confidence'] * 100).toStringAsFixed(0)}% confidence)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      _buildDataRow('Buyer', _extractedData!['buyerName']),
                      _buildDataRow('TIN', _extractedData!['buyerTin']),
                      _buildDataRow(
                        'Total',
                        Helpers.formatCurrency(_extractedData!['totalAmount']),
                      ),
                      _buildDataRow(
                        'Items',
                        '${(_extractedData!['lineItems'] as List).length} items',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _createInvoiceFromExtractedData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.add),
                label: const Text(
                  'Create Invoice from Data',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
