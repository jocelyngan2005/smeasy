class KnowledgeAssistantService {
  // Mock Vertex AI Search - Get answer to compliance question
  Future<Map<String, dynamic>> askQuestion(String question) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate AI processing

    // Mock knowledge base responses
    final mockResponses = {
      'rm10000': '''
**RM10,000 Transaction Rule**

According to LHDN guidelines:
- Transactions of RM10,000 and above require mandatory e-invoicing through MyInvois
- This applies to all B2B transactions during the initial implementation phase
- Consolidated invoicing is allowed during the 2026-2027 relaxation period
- Penalties may apply for non-compliance

**Source:** LHDN MyInvois Guidelines 2026, Section 3.2
''',
      'relaxation': '''
**Relaxation Period (2026-2027)**

During this period:
- SMEs can consolidate multiple small invoices (below RM10k) monthly
- Real-time submission required only for transactions RM10k and above
- Grace period for system adaptation and compliance
- Full compliance mandatory from 2028 onwards

**Source:** LHDN Circular No. 5/2025
''',
      'tin': '''
**Tax Identification Number (TIN) Requirements**

- All invoices must include valid TIN for both seller and buyer
- Format: 12-digit number starting with 'C' for companies
- Verification available through MyTax portal
- Missing or invalid TIN will result in invoice rejection

**Source:** LHDN MyInvois Technical Specifications v2.0
''',
    };

    // Simple keyword matching (in real app, use Vertex AI Search)
    String response = '';
    final lowerQuestion = question.toLowerCase();

    if (lowerQuestion.contains('rm10') || lowerQuestion.contains('10000') || lowerQuestion.contains('threshold')) {
      response = mockResponses['rm10000']!;
    } else if (lowerQuestion.contains('relaxation') || lowerQuestion.contains('period') || lowerQuestion.contains('consolidat')) {
      response = mockResponses['relaxation']!;
    } else if (lowerQuestion.contains('tin') || lowerQuestion.contains('tax identification')) {
      response = mockResponses['tin']!;
    } else {
      response = '''
I can help you with questions about:
- MyInvois e-invoicing requirements
- RM10,000 transaction rules
- Relaxation period guidelines
- TIN requirements
- Compliance deadlines
- Submission procedures

Please ask a specific question about Malaysian e-invoicing compliance.
''';
    }

    return {
      'question': question,
      'answer': response,
      'sources': [
        'LHDN MyInvois Guidelines 2026',
        'LHDN Technical Specifications',
        'Malaysian Tax Act (Amendments)',
      ],
      'confidence': 0.92,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Get FAQ
  Future<List<Map<String, String>>> getFAQ() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      {
        'question': 'What is the RM10,000 rule?',
        'answer': 'All transactions of RM10,000 and above must be submitted to MyInvois in real-time.',
      },
      {
        'question': 'What is the relaxation period?',
        'answer': '2026-2027 allows SMEs to consolidate smaller invoices and adapt to the system gradually.',
      },
      {
        'question': 'How do I get a TIN?',
        'answer': 'Register with LHDN through the MyTax portal to obtain your Tax Identification Number.',
      },
      {
        'question': 'What happens if I miss a deadline?',
        'answer': 'Late submissions may incur penalties. Use the compliance dashboard to track deadlines.',
      },
      {
        'question': 'Can I edit a submitted invoice?',
        'answer': 'Once submitted to MyInvois, you must submit a credit note or debit note for corrections.',
      },
    ];
  }

  // Get compliance guidelines
  Future<List<String>> getGuidelines() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      'All B2B transactions RM10k+ require MyInvois submission',
      'Valid TIN required for both seller and buyer',
      'Invoices must be submitted within 72 hours of transaction',
      'Keep digital records for 7 years',
      'Use QR codes for verification',
      'Regular system updates required for compliance',
    ];
  }
}
