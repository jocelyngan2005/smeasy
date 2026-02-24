/// Central definition of all Firestore collection paths.
/// Matches the agreed schema:
///   /users/{userId}
///   /invoices/{invoiceId}
///   /customers/{customerId}
///   /compliance_alerts/{alertId}
///   /compliance_questions/{questionId}
///   /support_locations/{locationId}
///   /analytics_cache/{userId}
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String invoices = 'invoices';
  static const String customers = 'customers';
  static const String complianceAlerts = 'compliance_alerts';
  static const String complianceQuestions = 'compliance_questions';
  static const String supportLocations = 'support_locations';
  static const String analyticsCache = 'analytics_cache';
}
