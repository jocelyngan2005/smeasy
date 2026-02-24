// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypton/crypton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../backend/invoice/models/signed_invoice_payload.dart';

/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// DigitalSignatureService
///
/// Simulates the LHDN-recommended digital signature workflow using a real
/// 2048-bit RSA keypair:
///
///   Step 1  Â·  One-time setup on account creation
///   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
///   â€¢ Generate a 2 048-bit RSA keypair via [generateAndStoreKeyPair].
///   â€¢ Store private key in device-level secure storage
///     (Android EncryptedSharedPreferences / iOS Keychain).
///   â€¢ Upload public key to Firestore â†’ users/{uid}.publicKey
///     (acts as the LHDN â€œkey registrationâ€ step).
///
///   Step 2  Â·  Per-invoice signing via [buildSignedPayload]
///   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
///   1. Serialise invoice to a canonical JSON string.
///   2. Sign the string with the private key (RSA-SHA256 via PKCS#1 v1.5).
///   3. Attach the Base64-encoded signature + key-owner id.
///
///   Final payload structure:
///   {
///     "invoice"     : { â€¦ invoice fields â€¦ },
///     "signature"   : "Base64EncodedSignatureHere",
///     "publicKeyId" : "uid-of-the-signer"
///   }
///
///   Verification via [verifySignature]
///   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
///   Fetches the public key from Firestore and verifies the signature.
/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class DigitalSignatureService {
  DigitalSignatureService._();

  // â”€â”€ Secure storage keys â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const _kPrivateKey  = 'rsa_private_key_pem';
  static const _kPublicKeyId = 'rsa_public_key_id';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ==========================================================================
  // STEP 1 â€” Keypair generation  (called once, on account creation)
  // ==========================================================================

  /// Generates a 2048-bit RSA keypair for [uid].
  ///
  /// * Private key  â†’  stored in device secure storage (never leaves device).
  /// * Public  key  â†’  written to Firestore `users/{uid}` (verifiable by anyone).
  ///
  /// Calling this when keys already exist on the device is a no-op unless
  /// [force] is `true`.
  ///
  /// Keypair generation is CPU-intensive (~1-3 s on a mid-range device) and
  /// runs in a background [Isolate] so the UI stays responsive.
  static Future<void> generateAndStoreKeyPair(
    String uid, {
    bool force = false,
  }) async {
    // â”€â”€ Skip if already generated â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    if (!force) {
      final existing = await _storage.read(key: _kPrivateKey);
      if (existing != null) {
        debugPrint('[DSS] Keypair already exists for uid=$uid â€” skipping.');
        return;
      }
    }

    debugPrint('[DSS] Generating 2048-bit RSA keypair for uid=$uid â€¦');

    // Run key generation in a background isolate to avoid UI jank.
    final pems = await compute(_isolateGenerateKeyPair, null);
    final privatePem = pems[0];
    final publicPem  = pems[1];

    // â”€â”€ Persist private key locally (secure enclave / keychain) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    await _storage.write(key: _kPrivateKey,  value: privatePem);
    await _storage.write(key: _kPublicKeyId, value: uid);

    // â”€â”€ Upload public key to Firestore â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    await _db.collection('users').doc(uid).set(
      {
        'publicKey'        : publicPem,
        'publicKeyId'      : uid,
        'keyRegisteredAt'  : FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    debugPrint('[DSS] Keypair ready. Public key registered in Firestore.');
  }

  // ==========================================================================
  // STEP 2 â€” Sign an invoice
  // ==========================================================================

  /// Signs [invoiceJson] with the locally-stored RSA private key (RSA-SHA256).
  ///
  /// Returns a Base64-encoded signature string.
  ///
  /// Throws [StateError] if no private key exists on this device yet.
  static Future<String> signInvoiceJson(
    Map<String, dynamic> invoiceJson,
  ) async {
    final privatePem = await _storage.read(key: _kPrivateKey);
    if (privatePem == null) {
      throw StateError(
        '[DSS] No private key found on this device. '
        'Call generateAndStoreKeyPair() during account creation.',
      );
    }

    final canonicalJson = jsonEncode(invoiceJson);
    return compute(
      _isolateSign,
      _SignRequest(privatePem: privatePem, message: canonicalJson),
    );
  }

  /// Builds the complete signed invoice payload:
  /// ```json
  /// {
  ///   "invoice"     : { â€¦ },
  ///   "signature"   : "Base64EncodedRSA-SHA256SignatureHere",
  ///   "publicKeyId" : "uid"
  /// }
  /// ```
  static Future<SignedInvoicePayload> buildSignedPayload(
    Map<String, dynamic> invoiceJson,
  ) async {
    final uid       = await _storage.read(key: _kPublicKeyId) ?? 'unknown';
    final signature = await signInvoiceJson(invoiceJson);
    return SignedInvoicePayload(
      invoice     : invoiceJson,
      signature   : signature,
      publicKeyId : uid,
    );
  }

  // ==========================================================================
  // VERIFICATION â€” confirm a signed payload is authentic
  // ==========================================================================

  /// Verifies [signature] over [invoiceJson] using the public key fetched
  /// from Firestore for [publicKeyId].
  ///
  /// Returns `true` when the signature is cryptographically valid.
  static Future<bool> verifySignature({
    required Map<String, dynamic> invoiceJson,
    required String signature,
    required String publicKeyId,
  }) async {
    try {
      final doc = await _db.collection('users').doc(publicKeyId).get();
      final publicPem = doc.data()?['publicKey'] as String?;
      if (publicPem == null) return false;

      final canonicalJson = jsonEncode(invoiceJson);
      return compute(
        _isolateVerify,
        _VerifyRequest(
          publicPem   : publicPem,
          message     : canonicalJson,
          signature   : signature,
        ),
      );
    } catch (e) {
      debugPrint('[DSS] Verification error: $e');
      return false;
    }
  }

  // ==========================================================================
  // STATUS HELPERS
  // ==========================================================================

  /// Returns `true` when a private key is present on this device.
  static Future<bool> hasKeyPair() async {
    final key = await _storage.read(key: _kPrivateKey);
    return key != null;
  }

  /// Returns the public-key owner id stored on this device (= Firebase uid).
  static Future<String?> storedPublicKeyId() async {
    return _storage.read(key: _kPublicKeyId);
  }

  /// Retrieves the public key PEM stored in Firestore for [uid].
  static Future<String?> fetchPublicKey(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['publicKey'] as String?;
  }

  /// Deletes locally-stored keys (call on sign-out or account deletion).
  static Future<void> clearLocalKeys() async {
    await Future.wait([
      _storage.delete(key: _kPrivateKey),
      _storage.delete(key: _kPublicKeyId),
    ]);
    debugPrint('[DSS] Local keys cleared.');
  }
}

