import 'dart:convert';
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
          maxOutputTokens: 2000,
          responseMimeType: 'application/json',
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

Extract all mentioned fields. Use null for fields not mentioned.

Return a JSON object with these keys:
- name (required)
- tin
- registration_number
- identification_number  
- email
- phone
- sst_number
- contact_person (look for "PIC", "contact person", or person name after company)
- address_line1
- address_line2
- address_line3
- city
- state
- postal_code
- country (default "MY")
- notes

Example for "Add customer ABC Trading, TIN C1234567890123, email abc@example.com, PIC John Lee":
{"name":"ABC Trading","tin":"C1234567890123","registration_number":null,"identification_number":null,"email":"abc@example.com","phone":null,"sst_number":null,"contact_person":"John Lee","address_line1":null,"address_line2":null,"address_line3":null,"city":null,"state":null,"postal_code":null,"country":"MY","notes":null}''';
      
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final responseText = response.text?.trim() ?? '';
      
      print('DEBUG CustomerCreation: AI response length: ${responseText.length}');
      print('DEBUG CustomerCreation: AI response: $responseText');
      
      // Extract JSON from response (handle markdown code blocks or pure JSON)
      String jsonText = responseText;
      
      // Check if response is wrapped in markdown code blocks
      if (jsonText.contains('```json')) {
        final parts = jsonText.split('```json');
        if (parts.length > 1) {
          final afterStart = parts[1];
          final beforeEnd = afterStart.split('```');
          if (beforeEnd.isNotEmpty) {
            jsonText = beforeEnd[0].trim();
          }
        }
      } else if (jsonText.contains('```')) {
        final parts = jsonText.split('```');
        if (parts.length > 1) {
          jsonText = parts[1].trim();
        }
      }
      
      // Clean up any remaining whitespace or newlines
      jsonText = jsonText.trim();
      
      print('DEBUG CustomerCreation: Extracted JSON (length: ${jsonText.length}): $jsonText');
      
      // Validate JSON structure before parsing
      if (!jsonText.startsWith('{') || !jsonText.endsWith('}')) {
        print('DEBUG CustomerCreation: Invalid JSON structure - missing braces');
        return _ParsedCustomerRequest(
          success: false,
          errorMessage: 'AI response is not valid JSON (missing braces)',
        );
      }
      
      // Parse JSON
      final Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(jsonText) as Map<String, dynamic>;
        print('DEBUG CustomerCreation: Successfully parsed JSON with ${parsed.length} fields');
      } catch (e) {
        print('DEBUG CustomerCreation: JSON parse error: $e');
        print('DEBUG CustomerCreation: Failed JSON text: $jsonText');
        return _ParsedCustomerRequest(
          success: false,
          errorMessage: 'Could not parse AI response as JSON: $e',
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
