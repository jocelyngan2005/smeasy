# Backend Invoice Model Update Plan
## Adding e-Invoice Compliance Fields

### Phase 1: Update PartyInfo Model ✅

**File:** `lib/backend/invoice/models/invoice_model.dart`

Add to `PartyInfo` class:
```dart
@JsonSerializable()
class PartyInfo {
  final String name;
  final String? tin; // Tax Identification Number
  final String? registrationNumber; // Company registration OR MyKad/Passport
  
  // NEW: e-Invoice Compliance Fields (LHDN 4.6)
  final String? identificationNumber; // MyKad/MyTentera/Passport/MyPR/MyKAS
  final String? contactNumber; // Phone number (required for buyers)
  final String? sstNumber; // SST Registration Number (use "NA" if not registered)
  
  final String? email;
  final String? phone; // Keep for backward compatibility
  final Address address;
  final String? contactPerson;

  PartyInfo({
    required this.name,
    this.tin,
    this.registrationNumber,
    this.identificationNumber,
    this.contactNumber,
    this.sstNumber,
    this.email,
    this.phone,
    required this.address,
    this.contactPerson,
  });

  // Validation helpers
  bool get hasValidBuyerInfo {
    return name.isNotEmpty &&
        (tin?.isNotEmpty ?? false) &&
        (identificationNumber?.isNotEmpty ?? identificationNumber == '000000000000') &&
        address.line1.isNotEmpty &&
        (contactNumber?.isNotEmpty ?? false) &&
        (sstNumber?.isNotEmpty ?? false);
  }

  // Helper for default values
  static String getDefaultIdentificationNumber() => '000000000000';
  static String getDefaultTinForMyKad() => 'EI00000000010';
  static String getDefaultSstNumber() => 'NA';
}
```

### Phase 2: Add Shipping Recipient Support ✅

Add to `Invoice` class:
```dart
@JsonSerializable(explicitToJson: true)
class Invoice {
  // ...existing fields...
  
  // NEW: Shipping Recipient (optional, for Annexure to e-Invoice)
  final PartyInfo? shippingRecipient;
  
  Invoice({
    // ...existing params...
    this.shippingRecipient,
  });

  // Validation
  bool get hasValidShippingRecipient {
    if (shippingRecipient == null) return true;
    return shippingRecipient!.name.isNotEmpty &&
        (shippingRecipient!.tin?.isNotEmpty ?? false) &&
        (shippingRecipient!.identificationNumber?.isNotEmpty ?? false) &&
        shippingRecipient!.address.line1.isNotEmpty;
  }
}
```

### Phase 3: Update InvoiceDraft Model ✅

**File:** `lib/backend/invoice/models/invoice_draft.dart`

Add same fields to `PartyInfoDraft`:
```dart
@JsonSerializable()
class PartyInfoDraft {
  final String? name;
  final String? tin;
  final String? registrationNumber;
  final String? identificationNumber; // NEW
  final String? contactNumber; // NEW
  final String? sstNumber; // NEW
  final String? email;
  final String? phone;
  final AddressDraft? address;
  final String? contactPerson;
}
```

### Phase 4: Update Invoice Adapter ✅

**File:** `lib/backend/invoice/models/invoice_adapter.dart`

Add parameters to `InvoiceBuilder.fromSimpleData()`:
```dart
static Invoice fromSimpleData({
  // ...existing params...
  
  // NEW: Buyer e-Invoice fields
  String? buyerIdentificationNumber,
  String? buyerContactNumber,
  String? buyerSstNumber,
  
  // NEW: Seller e-Invoice fields  
  String? sellerIdentificationNumber,
  String? sellerContactNumber,
  String? sellerSstNumber,
  
  // NEW: Shipping recipient (optional)
  String? shippingRecipientName,
  String? shippingRecipientTin,
  String? shippingRecipientIdentificationNumber,
  String? shippingRecipientContactNumber,
  String? shippingRecipientAddress1,
}) {
  // Create buyer with e-Invoice fields
  final buyer = PartyInfo(
    name: buyerName,
    tin: buyerTin,
    registrationNumber: buyerId,
    identificationNumber: buyerIdentificationNumber ?? PartyInfo.getDefaultIdentificationNumber(),
    contactNumber: buyerContactNumber,
    sstNumber: buyerSstNumber ?? PartyInfo.getDefaultSstNumber(),
    // ...
  );
  
  // Similar for vendor and shipping recipient
}
```

