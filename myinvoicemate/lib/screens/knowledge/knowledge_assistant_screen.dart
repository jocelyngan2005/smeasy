import 'package:flutter/material.dart';
import '../../backend/knowledge_assistant/knowledge_assistant_service.dart';
import '../../utils/constants.dart';

class KnowledgeAssistantScreen extends StatefulWidget {
  const KnowledgeAssistantScreen({super.key});

  @override
  State<KnowledgeAssistantScreen> createState() => _KnowledgeAssistantScreenState();
}

class _KnowledgeAssistantScreenState extends State<KnowledgeAssistantScreen> {
  final _knowledgeService = KnowledgeAssistantService();
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<Map<String, String>> _chatHistory = [];
  List<Map<String, String>> _faqs = [];
  bool _isLoading = false;
  bool _isLoadingFAQs = true;

  @override
  void initState() {
    super.initState();
    _loadFAQs();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFAQs() async {
    setState(() => _isLoadingFAQs = true);
    try {
      final faqs = await _knowledgeService.getFAQ();
      setState(() {
        _faqs = faqs;
        _isLoadingFAQs = false;
      });
    } catch (e) {
      setState(() => _isLoadingFAQs = false);
    }
  }

  Future<void> _askQuestion(String question) async {
    if (question.trim().isEmpty) return;

    setState(() {
      _chatHistory.add({'role': 'user', 'message': question});
      _isLoading = true;
    });

    _questionController.clear();
    _scrollToBottom();

    try {
      final response = await _knowledgeService.askQuestion(question);
      
      setState(() {
        _chatHistory.add({'role': 'assistant', 'message': response['answer']});
        _isLoading = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _chatHistory.add({
          'role': 'assistant',
          'message': 'Sorry, I encountered an error. Please try again.',
        });
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Assistant'),
                  content: const Text(
                    'Ask questions about Malaysian e-invoicing compliance, '
                    'LHDN MyInvois requirements, and tax regulations.\n\n'
                    'Powered by Vertex AI Search with official LHDN documentation.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat/FAQ Tabs
          if (_chatHistory.isEmpty)
            Expanded(
              child: _isLoadingFAQs
                  ? const Center(child: CircularProgressIndicator())
                  : _buildFAQView(),
            )
          else
            Expanded(child: _buildChatView()),

          // Input Area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildFAQView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Card(
          color: AppColors.primary.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(
                  Icons.support_agent,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'SME Compliance Knowledge Assistant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Get answers about LHDN MyInvois, compliance rules, and e-invoicing regulations',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // FAQ Section
        const Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        ..._faqs.map((faq) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              faq['question']!,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(faq['answer']!),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _askQuestion(faq['question']!),
                      icon: const Icon(Icons.chat),
                      label: const Text('Ask follow-up question'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildChatView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _chatHistory.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _chatHistory.length && _isLoading) {
          return _buildTypingIndicator();
        }

        final chat = _chatHistory[index];
        final isUser = chat['role'] == 'user';

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isUser ? AppColors.primary : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              chat['message']!,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTypingDot(delay: 0),
            const SizedBox(width: 4),
            _buildTypingDot(delay: 150),
            const SizedBox(width: 4),
            _buildTypingDot(delay: 300),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingDot({required int delay}) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, double value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                hintText: 'Ask about compliance...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _askQuestion,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoading
                ? null
                : () => _askQuestion(_questionController.text),
            icon: const Icon(Icons.send),
            color: AppColors.primary,
            iconSize: 28,
          ),
        ],
      ),
    );
  }
}
