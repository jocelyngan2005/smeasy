import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/customer_model.dart';

/// Service to parse natural language customer creation requests using Gemini AI
class CustomerCreationService {
  /// Parse natural language and create a customer profile
  Future<CustomerCreationResult> createCustomerFromRequest({
    required String request,
    required String userId,
  }) async {
    try {
      print('DEBUG CustomerCreation: Parsing request: "$request"');
      
      // Parse the request using Gemini AI
      final parsed = await _parseCustomerRequest(request);
      
      if (!parsed.success) {
        return CustomerCreationResult(
          success: false,
          errorMessage: parsed.errorMessage ?? 'Could not parse customer details',
        );
      }
      
      // Validate required fields
      if (parsed.name == null || parsed.name!.isEmpty) {
        return CustomerCreationResult(
          success: false,
          errorMessage: 'Customer name is required',
        );
      }
      
      // Create customer object
      final customerId = DateTime.now().millisecondsSinceEpoch.toString();
      final addressId = '${customerId}_addr_1';
      
      final customer = Customer(
        id: customerId,
        name: parsed.name!,
        tin: parsed.tin,
        registrationNumber: parsed.registrationNumber,
        identificationNumber: parsed.identificationNumber,
        contactNumber: parsed.phone,
        sstNumber: parsed.sstNumber,
        email: parsed.email,
        contactPerson: parsed.contactPerson,
        addresses: [
          CustomerAddress(
            id: addressId,
            line1: parsed.addressLine1 ?? 'Not provided',
            line2: parsed.addressLine2,
            line3: parsed.addressLine3,
            city: parsed.city ?? 'Not provided',
            state: parsed.state ?? 'Not provided',
            postalCode: parsed.postalCode ?? '00000',
            country: parsed.country ?? 'MY',
            isPrimary: true,
            label: 'Primary',
          ),
        ],
        notes: parsed.notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
      );
      
      // Build summary of what was extracted
      final summary = _buildSummary(parsed);
      
      print('DEBUG CustomerCreation: Successfully created customer profile');
      
      return CustomerCreationResult(
        success: true,
        customer: customer,
        summary: summary,
        missingFields: _identifyMissingFields(parsed),
      );
    } catch (e) {
      print('DEBUG CustomerCreation: Error - $e');
      return CustomerCreationResult(
        success: false,
        errorMessage: 'Error creating customer: ${e.toString()}',
      );
    }
  }
  