// =============================================================================
// Isolate workers  (top-level functions â€” pure Dart, no Flutter plugins)
// =============================================================================

/// Generates a 2048-bit RSA keypair and returns [privatePem, publicPem].
List<String> _isolateGenerateKeyPair(void _) {
  final keypair = RSAKeypair.fromRandom(keySize: 2048);
  return [
    keypair.privateKey.toPEM(),
    keypair.publicKey.toPEM(),
  ];
}

class _SignRequest {
  final String privatePem;
  final String message;
  const _SignRequest({required this.privatePem, required this.message});
}

/// Signs [message] with the PEM-encoded private key.
/// Returns a Base64-encoded RSA-SHA256 signature.
String _isolateSign(_SignRequest req) {
  final privateKey = RSAPrivateKey.fromString(req.privatePem);
  final dataBytes  = Uint8List.fromList(utf8.encode(req.message));
  final sigBytes   = privateKey.createSHA256Signature(dataBytes);
  return base64Encode(sigBytes);
}

class _VerifyRequest {
  final String publicPem;
  final String message;
  final String signature;
  const _VerifyRequest({
    required this.publicPem,
    required this.message,
    required this.signature,
  });
}

/// Verifies [signature] over [message] using the PEM-encoded public key.
bool _isolateVerify(_VerifyRequest req) {
  try {
    final publicKey = RSAPublicKey.fromString(req.publicPem);
    final dataBytes = Uint8List.fromList(utf8.encode(req.message));
    final sigBytes  = base64Decode(req.signature);
    return publicKey.verifySHA256Signature(dataBytes, sigBytes);
  } catch (_) {
    return false;
  }
}
