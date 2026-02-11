import '../models/user_model.dart';

class AuthService {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  // Mock Firebase Auth - Sign In
  Future<UserModel?> signIn(String email, String password) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

    // Mock successful login
    _currentUser = UserModel(
      id: 'user123',
      email: email,
      businessName: 'SME Trading Sdn Bhd',
      tin: 'C12345678900',
      phone: '0123456789',
      address: 'Kuala Lumpur, Malaysia',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      isVerified: true,
    );

    return _currentUser;
  }

  // Mock Firebase Auth - Sign Up
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String businessName,
    required String tin,
    required String phone,
    required String address,
  }) async {
    await Future.delayed(const Duration(seconds: 2));

    _currentUser = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      businessName: businessName,
      tin: tin,
      phone: phone,
      address: address,
      createdAt: DateTime.now(),
      isVerified: false,
    );

    return _currentUser;
  }

  // Sign Out
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
  }

  // Reset Password
  Future<bool> resetPassword(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    return true; // Mock success
  }

  // Update Profile
  Future<UserModel?> updateProfile(UserModel updatedUser) async {
    await Future.delayed(const Duration(seconds: 1));
    _currentUser = updatedUser;
    return _currentUser;
  }
}
