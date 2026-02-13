# Malaysian e-Invoice Compliance Implementation

## Overview
The InvoiceModel has been updated to comply with Malaysian e-Invoice requirements as specified in the IRBM e-Invoice Specific Guideline (Version 4.6).

## Updated Fields

### Buyer Information (Required)
The following fields have been added to support e-Invoice compliance:

1. **buyerRegistrationNumber** (String, required)
   - For Malaysian individuals: MyKad/MyTentera identification number
   - For non-Malaysian individuals: Passport/MyPR/MyKAS identification number
   - Default: "000000000000" (when only TIN is provided)

2. **buyerContactNumber** (String, required)
   - Telephone number of individual buyer
   - Required field for all e-Invoices

3. **buyerSstNumber** (String, required)
   - SST registration number of buyer
   - Use "NA" if buyer is not registered for SST

### Shipping Recipient Information (Optional)
The following optional fields support Annexure to e-Invoice:

1. **shippingRecipientName** (String?, optional)
   - Name of individual shipping recipient

2. **shippingRecipientTin** (String?, optional)
   - TIN of shipping recipient

3. **shippingRecipientRegistrationNumber** (String?, optional)
   - Registration/Identification/Passport number of shipping recipient

4. **shippingRecipientAddress** (String?, optional)
   - Address of shipping recipient

## Data Validation Rules

### For Malaysian Individuals
Three options are supported for TIN and identification:

**Option 1:** TIN only
- buyerTin: Actual TIN assigned by IRBM
- buyerRegistrationNumber: "000000000000"

**Option 2:** MyKad/MyTentera identification number only
- buyerTin: "EI00000000010"
- buyerRegistrationNumber: MyKad/MyTentera number

**Option 3:** Both TIN and MyKad/MyTentera
- buyerTin: Actual TIN assigned by IRBM
- buyerRegistrationNumber: MyKad/MyTentera number

### For Non-Malaysian Individuals
Two options are supported:

**Option 1:** TIN only
- buyerTin: Actual TIN assigned by IRBM (or general TIN from Appendix 1)
- buyerRegistrationNumber: "000000000000"

**Option 2:** Both TIN and passport/MyPR/MyKAS
- buyerTin: Actual TIN or general TIN
- buyerRegistrationNumber: Passport/MyPR/MyKAS number

## Helper Methods

### Validation Helpers
- **hasValidBuyerInfo**: Validates that all required buyer fields are complete
- **hasValidShippingRecipient**: Validates shipping recipient information when provided

### Static Helpers
- **getDefaultTinForMyKad()**: Returns "EI00000000010" (for Malaysian individuals using only MyKad)
- **getDefaultRegistrationNumber()**: Returns "000000000000" (when only TIN is provided)

## Updated Files

1. **lib/models/invoice_model.dart**
   - Added new required and optional fields
   - Added validation methods
   - Added helper methods for e-Invoice defaults

2. **lib/services/invoice_service.dart**
   - Updated all InvoiceModel instantiations
   - Updated mock data with compliant examples

3. **lib/services/gemini_service.dart**
   - Updated invoice generation from voice
   - Enhanced validation rules for e-Invoice compliance

4. **lib/screens/create/create_invoice_screen.dart**
   - Updated to include new fields in invoice creation

## Migration Guide

### For Existing Invoices
When loading existing invoices from JSON:
- `buyerRegistrationNumber` defaults to "000000000000"
- `buyerContactNumber` defaults to empty string (should be updated)
- `buyerSstNumber` defaults to "NA"
- Shipping recipient fields default to null (optional)

### For New Invoices
Ensure all required fields are populated:
```dart
InvoiceModel(
  // ... other fields
  buyerTin: 'C12345678900', // or 'EI00000000010' for MyKad-only
  buyerRegistrationNumber: '201601012345', // or '000000000000' for TIN-only
  buyerContactNumber: '+60123456789',
  buyerSstNumber: 'A01-1234-56789012', // or 'NA'
  // Shipping recipient fields (optional)
  shippingRecipientName: null,
  shippingRecipientTin: null,
  shippingRecipientRegistrationNumber: null,
  shippingRecipientAddress: null,
);
```

## Compliance Checklist

Before submitting an invoice to MyInvois, ensure:
- [ ] Buyer's name is provided (full name as per MyKad/Passport)
- [ ] Buyer's TIN is provided (or general TIN for non-Malaysian without TIN)
- [ ] Buyer's registration/identification/passport number is provided (or "000000000000")
- [ ] Buyer's address is provided (residential address for individuals)
- [ ] Buyer's contact number is provided
- [ ] Buyer's SST number is provided (or "NA")
- [ ] If shipping recipient info is provided, all related fields are complete
- [ ] Invoice meets `hasValidBuyerInfo` validation
- [ ] Invoice meets `hasValidShippingRecipient` validation (if applicable)

## References
- IRBM e-Invoice Specific Guideline (Version 4.6)
- Section 3.5: Individual Buyer and Shipping Recipient Details
- Table 3.1: Individual Buyer's details
- Table 3.2: Individual Shipping Recipient's details
- Table 3.3: Details of TIN and identification number requirements
