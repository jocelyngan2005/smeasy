import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/digital_signature_service.dart';
import '../../firestore_collections.dart';
import '../models/user_model.dart';

/// Firebase Auth + Firestore-backed authentication service.
///
/// User profiles are stored in /users/{uid} following the agreed schema.
/// A [currentUser] cache is maintained in memory and refreshed on each auth
/// state change, so existing screens can read it synchronously via [currentUser].
class AuthService {
  AuthService._()
      : _auth = FirebaseAuth.instance,
        _db = FirebaseFirestore.instance {
    // Keep the in-memory cache in sync whenever Firebase auth state changes.
    _auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser == null) {
        _currentUser = null;
      } else {
        _currentUser = await _fetchUserModel(firebaseUser.uid);
      }
    });
  }

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// In-memory cache — populated on sign-in and cleared on sign-out.
  UserModel? _currentUser;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestoreCollections.users);

  // ---------------------------------------------------------------------------
  // State helpers
  // ---------------------------------------------------------------------------

  /// Synchronous snapshot of the current user (may be null before the first
  /// sign-in or while the async fetch is in progress).
  UserModel? get currentUser => _currentUser;

  /// Stream that emits a fresh [UserModel] on every auth state change.
  Stream<UserModel?> get userStream {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return _fetchUserModel(firebaseUser.uid);
    });
  }

  bool get isAuthenticated => _auth.currentUser != null;

  String? get currentUserId => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Sign in
  // ---------------------------------------------------------------------------

  Future<UserModel?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null) return null;
    _currentUser = await _fetchUserModel(credential.user!.uid);
    return _currentUser;
  }

  // ---------------------------------------------------------------------------
  // Sign up
  // ---------------------------------------------------------------------------

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String businessName,
    required String tin,
    required String phone,
    required String address,
    String? businessType,
    String? ssmNumber,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null) return null;

    final uid = credential.user!.uid;
    final model = UserModel(
      id: uid,
      email: email,
      businessName: businessName,
      businessType: businessType,
      ssmNumber: ssmNumber,
      tin: tin,
      phone: phone,
      address: address,
      createdAt: DateTime.now(),
      isVerified: false,
    );

    await _users.doc(uid).set(model.toFirestore());
    _currentUser = model;

    // ── Step 1: Generate RSA keypair (one-time) ──────────────────────────────
    // Runs in background; errors are non-fatal so sign-up still succeeds.
    DigitalSignatureService.generateAndStoreKeyPair(uid).catchError(
      (e) => {},
    );

    return model;
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
  }

  // ---------------------------------------------------------------------------
  // Password reset
  // ---------------------------------------------------------------------------

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // ---------------------------------------------------------------------------
  // Profile update
  // ---------------------------------------------------------------------------

  Future<UserModel?> updateProfile(UserModel updated) async {
    await _users.doc(updated.id).update(updated.toFirestore());
    _currentUser = updated;
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Mark email as verified (called after email-link verification)
  // ---------------------------------------------------------------------------

  Future<void> markVerified(String uid) async {
    await _users.doc(uid).update({'isVerified': true});
    if (_currentUser?.id == uid) {
      _currentUser = _currentUser?.copyWith(isVerified: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<UserModel?> _fetchUserModel(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }
}
