import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../backend/invoice/services/invoice_service.dart';
import '../../backend/invoice/models/invoice_model.dart';
import '../../backend/invoice/models/invoice_adapter.dart';
import '../../backend/invoice/models/invoice_draft.dart';
import '../../backend/invoice/services/invoice_orchestrator.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../invoices/invoice_detail_screen.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _orchestrator = InvoiceGenerationOrchestrator();
  final _invoiceService = InvoiceService();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isProcessing = false;
  String _transcription = '';
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _textFocusNode = FocusNode();

  final _picker = ImagePicker();
  File? _imageFile;
  Invoice? _previewInvoice;
  bool _isEditingInvoice = false;

  // Invoice editing controllers
  final _invoiceNumberController = TextEditingController();
  final _sellerNameController = TextEditingController();
  final _sellerTinController = TextEditingController();
  final _buyerIdController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _tinController = TextEditingController();
  final _buyerAddressController = TextEditingController();
  final _subtotalController = TextEditingController();
  final _taxAmountController = TextEditingController();
  final _statusController = TextEditingController();

  // Line item controllers
  final List<Map<String, TextEditingController>> _lineItemControllers = [];

  // Chat messages
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    // Auto-focus text field to show keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _textFocusNode.dispose();
    _invoiceNumberController.dispose();
    _sellerNameController.dispose();
    _sellerTinController.dispose();
    _buyerIdController.dispose();
    _customerNameController.dispose();
    _tinController.dispose();
    _buyerAddressController.dispose();
    _subtotalController.dispose();
    _taxAmountController.dispose();
    _statusController.dispose();
    // Dispose line item controllers
    for (var controllerMap in _lineItemControllers) {
      controllerMap['description']?.dispose();
      controllerMap['quantity']?.dispose();
      controllerMap['unitPrice']?.dispose();
    }
    _lineItemControllers.clear();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Voice Invoice Methods
  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onError: (error) {
        print('Speech recognition error: $error');
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        print('Speech recognition status: $status');
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _transcription = result.recognizedWords;
            _textController.text = _transcription;
          });
        },
        listenFor: const Duration(seconds: 30), // Listen for up to 30 seconds
        pauseFor: const Duration(seconds: 5), // Wait 5 seconds of silence before stopping
        partialResults: true, // Show results as user speaks
        cancelOnError: false, // Don't stop on minor errors
        listenMode: stt.ListenMode.confirmation, // Keep listening
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
    if (_textController.text.trim().isEmpty && _imageFile == null) {
      Helpers.showErrorSnackbar(
        context,
        'Please enter or speak invoice details',
      );
      return;
    }

    // Add user message to chat
    final userMessage = _textController.text;
    final attachedImage = _imageFile;

    setState(() {
      _messages.add({
        'type': 'user',
        'text': userMessage,
        'image': attachedImage,
        'timestamp': DateTime.now(),
      });
      // Add loading message
      _messages.add({'type': 'loading', 'timestamp': DateTime.now()});
      _isProcessing = true;
      _textController.clear();
      _imageFile = null;
    });

    _scrollToBottom();

    try {
      InvoiceGenerationResult result;
      
      // Process based on input type
      if (attachedImage != null) {
        // Receipt scanning with Gemini Vision
        result = await _orchestrator.generateFromReceiptFile(
          imageFile: attachedImage,
          userId: 'user123', // TODO: Replace with actual user ID from auth
          saveDraft: false, // Disable Firestore for testing
        );
      } else {
        // Voice/text input with Gemini AI
        result = await _orchestrator.generateFromVoiceOrText(
          input: userMessage,
          userId: 'user123', // TODO: Replace with actual user ID from auth
          saveDraft: false, // Disable Firestore for testing
        );
      }

      if (mounted && result.draft != null) {
        // Try to convert draft to invoice for preview
        Invoice? invoice;
        
        try {
          // Only convert if draft is ready, otherwise create a placeholder invoice
          if (result.draft!.isReadyForFinalization) {
            invoice = result.draft!.toInvoice(
              id: 'preview_${DateTime.now().millisecondsSinceEpoch}',
              createdBy: 'user123',
            );
          } else {
            // Create a placeholder invoice for preview with available data
            invoice = _createPlaceholderInvoice(result.draft!);
          }
        } catch (e) {
          print('Error converting draft to invoice: $e');
          // Create placeholder invoice as fallback
          invoice = _createPlaceholderInvoice(result.draft!);
        }

        setState(() {
          // Remove loading message
          _messages.removeWhere((msg) => msg['type'] == 'loading');
          
          // Add AI response with metadata
          final responseText = StringBuffer();
          responseText.writeln(result.message);
          
          // Add confidence score
          if (result.draft!.confidenceScore != null) {
            final confidence = (result.draft!.confidenceScore! * 100).toStringAsFixed(0);
            responseText.writeln('\n🎯 Confidence: $confidence%');
          }
          
          // Add extraction source
          if (attachedImage != null) {
            final ocrQuality = result.draft!.extractedEntities?.last ?? 'unknown';
            responseText.writeln('📸 OCR Quality: $ocrQuality');
          }
          
          // Add warnings if any
          if (result.draft!.warnings.isNotEmpty) {
            responseText.writeln('\n⚠️ Warnings:');
            for (var warning in result.draft!.warnings) {
              responseText.writeln('  • $warning');
            }
          }
          
          // Add missing fields if any
          if (result.draft!.missingFields.isNotEmpty) {
            responseText.writeln('\n📝 Missing fields:');
            for (var field in result.draft!.missingFields) {
              responseText.writeln('  • $field');
            }
          }
          
          _messages.add({
            'type': 'assistant',
            'text': responseText.toString(),
            'invoice': invoice,
            'timestamp': DateTime.now(),
          });
          _previewInvoice = invoice;
          _isProcessing = false;
        });

        _scrollToBottom();
      } else {
        throw Exception('No draft generated');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Remove loading message
          _messages.removeWhere((msg) => msg['type'] == 'loading');
          _messages.add({
            'type': 'error',
            'text': 'Failed to generate invoice: ${e.toString()}\n\nPlease try again or provide more details.',
            'timestamp': DateTime.now(),
          });
          _isProcessing = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.accent,
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        });
      }
    } catch (e) {
      Helpers.showErrorSnackbar(context, 'Failed to pick image');
    }
  }

  /// Create a placeholder invoice from incomplete draft data
  Invoice _createPlaceholderInvoice(InvoiceDraft draft) {
    // Use adapter to create invoice from partial data
    return InvoiceBuilder.fromSimpleData(
      id: 'preview_${DateTime.now().millisecondsSinceEpoch}',
      invoiceNumber: draft.invoiceNumber ?? 'DRAFT-${DateTime.now().millisecondsSinceEpoch}',
      sellerId: draft.vendor?.name ?? '',
      sellerName: draft.vendor?.name ?? '[Vendor Name Missing]',
      sellerTin: draft.vendor?.tin ?? '',
      sellerIdentificationNumber: draft.vendor?.identificationNumber ?? '',
      sellerContactNumber: draft.vendor?.contactNumber ?? draft.vendor?.phone ?? '',
      sellerSstNumber: draft.vendor?.sstNumber ?? '',
      sellerEmail: draft.vendor?.email ?? '',
      sellerAddress1: draft.vendor?.address?.line1 ?? '',
      sellerAddress2: draft.vendor?.address?.line2 ?? '',
      sellerCity: draft.vendor?.address?.city ?? '',
      sellerState: draft.vendor?.address?.state ?? '',
      sellerPostalCode: draft.vendor?.address?.postalCode ?? '',
      buyerId: draft.buyer?.name ?? '',
      buyerName: draft.buyer?.name ?? '[Buyer Name Missing]',
      buyerTin: draft.buyer?.tin ?? '',
      buyerIdentificationNumber: draft.buyer?.identificationNumber ?? '',
      buyerContactNumber: draft.buyer?.contactNumber ?? draft.buyer?.phone ?? '',
      buyerSstNumber: draft.buyer?.sstNumber ?? '',
      buyerEmail: draft.buyer?.email ?? '',
      buyerAddress1: draft.buyer?.address?.line1 ?? '',
      buyerAddress2: draft.buyer?.address?.line2 ?? '',
      buyerCity: draft.buyer?.address?.city ?? '',
      buyerState: draft.buyer?.address?.state ?? '',
      buyerPostalCode: draft.buyer?.address?.postalCode ?? '',
      issueDate: draft.issueDate ?? DateTime.now(),
      dueDate: draft.dueDate,
      lineItems: draft.lineItems.map((item) {
        final lineSubtotal = item.quantity * item.unitPrice;
        final lineTaxAmount = item.taxRate != null 
            ? lineSubtotal * (item.taxRate! / 100) 
            : 0.0;
        
        return InvoiceLineItem(
          id: item.id,
          description: item.description,
          quantity: item.quantity,
          unit: item.unit,
          unitPrice: item.unitPrice,
          subtotal: lineSubtotal,
          taxRate: item.taxRate,
          taxAmount: lineTaxAmount,
          totalAmount: lineSubtotal + lineTaxAmount,
          taxType: item.taxType,
        );
      }).toList(),
      subtotal: draft.subtotal ?? 0.0,
      taxAmount: draft.taxAmount ?? 0.0,
      totalAmount: draft.totalAmount ?? 0.0,
      status: 'draft',
      createdBy: 'user123',
      source: draft.source,
    );
  }

  Future<void> _saveInvoice() async {
    if (_previewInvoice == null) return;

    setState(() => _isProcessing = true);

    try {
      await _invoiceService.createInvoice(_previewInvoice!);

      if (mounted) {
        Helpers.showSuccessSnackbar(context, 'Invoice saved successfully!');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(invoice: _previewInvoice!),
          ),
        );
      }
    } catch (e) {
      Helpers.showErrorSnackbar(context, 'Failed to save invoice');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _cancelPreview() {
    setState(() {
      _previewInvoice = null;
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Create Invoice',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          // Chat Messages Area
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E3193), Color(0xFF0533F4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'AI Invoice Assistant',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Describe your invoice or attach a receipt image, and I\'ll help you create it',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Input Container at Bottom
          Container(
            decoration: const BoxDecoration(color: Colors.white),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Preview if attached
                if (_imageFile != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() => _imageFile = null);
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              padding: const EdgeInsets.all(4),
                            ),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Input Row
                Row(
                  children: [
                    // Add button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, size: 24),
                        onPressed: _isProcessing
                            ? null
                            : _showImageSourceOptions,
                        color: Colors.grey[700],
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Text Input with integrated mic/send button wrapped in grey container
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                focusNode: _textFocusNode,
                                maxLines: null,
                                decoration: InputDecoration(
                                  hintText: 'Ask anything',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 15),
                                onChanged: (value) => setState(() {}),
                              ),
                            ),
                            // Mic icon (shows when no text and not listening)
                            if (_textController.text.isEmpty &&
                                !_isListening &&
                                !_isProcessing)
                              IconButton(
                                icon: const Icon(Icons.mic_none, size: 22),
                                onPressed: _startListening,
                                color: Colors.grey[700],
                                padding: const EdgeInsets.all(8),
                              ),
                            // Listening indicator
                            if (_isListening)
                              IconButton(
                                icon: const Icon(Icons.mic, size: 22),
                                onPressed: _stopListening,
                                color: Colors.red,
                                padding: const EdgeInsets.all(8),
                              ),
                            // Voice agent button / Send button (gradient, changes icon based on input)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2E3193),
                                    Color(0xFF0533F4),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _textController.text.isNotEmpty ||
                                          _imageFile != null
                                      ? Icons.send_rounded
                                      : Icons.graphic_eq_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                onPressed:
                                    (_textController.text.isNotEmpty ||
                                            _imageFile != null) &&
                                        !_isProcessing
                                    ? _generateInvoiceFromVoice
                                    : null,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['type'] == 'user';
    final isError = message['type'] == 'error';
    final isLoading = message['type'] == 'loading';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E3193), Color(0xFF0533F4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: isLoading
                ? const _LoadingMessageBubble()
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF2E3193)
                          : isError
                          ? Colors.red[50]
                          : Colors.white,
                      border: !isUser && !isError
                          ? Border.all(color: Colors.grey[300]!, width: 1)
                          : null,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      boxShadow: isUser
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message['image'] != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              message['image'],
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (message['text'] != null &&
                            message['text'].isNotEmpty)
                          Text(
                            message['text'],
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        if (message['invoice'] != null)
                          _buildInvoicePreviewCard(message['invoice']),
                      ],
                    ),
                  ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent.withOpacity(0.2),
              child: const Icon(
                Icons.person,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoicePreviewCard(Invoice invoice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Invoice Preview',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                _isEditingInvoice ? Icons.check : Icons.edit,
                size: 18,
                color: AppColors.primary,
              ),
              onPressed: () {
                setState(() {
                  if (_isEditingInvoice) {
                    // Save changes
                    if (_previewInvoice != null) {
                      // Build updated line items from controllers
                      final updatedLineItems = <InvoiceLineItem>[];
                      for (int i = 0; i < _lineItemControllers.length; i++) {
                        final description =
                            _lineItemControllers[i]['description']!.text;
                        final quantity =
                            double.tryParse(
                              _lineItemControllers[i]['quantity']!.text,
                            ) ??
                            0.0;
                        final unitPrice =
                            double.tryParse(
                              _lineItemControllers[i]['unitPrice']!.text,
                            ) ??
                            0.0;

                        // Use the helper to create properly structured line item
                        updatedLineItems.add(
                          InvoiceLineItemHelper.createSimple(
                            description: description,
                            quantity: quantity,
                            unitPrice: unitPrice,
                            taxRate: _previewInvoice!.lineItems[i].taxRate,
                          ),
                        );
                      }

                      // Calculate totals from line items
                      final subtotal = updatedLineItems.fold(
                        0.0,
                        (sum, item) => sum + item.subtotal,
                      );
                      final taxAmount = updatedLineItems.fold(
                        0.0,
                        (sum, item) => sum + (item.taxAmount ?? 0.0),
                      );
                      final totalAmount = updatedLineItems.fold(
                        0.0,
                        (sum, item) => sum + item.totalAmount,
                      );

                      // Parse address from text field
                      final buyerAddressParts = _buyerAddressController.text.split(', ');
                      
                      // Use copyWith to update the invoice
                      _previewInvoice = _previewInvoice!.copyWith(
                        vendor: _previewInvoice!.vendor.copyWith(
                          name: _sellerNameController.text,
                          tin: _sellerTinController.text,
                        ),
                        buyer: _previewInvoice!.buyer.copyWith(
                          name: _customerNameController.text,
                          tin: _tinController.text,
                          address: buyerAddressParts.isNotEmpty
                              ? Address(
                                  line1: buyerAddressParts[0],
                                  line2: buyerAddressParts.length > 1 ? buyerAddressParts[1] : null,
                                  city: _previewInvoice!.buyer.address.city,
                                  state: _previewInvoice!.buyer.address.state,
                                  postalCode: _previewInvoice!.buyer.address.postalCode,
                                )
                              : _previewInvoice!.buyer.address,
                        ),
                        lineItems: updatedLineItems,
                        subtotal: subtotal,
                        taxAmount: taxAmount,
                        totalAmount: totalAmount,
                      );
                    }
                    _isEditingInvoice = false;
                  } else {
                    // Enter edit mode and populate controllers
                    if (_previewInvoice != null) {
                      _invoiceNumberController.text =
                          _previewInvoice!.invoiceNumber;
                      _sellerNameController.text = _previewInvoice!.sellerName;
                      _sellerTinController.text = _previewInvoice!.sellerTin;
                      _buyerIdController.text = _previewInvoice!.buyerId;
                      _customerNameController.text = _previewInvoice!.buyerName;
                      _tinController.text = _previewInvoice!.buyerTin;
                      _buyerAddressController.text =
                          _previewInvoice!.buyerAddress;
                      _subtotalController.text = _previewInvoice!.subtotal
                          .toStringAsFixed(2);
                      _taxAmountController.text = _previewInvoice!.taxAmount
                          .toStringAsFixed(2);
                      _statusController.text = _previewInvoice!.status;

                      // Create controllers for line items
                      _lineItemControllers.clear();
                      for (var item in _previewInvoice!.lineItems) {
                        _lineItemControllers.add({
                          'description': TextEditingController(
                            text: item.description,
                          ),
                          'quantity': TextEditingController(
                            text: item.quantity.toString(),
                          ),
                          'unitPrice': TextEditingController(
                            text: item.unitPrice.toStringAsFixed(2),
                          ),
                        });
                      }
                    }
                    _isEditingInvoice = true;
                  }
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDataRow('Invoice #', invoice.invoiceNumber, isEditable: false),
        const SizedBox(height: 8),
        const Text(
          'Seller Information',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        _buildDataRow(
          'Seller Name',
          invoice.sellerName,
          controller: _sellerNameController,
        ),
        _buildDataRow(
          'Seller TIN',
          invoice.sellerTin,
          controller: _sellerTinController,
        ),
        const SizedBox(height: 8),
        const Text(
          'Buyer Information',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        _buildDataRow(
          'Buyer ID',
          invoice.buyerId,
          controller: _buyerIdController,
        ),
        _buildDataRow(
          'Buyer Name',
          invoice.buyerName,
          controller: _customerNameController,
        ),
        _buildDataRow(
          'Buyer TIN',
          invoice.buyerTin,
          controller: _tinController,
        ),
        _buildDataRow(
          'Address',
          invoice.buyerAddress,
          controller: _buyerAddressController,
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        _buildDataRow('Date', Helpers.formatDate(invoice.issueDate)),
        _buildDataRow('Status', invoice.status, controller: _statusController),
        const SizedBox(height: 8),
        const Text(
          'Items',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        // Column Headers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                width: 60,
                child: Text(
                  'Unit Price',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Amount',
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
        ...invoice.lineItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Expanded(
                  flex: 3,
                  child:
                      _isEditingInvoice && _lineItemControllers.length > index
                      ? TextField(
                          controller:
                              _lineItemControllers[index]['description'],
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                        )
                      : Text(
                          item.description,
                          style: const TextStyle(fontSize: 12),
                        ),
                ),
                const SizedBox(width: 4),
                // Quantity
                SizedBox(
                  width: 40,
                  child:
                      _isEditingInvoice && _lineItemControllers.length > index
                      ? TextField(
                          controller: _lineItemControllers[index]['quantity'],
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (val) => setState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                        )
                      : Text(
                          '${item.quantity.toInt()}',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                ),
                const SizedBox(width: 4),
                // Unit Price
                SizedBox(
                  width: 60,
                  child:
                      _isEditingInvoice && _lineItemControllers.length > index
                      ? TextField(
                          controller: _lineItemControllers[index]['unitPrice'],
                          style: const TextStyle(fontSize: 11),
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (val) => setState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                        )
                      : Text(
                          Helpers.formatCurrency(item.unitPrice),
                          style: const TextStyle(fontSize: 11),
                          textAlign: TextAlign.right,
                        ),
                ),
                const SizedBox(width: 4),
                // Amount (calculated)
                SizedBox(
                  width: 60,
                  child: Text(
                    _isEditingInvoice && _lineItemControllers.length > index
                        ? Helpers.formatCurrency(
                            (double.tryParse(
                                      _lineItemControllers[index]['quantity']!
                                          .text,
                                    ) ??
                                    0.0) *
                                (double.tryParse(
                                      _lineItemControllers[index]['unitPrice']!
                                          .text,
                                    ) ??
                                    0.0),
                          )
                        : Helpers.formatCurrency((item.quantity * item.unitPrice)),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        // Total Product/Service Price
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Product/Service Price',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _isEditingInvoice
                    ? Helpers.formatCurrency(
                        _lineItemControllers.fold(0.0, (sum, controller) {
                          final qty =
                              double.tryParse(controller['quantity']!.text) ??
                              0.0;
                          final price =
                              double.tryParse(controller['unitPrice']!.text) ??
                              0.0;
                          return sum + (qty * price);
                        }),
                      )
                    : Helpers.formatCurrency(
                        invoice.lineItems.fold(
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
        // Subtotal (calculated, non-editable)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Subtotal',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                _isEditingInvoice
                    ? Helpers.formatCurrency(
                        _lineItemControllers.fold(0.0, (sum, controller) {
                          final qty =
                              double.tryParse(controller['quantity']!.text) ??
                              0.0;
                          final price =
                              double.tryParse(controller['unitPrice']!.text) ??
                              0.0;
                          return sum + (qty * price);
                        }),
                      )
                    : Helpers.formatCurrency(invoice.subtotal),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Tax (editable)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Tax',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              if (_isEditingInvoice)
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _taxAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  Helpers.formatCurrency(invoice.taxAmount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        // Total (calculated)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _isEditingInvoice
                    ? Helpers.formatCurrency(
                        _lineItemControllers.fold(0.0, (sum, controller) {
                              final qty =
                                  double.tryParse(
                                    controller['quantity']!.text,
                                  ) ??
                                  0.0;
                              final price =
                                  double.tryParse(
                                    controller['unitPrice']!.text,
                                  ) ??
                                  0.0;
                              return sum + (qty * price);
                            }) +
                            (double.tryParse(_taxAmountController.text) ?? 0.0),
                      )
                    : Helpers.formatCurrency(invoice.totalAmount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _cancelPreview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E3193), Color(0xFF0533F4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton(
                  onPressed: _saveInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataRow(
    String label,
    String value, {
    TextEditingController? controller,
    bool isEditable = true,
    bool isCurrency = false,
    int maxLines = 1,
  }) {
    final shouldEdit = controller != null && _isEditingInvoice && isEditable;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: shouldEdit
                ? TextField(
                    controller: controller,
                    maxLines: maxLines,
                    keyboardType: isCurrency
                        ? TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    onChanged: isCurrency
                        ? (val) {
                            setState(() {}); // Trigger rebuild to update total
                          }
                        : null,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey[400]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: !isEditable ? Colors.grey[600] : Colors.black,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Animated loading message bubble
class _LoadingMessageBubble extends StatefulWidget {
  const _LoadingMessageBubble();

  @override
  State<_LoadingMessageBubble> createState() => _LoadingMessageBubbleState();
}

class _LoadingMessageBubbleState extends State<_LoadingMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _dotCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _dotCount = IntTween(
      begin: 0,
      end: 3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotCount,
      builder: (context, child) {
        return Text(
          'Crafting Invoice${"." * (_dotCount.value + 1)}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }
}
