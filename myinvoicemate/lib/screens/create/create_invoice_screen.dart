import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/gemini_service.dart';
import '../../services/invoice_service.dart';
import '../../models/invoice_model.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../invoices/invoice_detail_screen.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _geminiService = GeminiService();
  final _invoiceService = InvoiceService();

  // Voice tab
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isProcessingVoice = false;
  String _transcription = '';
  final _textController = TextEditingController();

  // Scanner tab
  final _picker = ImagePicker();
  File? _imageFile;
  bool _isProcessingImage = false;
  Map<String, dynamic>? _extractedData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // Voice Invoice Methods
  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _transcription = result.recognizedWords;
            _textController.text = _transcription;
          });
        },
      );
    } else {
      Helpers.showErrorSnackbar(context, 'Voice recognition not available');
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _generateInvoiceFromVoice() async {
    if (_textController.text.trim().isEmpty) {
      Helpers.showErrorSnackbar(
        context,
        'Please enter or speak invoice details',
      );
      return;
    }

    setState(() => _isProcessingVoice = true);

    try {
      final invoice = await _geminiService.generateInvoiceFromVoice(
        _textController.text,
      );

      await _invoiceService.createInvoice(invoice);

      if (mounted) {
        Helpers.showSuccessSnackbar(
          context,
          'Invoice draft created successfully!',
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(invoice: invoice),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorSnackbar(
          context,
          'Failed to generate invoice. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingVoice = false);
    }
  }

  // Receipt Scanner Methods
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

    setState(() => _isProcessingImage = true);

    try {
      final data = await _geminiService.extractDataFromReceipt(
        _imageFile!.path,
      );

      setState(() {
        _extractedData = data;
        _isProcessingImage = false;
      });

      Helpers.showSuccessSnackbar(context, 'Receipt processed successfully!');
    } catch (e) {
      setState(() => _isProcessingImage = false);
      Helpers.showErrorSnackbar(
        context,
        'Failed to process receipt. Please try again.',
      );
    }
  }

  Future<void> _createInvoiceFromExtractedData() async {
    if (_extractedData == null) return;

    setState(() => _isProcessingImage = true);

    try {
      final lineItems = (_extractedData!['lineItems'] as List)
          .map(
            (item) => InvoiceLineItem(
              description: item['description'],
              quantity: item['quantity'],
              unitPrice: item['unitPrice'],
              amount: item['amount'],
            ),
          )
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
        Helpers.showSuccessSnackbar(context, 'Invoice draft created!');

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
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.mic), text: 'Voice'),
            Tab(icon: Icon(Icons.camera_alt), text: 'Scanner'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildVoiceTab(), _buildScannerTab()],
      ),
    );
  }

  Widget _buildVoiceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions Card
          Card(
            color: AppColors.primary.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Tap the microphone to speak\n'
                    '2. Say customer name, items sold, and amounts\n'
                    '3. AI will structure it into an invoice\n'
                    '4. Review and edit the generated invoice',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Example prompt
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Example:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"Create invoice for ABC Trading, 10 units of Product A at RM 1200 each, total RM 12000"',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Voice/Text Input
          TextField(
            controller: _textController,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Invoice Details',
              hintText: 'Speak or type invoice details here...',
              alignLabelWithHint: true,
              suffixIcon: _textController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _textController.clear();
                          _transcription = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 24),

          // Voice Button
          SizedBox(
            height: 120,
            child: ElevatedButton(
              onPressed: _isProcessingVoice
                  ? null
                  : (_isListening ? _stopListening : _startListening),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening
                    ? AppColors.error
                    : AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isListening ? Icons.mic : Icons.mic_none, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    _isListening ? 'Listening...' : 'Tap to Speak',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Generate Button
          ElevatedButton.icon(
            onPressed: _isProcessingVoice || _textController.text.isEmpty
                ? null
                : _generateInvoiceFromVoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _isProcessingVoice
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _isProcessingVoice ? 'Generating...' : 'Generate Invoice with AI',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return SingleChildScrollView(
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
                child: Image.file(_imageFile!, fit: BoxFit.contain),
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
                  onPressed: _isProcessingImage
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
                  onPressed: _isProcessingImage
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
          if (_isProcessingImage)
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
          if (_extractedData != null && !_isProcessingImage) ...[
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
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Extracted Data (${(_extractedData!['confidence'] * 100).toStringAsFixed(0)}% confidence)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
