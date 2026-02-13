/// Configuration for invoice backend services
class InvoiceBackendConfig {
  final String geminiApiKey;
  final String? firestoreProjectId;
  
  // Default vendor information (pre-filled for the business)
  final DefaultVendorInfo? defaultVendor;
  
  // MyInvois compliance settings
  final ComplianceSettings complianceSettings;

  const InvoiceBackendConfig({
    required this.geminiApiKey,
    this.firestoreProjectId,
    this.defaultVendor,
    this.complianceSettings = const ComplianceSettings(),
  });
}

class DefaultVendorInfo {
  final String businessName;
  final String tin;
  final String? sstNumber;
  final String? registrationNumber;
  final String email;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  const DefaultVendorInfo({
    required this.businessName,
    required this.tin,
    this.sstNumber,
    this.registrationNumber,
    required this.email,
    required this.phone,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.postalCode,
    this.country = 'MY',
  });

  String toContextString() {
    return '''
Business Name: $businessName
TIN: $tin
${sstNumber != null ? 'SST Number: $sstNumber\n' : ''}
Email: $email
Phone: $phone
Address: $addressLine1${addressLine2 != null ? ', $addressLine2' : ''}, $city, $state $postalCode, $country
''';
  }
}

class ComplianceSettings {
  final double submissionThreshold; // RM10,000 by default
  final bool enableRelaxationPeriod;
  final DateTime? relaxationPeriodEnd;
  final bool autoValidation;

  const ComplianceSettings({
    this.submissionThreshold = 10000.0,
    this.enableRelaxationPeriod = true,
    this.relaxationPeriodEnd,
    this.autoValidation = true,
  });

  bool isInRelaxationPeriod() {
    if (!enableRelaxationPeriod || relaxationPeriodEnd == null) {
      return false;
    }
    return DateTime.now().isBefore(relaxationPeriodEnd!);
  }

  bool requiresSubmission(double totalAmount) {
    return totalAmount >= submissionThreshold;
  }
}
