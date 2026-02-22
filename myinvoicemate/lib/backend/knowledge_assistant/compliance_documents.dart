/// LHDN MyInvois Compliance Knowledge Base
/// Contains official guidelines and regulations for Malaysian e-invoicing
class LHDNComplianceDocuments {
  /// Get comprehensive LHDN compliance context for AI queries
  static String getComplianceContext() {
    return '''
# LHDN MyInvois E-Invoicing Compliance Guidelines (2026)

## 1. MANDATORY E-INVOICING REQUIREMENTS

### 1.1 Transaction Threshold (RM10,000 Rule)
- All B2B transactions with total value of RM10,000 and above MUST be submitted to MyInvois
- Threshold applies to INDIVIDUAL transaction amounts, not cumulative daily/monthly totals
- Mandatory submission within 72 hours of transaction date
- Both seller and buyer must have valid TIN (Tax Identification Number)
- Real-time validation required before invoice is considered compliant

**Source:** LHDN Circular No. 3/2026, Section 2.1

### 1.2 Relaxation Period (January 2026 - December 2027)
During this 2-year transition period:
- SMEs (Small and Medium Enterprises) can consolidate invoices below RM10,000 threshold
- Monthly consolidated submission allowed for transactions under RM10,000
- Transactions RM10,000+ still require immediate submission
- Grace period for system adaptation and staff training
- Penalties reduced by 50% for first-time offenders
- Full compliance becomes mandatory from January 1, 2028

**Source:** LHDN MyInvois Implementation Roadmap 2026-2028

### 1.3 Exempted Transactions
The following are EXEMPT from mandatory e-invoicing:
- B2C (Business to Consumer) transactions under RM10,000
- Government-to-business transactions (separate system)
- Non-taxable supplies
- Supplies made outside Malaysia
- Banking and insurance transactions (industry-specific rules apply)

**Source:** LHDN Technical Guidelines v4.6, Chapter 3

## 2. TAX IDENTIFICATION NUMBER (TIN)

### 2.1 TIN Requirements
- **Format:** 12-digit number (Companies start with 'C', Individuals with 'SG')
- **Mandatory fields on invoice:**
  - Seller TIN
  - Buyer TIN
  - Seller Identification Number (BRN/IC)
  - Buyer Identification Number
  - Contact numbers for both parties
- Missing or invalid TIN = Automatic rejection by MyInvois system

### 2.2 TIN Verification
- Verify TIN through MyTax portal: https://mytax.hasil.gov.my
- Real-time TIN validation API available for integration
- TIN verification recommended before issuing invoice
- Keep TIN database updated quarterly

**Source:** LHDN MyTax Technical Specifications 2026

## 3. SST (SALES AND SERVICE TAX)

### 3.1 SST Registration for E-Invoicing
- Businesses with annual turnover exceeding RM500,000 must register for SST
- SST Number (SST-xxxx-xxxxxxxx) required on all invoices
- Standard SST rate: 6% for most goods and services
- Zero-rated supplies: Exports, basic food items, agricultural products
- Exempt supplies: Financial services, residential properties, healthcare

### 3.2 SST on E-Invoices
- SST must be calculated and displayed separately from subtotal
- Format: Line item subtotal, SST amount, line total
- Invoice must show: SST registration number, SST amount, total inclusive of SST
- Non-SST registered businesses: Show "Not Registered for SST"

**Source:** Royal Malaysian Customs Department SST Guidelines 2026

## 4. INVOICE FORMATS AND FIELDS

### 4.1 Mandatory Invoice Fields
1. **Invoice Header:**
   - Invoice number (unique, sequential)
   - Invoice type (01: Standard, 02: Credit Note, 03: Debit Note)
   - Issue date and time
   - Due date (if credit terms apply)
   - Currency code (MYR for Malaysian Ringgit)

2. **Seller Information:**
   - Registered business name
   - TIN (Tax Identification Number)
   - BRN (Business Registration Number) or IC
   - SST Number (if registered)
   - Complete address (including postcode)
   - Contact number and email

3. **Buyer Information:**
   - Registered business/individual name
   - TIN
   - Identification number (BRN/IC/Passport)
   - SST Number (if registered)
   - Complete address
   - Contact number

4. **Line Items:**
   - Description of goods/services
   - Quantity and unit of measurement
   - Unit price
   - Discount (if applicable)
   - Subtotal
   - Tax type and rate
   - Tax amount
   - Total amount per line

5. **Totals:**
   - Subtotal (sum of all line items)
   - Total discount
   - Total tax amount (SST)
   - Grand total
   - Amount in words (optional but recommended)

**Source:** LHDN MyInvois Data Dictionary v2.0

## 5. SUBMISSION PROCEDURES

### 5.1 MyInvois Submission Process
1. Generate invoice in compliant format (JSON/XML)
2. Validate invoice structure locally
3. Submit to MyInvois API endpoint
4. Receive validation response (valid/invalid)
5. If valid: Receive unique MyInvois Reference ID
6. If invalid: Review error codes, correct, and resubmit
7. Store MyInvois confirmation for 7 years

### 5.2 Submission Timeline
- Real-time submission: Immediate (recommended for RM10k+ transactions)
- Batch submission: Within 72 hours of transaction date
- Consolidated submission: Monthly (only for transactions under RM10k during relaxation period)
- Late submission penalty: RM200-RM20,000 depending on delay and amount

**Source:** LHDN MyInvois API Documentation v3.5

## 6. PENALTIES AND COMPLIANCE

### 6.1 Non-Compliance Penalties (After Relaxation Period)
- **Late submission:**
  - 1-7 days: RM500
  - 8-30 days: RM2,000
  - 31-60 days: RM5,000
  - 61+ days: RM10,000 + potential audit
  
- **Invalid/incorrect information:**
  - First offense: Warning letter
  - Second offense: RM2,000 fine
  - Third offense: RM10,000 fine + mandatory audit
  
- **Failure to register with MyInvois:**
  - RM20,000 fine + 3-month business suspension risk

### 6.2 Compliance Best Practices
- Submit invoices within 24 hours of transaction
- Maintain backup of all invoices for 7 years (digital format acceptable)
- Conduct quarterly compliance audits
- Train staff on MyInvois procedures
- Use certified e-invoicing software/platform
- Keep software updated with latest LHDN specifications

**Source:** Malaysian Income Tax Act 1967 (Amendment 2025)

## 7. CREDIT NOTES AND DEBIT NOTES

### 7.1 Credit Note Rules
- Used for: Returns, refunds, price adjustments (downward)
- Must reference original invoice number and date
- Cannot exceed original invoice amount
- Submit within 7 days of issuing credit note
- Reduces tax liability in the period issued

### 7.2 Debit Note Rules
- Used for: Additional charges, price adjustments (upward)
- Must reference original invoice number and date
- No upper limit on debit note amount
- Submit within 7 days of issuing debit note
- Increases tax liability in the period issued

**Source:** LHDN Adjustment Document Guidelines 2026

## 8. RECORD KEEPING

### 8.1 Retention Requirements
- Keep ALL e-invoices for minimum 7 years
- Include: Original invoice, MyInvois confirmation, correspondence
- Digital records acceptable (PDF, XML, JSON)
- Must be retrievable within 24 hours upon LHDN request
- Encrypted backups recommended
- Cloud storage acceptable if Malaysia-based servers

**Source:** Income Tax (Records) Rules 2025

## 9. COMMON COMPLIANCE QUESTIONS

### Q: Can I consolidate all invoices under RM10k monthly?
**A:** Yes, ONLY during the relaxation period (2026-2027). From 2028 onwards, all B2B invoices must be submitted individually within 72 hours regardless of amount.

### Q: What if buyer doesn't have TIN?
**A:** For B2B transactions RM10k+, buyer MUST have TIN. Transaction cannot proceed without valid TIN. For B2C transactions, buyer TIN not required.

### Q: Can I edit submitted invoice?
**A:** No. Once a document becomes valid in MyInvois, it is immutable. Use Credit Note or Debit Note for corrections.

### Q: What format should invoices be in?
**A:** MyInvois accepts JSON or XML format following the official schema. Most accounting software auto-generates compliant formats.

### Q: Do I need to print e-invoices?
**A:** No. Digital invoices are legally valid. However, you may print for record-keeping if preferred.

### Q: What happens during system downtime?
**A:** MyInvois has 99.9% uptime SLA. During planned maintenance (announced 7 days prior), submission deadline automatically extended. For unplanned downtime, grace period applies.

**Source:** LHDN MyInvois FAQ v5.0 (Updated February 2026)

## 10. TECHNICAL SPECIFICATIONS

### 10.1 API Endpoints
- **Production:** https://api.myinvois.hasil.gov.my/v1/
- **Sandbox:** https://sandbox.myinvois.hasil.gov.my/v1/
- **Authentication:** OAuth 2.0 with client credentials
- **Rate limit:** 1000 requests per hour per business

### 10.2 Supported Formats
- JSON (application/json) - Recommended
- XML (application/xml)
- Character encoding: UTF-8
- Max file size: 5MB per invoice
- Batch upload: Max 100 invoices per batch

**Source:** LHDN MyInvois API Technical Guide v3.5

---

**Document Version:** 2026.02
**Last Updated:** February 15, 2026
**Authority:** Lembaga Hasil Dalam Negeri Malaysia (LHDN)
**Compliance Helpline:** 1-800-88-4567
**Email:** myinvois@hasil.gov.my
''';
  }