  /// Parse customer creation request using Gemini AI
  Future<_ParsedCustomerRequest> _parseCustomerRequest(String request) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY not found in .env file');
      }
      
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          maxOutputTokens: 500,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        ],
      );
      
      final prompt = '''
Parse this customer creation request and extract customer details.

Request: "$request"

Extract the following fields (use "null" if not mentioned):
- name: Company or person name (REQUIRED)
- tin: Tax Identification Number (format: C followed by 13 digits, e.g., C1234567890123)
- registration_number: Company registration number
- identification_number: MyKad/Passport/ID number
- email: Email address
- phone: Contact phone number
- sst_number: SST registration number
- contact_person: Name of contact person
- address_line1: Street address line 1
- address_line2: Street address line 2
- address_line3: Street address line 3
- city: City name
- state: State/Province
- postal_code: Postal/ZIP code
- country: Country (default "MY" for Malaysia)
- notes: Any additional notes or comments

Respond with ONLY a JSON object with these exact keys (use null for missing values):
{
  "name": "string or null",
  "tin": "string or null",
  "registration_number": "string or null",
  "identification_number": "string or null",
  "email": "string or null",
  "phone": "string or null",
  "sst_number": "string or null",
  "contact_person": "string or null",
  "address_line1": "string or null",
  "address_line2": "string or null",
  "address_line3": "string or null",
  "city": "string or null",
  "state": "string or null",
  "postal_code": "string or null",
  "country": "string or null",
  "notes": "string or null"
}

Examples:
Request: "Add customer ABC Trading Sdn Bhd, TIN C1234567890123, email abc@example.com"
Response: {"name": "ABC Trading Sdn Bhd", "tin": "C1234567890123", "email": "abc@example.com", "registration_number": null, "identification_number": null, "phone": null, "sst_number": null, "contact_person": null, "address_line1": null, "address_line2": null, "address_line3": null, "city": null, "state": null, "postal_code": null, "country": "MY", "notes": null}

Request: "Create customer John Doe, phone 0123456789, address 123 Main St, Kuala Lumpur"
Response: {"name": "John Doe", "tin": null, "registration_number": null, "identification_number": null, "email": null, "phone": "0123456789", "sst_number": null, "contact_person": null, "address_line1": "123 Main St", "address_line2": null, "address_line3": null, "city": "Kuala Lumpur", "state": null, "postal_code": null, "country": "MY", "notes": null}''';
      
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final responseText = response.text?.trim() ?? '';
      
      print('DEBUG CustomerCreation: AI response: $responseText');
      
      // Extract JSON from response (handle markdown code blocks)
      String jsonText = responseText;
      if (jsonText.contains('```json')) {
        jsonText = jsonText.split('```json')[1].split('```')[0].trim();
      } else if (jsonText.contains('```')) {
        jsonText = jsonText.split('```')[1].split('```')[0].trim();
      }
      
      // Parse JSON
      final Map<String, dynamic> parsed;
      try {
        parsed = Map<String, dynamic>.from(
          // ignore: avoid_dynamic_calls
          (response.text as dynamic).contains('```')
              ? _parseJsonFromMarkdown(responseText)
              : _parseJson(jsonText),
        );
      } catch (e) {
        print('DEBUG CustomerCreation: JSON parse error: $e');
        return _ParsedCustomerRequest(
          success: false,
          errorMessage: 'Could not parse AI response as JSON',
        );
      }
      
      return _ParsedCustomerRequest(
        success: true,
        name: _getStringValue(parsed, 'name'),
        tin: _getStringValue(parsed, 'tin'),
        registrationNumber: _getStringValue(parsed, 'registration_number'),
        identificationNumber: _getStringValue(parsed, 'identification_number'),
        email: _getStringValue(parsed, 'email'),
        phone: _getStringValue(parsed, 'phone'),
        sstNumber: _getStringValue(parsed, 'sst_number'),
        contactPerson: _getStringValue(parsed, 'contact_person'),
        addressLine1: _getStringValue(parsed, 'address_line1'),
        addressLine2: _getStringValue(parsed, 'address_line2'),
        addressLine3: _getStringValue(parsed, 'address_line3'),
        city: _getStringValue(parsed, 'city'),
        state: _getStringValue(parsed, 'state'),
        postalCode: _getStringValue(parsed, 'postal_code'),
        country: _getStringValue(parsed, 'country') ?? 'MY',
        notes: _getStringValue(parsed, 'notes'),
      );
    } catch (e) {
      print('DEBUG CustomerCreation: Parse error - $e');
      return _ParsedCustomerRequest(
        success: false,
        errorMessage: 'Error parsing request: ${e.toString()}',
      );
    }
  }
  
  Map<String, dynamic> _parseJson(String text) {
    // Try different JSON parsing approaches
    final jsonRegex = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}');
    final match = jsonRegex.firstMatch(text);
    if (match != null) {
      final jsonStr = match.group(0)!;
      return Map<String, dynamic>.from(
        // ignore: avoid_dynamic_calls
        (Uri.dataFromString(jsonStr).data as dynamic),
      );
    }
    throw Exception('No valid JSON found in response');
  }
  
  Map<String, dynamic> _parseJsonFromMarkdown(String text) {
    if (text.contains('```json')) {
      final jsonText = text.split('```json')[1].split('```')[0].trim();
      return _parseJson(jsonText);
    } else if (text.contains('```')) {
      final jsonText = text.split('```')[1].split('```')[0].trim();
      return _parseJson(jsonText);
    }
    return _parseJson(text);
  }
  
  String? _getStringValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null || value == 'null' || value.toString().isEmpty) {
      return null;
    }
    return value.toString();
  }
  
  String _buildSummary(_ParsedCustomerRequest parsed) {
    final parts = <String>[];
    
    parts.add('**Name:** ${parsed.name}');
    
    if (parsed.tin != null) parts.add('**TIN:** ${parsed.tin}');
    if (parsed.registrationNumber != null) {
      parts.add('**Registration No:** ${parsed.registrationNumber}');
    }
    if (parsed.identificationNumber != null) {
      parts.add('**ID Number:** ${parsed.identificationNumber}');
    }
    if (parsed.email != null) parts.add('**Email:** ${parsed.email}');
    if (parsed.phone != null) parts.add('**Phone:** ${parsed.phone}');
    if (parsed.sstNumber != null) parts.add('**SST No:** ${parsed.sstNumber}');
    if (parsed.contactPerson != null) {
      parts.add('**Contact Person:** ${parsed.contactPerson}');
    }
    
    // Address
    final addressParts = <String>[];
    if (parsed.addressLine1 != null) addressParts.add(parsed.addressLine1!);
    if (parsed.addressLine2 != null) addressParts.add(parsed.addressLine2!);
    if (parsed.addressLine3 != null) addressParts.add(parsed.addressLine3!);
    if (parsed.city != null) addressParts.add(parsed.city!);
    if (parsed.state != null) addressParts.add(parsed.state!);
    if (parsed.postalCode != null) addressParts.add(parsed.postalCode!);
    
    if (addressParts.isNotEmpty) {
      parts.add('**Address:** ${addressParts.join(", ")}');
    }
    
    if (parsed.notes != null) parts.add('**Notes:** ${parsed.notes}');
    
    return parts.join('\n');
  }
  
  List<String> _identifyMissingFields(_ParsedCustomerRequest parsed) {
    final missing = <String>[];
    
    if (parsed.tin == null && parsed.identificationNumber == null) {
      missing.add('TIN or Identification Number (at least one is recommended)');
    }
    if (parsed.email == null) missing.add('Email');
    if (parsed.phone == null) missing.add('Phone');
    if (parsed.addressLine1 == null) missing.add('Street Address');
    if (parsed.city == null) missing.add('City');
    if (parsed.state == null) missing.add('State');
    if (parsed.postalCode == null) missing.add('Postal Code');
    
    return missing;
  }
}

/// Result of customer creation operation
class CustomerCreationResult {
  final bool success;
  final Customer? customer;
  final String? summary;
  final List<String>? missingFields;
  final String? errorMessage;
  
  CustomerCreationResult({
    required this.success,
    this.customer,
    this.summary,
    this.missingFields,
    this.errorMessage,
  });
}

/// Internal parsed customer request
class _ParsedCustomerRequest {
  final bool success;
  final String? errorMessage;
  final String? name;
  final String? tin;
  final String? registrationNumber;
  final String? identificationNumber;
  final String? email;
  final String? phone;
  final String? sstNumber;
  final String? contactPerson;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressLine3;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? notes;
  
  _ParsedCustomerRequest({
    required this.success,
    this.errorMessage,
    this.name,
    this.tin,
    this.registrationNumber,
    this.identificationNumber,
    this.email,
    this.phone,
    this.sstNumber,
    this.contactPerson,
    this.addressLine1,
    this.addressLine2,
    this.addressLine3,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.notes,
  });
}
