/// Represents the final signed invoice document that is persisted / submitted.
///
/// Structure mirrors the LHDN-recommended format:
/// ```json
/// {
///   "invoice"     : { /* Invoice fields */ },
///   "signature"   : "Base64EncodedRSASignatureHere",
///   "publicKeyId" : "uid-of-the-signer"
/// }
/// ```
class SignedInvoicePayload {
  /// The canonical invoice JSON that was signed.
  final Map<String, dynamic> invoice;

  /// Base64-encoded RSA-SHA256 signature over the canonical JSON bytes.
  final String signature;

  /// The user-id that owns the private key used to sign; the corresponding
  /// public key is retrievable from Firestore at `users/{publicKeyId}.publicKey`.
  final String publicKeyId;

  const SignedInvoicePayload({
    required this.invoice,
    required this.signature,
    required this.publicKeyId,
  });

  Map<String, dynamic> toJson() => {
        'invoice': invoice,
        'signature': signature,
        'publicKeyId': publicKeyId,
      };

  factory SignedInvoicePayload.fromJson(Map<String, dynamic> json) =>
      SignedInvoicePayload(
        invoice: Map<String, dynamic>.from(json['invoice'] as Map),
        signature: json['signature'] as String,
        publicKeyId: json['publicKeyId'] as String,
      );

  @override
  String toString() =>
      'SignedInvoicePayload(publicKeyId: $publicKeyId, '
      'signatureLength: ${signature.length})';
}