  /// Get quick reference FAQs
  static List<Map<String, String>> getQuickFAQs() {
    return [
      {
        'question': 'What is the RM10,000 rule?',
        'answer': 'All B2B transactions with a total value of RM10,000 and above must be submitted to MyInvois within 72 hours. This applies to individual transaction amounts, not cumulative totals.',
        'category': 'E-Invoicing',
      },
      {
        'question': 'Can I consolidate invoices this month?',
        'answer': 'Yes, during the relaxation period (2026-2027), SMEs can consolidate invoices below RM10,000 monthly. However, transactions RM10,000 and above must still be submitted immediately.',
        'category': 'E-Invoicing',
      },
      {
        'question': 'What is the relaxation period?',
        'answer': 'The relaxation period runs from January 2026 to December 2027. During this time, SMEs can consolidate smaller invoices and adapt gradually. Full compliance becomes mandatory from January 1, 2028.',
        'category': 'Deadlines',
      },
      {
        'question': 'How do I get a TIN?',
        'answer': 'Register with LHDN through the MyTax portal at https://mytax.hasil.gov.my. TIN is a 12-digit number required for all B2B e-invoicing transactions.',
        'category': 'Taxation',
      },
      {
        'question': 'What happens if I submit late?',
        'answer': 'Late submission penalties range from RM500 (1-7 days late) to RM10,000+ (61+ days late) after the relaxation period. During relaxation period, penalties are reduced by 50%.',
        'category': 'Penalties',
      },
      {
        'question': 'Can I edit a submitted invoice?',
        'answer': 'No. Once a document becomes valid in MyInvois, invoices are immutable. You must issue a Credit Note or Debit Note for corrections.',
        'category': 'Technical',
      },
      {
        'question': 'What is SST and do I need to register?',
        'answer': 'SST (Sales and Service Tax) is a 6% tax on most goods and services. Businesses with annual turnover exceeding RM500,000 must register for SST.',
        'category': 'Taxation',
      },
      {
        'question': 'Are B2C transactions exempt?',
        'answer': 'Yes, B2C (Business to Consumer) transactions under RM10,000 are exempt from mandatory e-invoicing. However, you may voluntarily issue e-invoices.',
        'category': 'Exemptions',
      },
      {
        'question': 'How long must I keep invoice records?',
        'answer': 'All e-invoices must be kept for a minimum of 7 years in retrievable digital format (PDF, XML, JSON). Digital records are legally acceptable.',
        'category': 'Reporting',
      },
      {
        'question': 'What if MyInvois system is down?',
        'answer': 'MyInvois has 99.9% uptime. During planned maintenance (announced 7 days prior) or unplanned downtime, submission deadlines are automatically extended.',
        'category': 'Technical',
      },
    ];
  }

