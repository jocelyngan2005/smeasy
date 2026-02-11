import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/gemini_service.dart';
import '../../services/invoice_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../invoices/invoice_detail_screen.dart';

class VoiceInvoiceScreen extends StatefulWidget {
  const VoiceInvoiceScreen({super.key});

  @override
  State<VoiceInvoiceScreen> createState() => _VoiceInvoiceScreenState();
}

class _VoiceInvoiceScreenState extends State<VoiceInvoiceScreen> {
  final _geminiService = GeminiService();
  final _invoiceService = InvoiceService();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isProcessing = false;
  String _transcription = '';
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

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
      Helpers.showErrorSnackbar(
        context,
        'Voice recognition not available',
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _generateInvoice() async {
    if (_textController.text.trim().isEmpty) {
      Helpers.showErrorSnackbar(
        context,
        'Please enter or speak invoice details',
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Use Gemini AI to generate invoice from text
      final invoice = await _geminiService.generateInvoiceFromVoice(
        _textController.text,
      );

      // Save draft invoice
      await _invoiceService.createInvoice(invoice);

      if (mounted) {
        Helpers.showSuccessSnackbar(
          context,
          'Invoice draft created successfully!',
        );
        
        // Navigate to invoice detail for editing
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice-to-Invoice'),
      ),
      body: SingleChildScrollView(
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
                onPressed: _isProcessing
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
                    Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      size: 48,
                    ),
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
              onPressed: _isProcessing || _textController.text.isEmpty
                  ? null
                  : _generateInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _isProcessing
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
                _isProcessing ? 'Generating...' : 'Generate Invoice with AI',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