Add compatibility extensions:
```dart
extension InvoiceCompat on Invoice {
  // Existing compatibility getters
  String get buyerTin => buyer.tin ?? '';
  
  // NEW: e-Invoice compliance getters
  String get buyerRegistrationNumber => buyer.identificationNumber ?? '000000000000';
  String get buyerContactNumber => buyer.contactNumber ?? '';
  String get buyerSstNumber => buyer.sstNumber ?? 'NA';
  
  String? get shippingRecipientName => shippingRecipient?.name;
  String? get shippingRecipientTin => shippingRecipient?.tin;
  // ...etc
}
```

### Phase 5: Update Gemini Services ✅

**Files:** 
- `lib/backend/invoice/services/gemini_invoice_service.dart`
- `lib/backend/invoice/services/gemini_vision_service.dart`

Update AI prompts to extract new fields:
```dart
String _buildInvoiceGenerationPrompt(...) {
  return '''
  ...
  MALAYSIAN e-INVOICE COMPLIANCE:
  - Extract buyer's identification number (MyKad/Passport)
  - Extract buyer's contact number (required)
  - Extract buyer's SST number (use "NA" if not mentioned)
  - For individuals: MyKad format or "EI00000000010" if only MyKad provided
  - For companies: TIN format C 1234567890
  
  Return JSON with:
  {
    "buyer": {
      "name": "string",
      "tin": "string or null",
      "identificationNumber": "string (MyKad/Passport) or 000000000000",
      "contactNumber": "string (required)",
      "sstNumber": "string or NA",
      ...
    }
  }
  ''';
}
```

### Phase 6: Run Code Generation 🔧

After updating models, regenerate JSON serialization:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Phase 7: Update Frontend Services 🔄

**Remove:**
- `lib/services/gemini_service.dart` (mock)
- `lib/models/invoice_model.old.dart` (already renamed)
- `lib/models/invoice_model.new.dart` (reference only)

**Update:**
- All frontend screens to use `InvoiceGenerationOrchestrator`
- Add API key configuration using `.env` file
- Update adapter usage with new e-Invoice fields

### Phase 8: Testing ✅

Test scenarios:
1. ✅ Voice input extracts MyKad/Passport numbers
2. ✅ Receipt scanning captures contact numbers
3. ✅ Manual entry validates SST numbers
4. ✅ Submission validates all required e-Invoice fields
5. ✅ Shipping recipient info (optional) works correctly

## File Structure After Update

```
lib/
├── backend/                          # ✅ KEEP AS MODULE
│   └── invoice/                      # Invoice generation module
│       ├── models/
│       │   ├── invoice_model.dart    # ⬆️ UPDATED with e-Invoice fields
│       │   ├── invoice_draft.dart    # ⬆️ UPDATED with e-Invoice fields
│       │   └── invoice_adapter.dart  # ⬆️ UPDATED with new params
│       ├── services/
│       │   ├── gemini_invoice_service.dart    # ⬆️ UPDATED prompts
│       │   ├── gemini_vision_service.dart     # ⬆️ UPDATED prompts
│       │   ├── firestore_invoice_service.dart # ⬆️ UPDATED validation
│       │   └── invoice_orchestrator.dart      # ⬆️ UPDATED validation
│       ├── config/
│       │   └── invoice_config.dart
│       └── [docs...]
│
├── models/                           # General app models
│   ├── user_model.dart
│   ├── analytics_model.dart
│   ├── compliance_model.dart
│   └── support_location_model.dart
│
├── services/                         # General app services
│   ├── auth_service.dart
│   ├── analytics_service.dart
│   ├── invoice_service.dart          # ⬆️ UPDATE to use orchestrator
│   └── knowledge_assistant_service.dart
│
└── screens/                          # UI
    ├── create/
    │   └── create_invoice_screen.dart  # ⬆️ USE orchestrator
    ├── receipt_scanner/
    │   └── receipt_scanner_screen.dart # ⬆️ USE orchestrator
    └── invoices/
        ├── invoice_list_screen.dart
        └── invoice_detail_screen.dart
```

## Benefits of This Approach ✨

1. **Maintains Modularity** - Invoice logic stays self-contained
2. **Adds Compliance** - All LHDN e-Invoice 4.6 requirements met
3. **Backward Compatible** - Adapter provides old-style access
4. **Clean Separation** - Invoice module vs app-level code
5. **Future-Proof** - Can extract as package later
6. **Better Architecture** - Structured data > flat data

## Migration Timeline

- **Week 1:** Update models and run code generation
- **Week 2:** Update services and AI prompts
- **Week 3:** Update frontend to use orchestrator
- **Week 4:** Testing and validation

## References

- LHDN e-Invoice Specific Guideline Version 4.6
- Section 3.5: Individual Buyer Details
- Tables 3.1, 3.2, 3.3: TIN and Identification Requirements