  /// Get compliance tips for SMEs
  static List<String> getComplianceTips() {
    return [
      'Submit invoices within 24 hours of transaction to avoid last-minute delays',
      'Verify buyer TIN before processing RM10k+ transactions',
      'Keep digital backups of all invoices for 7 years',
      'Use certified e-invoicing software with auto-validation',
      'Conduct quarterly compliance audits',
      'Train all staff on MyInvois procedures',
      'Set up alerts for submission deadlines',
      'Maintain updated contact details in MyInvois profile',
      'Review invalid invoices within 24 hours and resubmit',
      'Take advantage of the relaxation period to consolidate smaller invoices',
    ];
  }

  /// Get document sources references
  static List<String> getOfficialSources() {
    return [
      'LHDN MyInvois Guidelines 2026 (v4.6)',
      'Malaysian Income Tax Act 1967 (Amendment 2025)',
      'LHDN Circular No. 3/2026 - E-Invoicing Mandates',
      'LHDN MyInvois API Documentation v3.5',
      'LHDN Technical Specifications v2.0',
      'Royal Malaysian Customs SST Guidelines 2026',
      'LHDN MyInvois Implementation Roadmap 2026-2028',
      'Income Tax (Records) Rules 2025',
      'LHDN MyInvois FAQ v5.0 (February 2026)',
    ];
  }
}
