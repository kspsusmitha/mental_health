import '../models/user_model.dart';

class MockAuthService {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  // Mock sign in
  Future<UserModel?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // Mock authentication - accept any email/password for demo
    if (email.isNotEmpty && password.isNotEmpty) {
      _currentUser = UserModel(
        id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        name: email.split('@')[0],
        password: password,
        userType: UserType.user,
        createdAt: DateTime.now(),
      );
      return _currentUser;
    }
    return null;
  }

  // Mock register
  Future<UserModel?> registerWithEmailPassword(
    String email,
    String password,
    String name,
    UserType userType,
  ) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    _currentUser = UserModel(
      id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: name,
      password: password,
      userType: userType,
      createdAt: DateTime.now(),
    );
    return _currentUser;
  }

  // Mock sign out
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
  }

  // Mock get user data
  Future<UserModel?> getUserData(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _currentUser;
  }

  // Mock auth state stream
  Stream<UserModel?> get authStateChanges {
    return Stream.value(_currentUser);
  }
}
