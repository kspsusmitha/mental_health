import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/user_model.dart';
import 'realtime_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modules/admin/admin_credentials.dart';

class AuthService {
  final RealtimeDatabaseService _database = RealtimeDatabaseService();
  UserModel? _currentUser;
  
  // Get current user
  UserModel? get currentUser => _currentUser;

  // Get the node path based on user type
  String _getNodePath(UserType userType) {
    switch (userType) {
      case UserType.user:
        return 'users';
      case UserType.therapist:
        return 'therapists';
      case UserType.admin:
        return 'admins';
    }
  }

  // Get current user's node path
  String? getCurrentUserNodePath() {
    if (_currentUser == null) return null;
    return _getNodePath(_currentUser!.userType);
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _currentUser?.id;
  }

  // Initialize - load current user from shared preferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('current_user_id');
      final userTypeStr = prefs.getString('current_user_type');
      
      if (userId != null && userTypeStr != null) {
        final userType = UserType.fromString(userTypeStr);
        _currentUser = await getUserData(userId, userType);
      }
    } catch (e) {
      _currentUser = null;
    }
  }

  // Hash password (simple SHA256 - in production, use bcrypt or similar)
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmailPassword(
    String email,
    String password, {
    UserType? selectedUserType,
  }) async {
    try {
      UserModel? foundUser;
      
      // If user type is specified, check only that node
      if (selectedUserType != null) {
        final nodePath = _getNodePath(selectedUserType);
        final usersData = await _database.readList(nodePath);
        
        for (var userData in usersData) {
          try {
            final user = UserModel.fromMap(userData);
            if (user.email.toLowerCase().trim() == email.toLowerCase().trim()) {
              foundUser = user;
              break;
            }
          } catch (e) {
            continue;
          }
        }
      } else {
        // Check all nodes if no type specified
        final nodes = ['users', 'therapists', 'admins'];
        for (var node in nodes) {
          try {
            final usersData = await _database.readList(node);
            for (var userData in usersData) {
              try {
                final user = UserModel.fromMap(userData);
                if (user.email.toLowerCase().trim() == email.toLowerCase().trim()) {
                  foundUser = user;
                  break;
                }
              } catch (e) {
                continue;
              }
            }
            if (foundUser != null) break;
          } catch (e) {
            continue;
          }
        }
      }

      if (foundUser == null) {
        throw Exception('User not found');
      }

      // Get stored password hash
      final userAuthData = await _database.readData('auth/${foundUser.id}');
      if (userAuthData == null) {
        throw Exception('Authentication data not found');
      }

      final storedPasswordHash = userAuthData['passwordHash'] as String?;
      if (storedPasswordHash == null) {
        throw Exception('Password not set');
      }

      // Verify password
      final inputPasswordHash = _hashPassword(password);
      if (inputPasswordHash != storedPasswordHash) {
        throw Exception('Invalid password');
      }

      // Set current user
      _currentUser = foundUser;
      
      // Save to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', foundUser.id);
      await prefs.setString('current_user_type', foundUser.userType.toString());

      return foundUser;
    } catch (e) {
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  // Register with email and password
  Future<UserModel?> registerWithEmailPassword(
    String email,
    String password,
    String name,
    UserType userType,
  ) async {
    try {
      // Prevent admin registration - admins have predefined credentials
      if (userType == UserType.admin) {
        throw Exception('Admin registration is not allowed. Admins have predefined credentials.');
      }

      // Validate inputs
      if (email.isEmpty || password.isEmpty || name.isEmpty) {
        throw Exception('All fields are required');
      }

      // Get the node path for this user type
      final nodePath = _getNodePath(userType);

      // Check if email already exists in the specific node
      try {
        final usersData = await _database.readList(nodePath);
        
        for (var userData in usersData) {
          try {
            final user = UserModel.fromMap(userData);
            if (user.email.toLowerCase().trim() == email.toLowerCase().trim()) {
              throw Exception('Email already registered');
            }
          } catch (e) {
            // If it's the email already registered exception, rethrow it
            if (e.toString().contains('Email already registered')) {
              rethrow;
            }
            // Skip invalid user data
            continue;
          }
        }
      } catch (e) {
        // If it's the email already registered exception, rethrow it
        if (e.toString().contains('Email already registered')) {
          rethrow;
        }
        // If reading users fails (e.g., no users exist yet), continue with registration
      }

      // Generate user ID
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Hash password
      final passwordHash = _hashPassword(password);

      // Create user model
      final userModel = UserModel(
        id: userId,
        email: email.trim(),
        name: name.trim(),
        userType: userType,
        createdAt: DateTime.now(),
      );

      // Save user data to the appropriate node
      await _database.writeData(
        '$nodePath/$userId',
        userModel.toMap(),
      );

      // Save authentication data (password hash)
      await _database.writeData(
        'auth/$userId',
        {
          'email': email.toLowerCase().trim(),
          'passwordHash': passwordHash,
          'userType': userType.toString(),
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
      );

      // Set current user
      _currentUser = userModel;
      
      // Save to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', userId);
      await prefs.setString('current_user_type', userType.toString());

      return userModel;
    } catch (e) {
      // Re-throw if it's already a formatted exception
      if (e.toString().contains('Email already registered')) {
        rethrow;
      }
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    await prefs.remove('current_user_type');
  }

  // Get user data - checks all nodes
  Future<UserModel?> getUserData(String userId, [UserType? userType]) async {
    try {
      // If user type is known, check only that node
      if (userType != null) {
        final nodePath = _getNodePath(userType);
        final data = await _database.readData('$nodePath/$userId');
        if (data != null) {
          return UserModel.fromMap(data);
        }
        return null;
      }
      
      // Otherwise check all nodes
      final nodes = ['users', 'therapists', 'admins'];
      for (var node in nodes) {
        try {
          final data = await _database.readData('$node/$userId');
          if (data != null) {
            return UserModel.fromMap(data);
          }
        } catch (e) {
          continue;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get user by email - checks specific node or all nodes
  Future<UserModel?> getUserByEmail(String email, {UserType? userType}) async {
    try {
      if (userType != null) {
        // Check only the specified node
        final nodePath = _getNodePath(userType);
        final usersData = await _database.readList(nodePath);
        
        for (var userData in usersData) {
          try {
            final user = UserModel.fromMap(userData);
            if (user.email.toLowerCase().trim() == email.toLowerCase().trim()) {
              return user;
            }
          } catch (e) {
            continue;
          }
        }
        return null;
      }
      
      // Check all nodes
      final nodes = ['users', 'therapists', 'admins'];
      for (var node in nodes) {
        try {
          final usersData = await _database.readList(node);
          for (var userData in usersData) {
            try {
              final user = UserModel.fromMap(userData);
              if (user.email.toLowerCase().trim() == email.toLowerCase().trim()) {
                return user;
              }
            } catch (e) {
              continue;
            }
          }
        } catch (e) {
          continue;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update user data
  Future<void> updateUserData(UserModel user) async {
    try {
      final nodePath = _getNodePath(user.userType);
      await _database.updateData('$nodePath/${user.id}', user.toMap());
      if (_currentUser?.id == user.id) {
        _currentUser = user;
      }
    } catch (e) {
      throw Exception('Update failed: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email, String newPassword, {UserType? userType}) async {
    try {
      final user = await getUserByEmail(email, userType: userType);
      if (user == null) {
        throw Exception('User not found');
      }

      final passwordHash = _hashPassword(newPassword);
      await _database.updateData(
        'auth/${user.id}',
        {
          'passwordHash': passwordHash,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  // Initialize predefined admin accounts in the database
  // This ensures the admin branch exists and predefined admins are available
  Future<void> initializePredefinedAdmins() async {
    try {
      for (final adminAccount in AdminCredentials.predefinedAdmins) {
        // Check if admin already exists
        final existingAdmin = await getUserByEmail(
          adminAccount.email,
          userType: UserType.admin,
        );

        // If admin doesn't exist, create it
        if (existingAdmin == null) {
          // Generate admin ID (using timestamp for uniqueness)
          final adminId = 'admin_${DateTime.now().millisecondsSinceEpoch}_${adminAccount.email.hashCode}';
          
          // Hash password
          final passwordHash = _hashPassword(adminAccount.password);

          // Create admin user model
          final adminModel = UserModel(
            id: adminId,
            email: adminAccount.email.trim(),
            name: adminAccount.name.trim(),
            userType: UserType.admin,
            createdAt: DateTime.now(),
          );

          // Save admin data to admins node
          await _database.writeData(
            'admins/$adminId',
            adminModel.toMap(),
          );

          // Save authentication data (password hash)
          await _database.writeData(
            'auth/$adminId',
            {
              'email': adminAccount.email.toLowerCase().trim(),
              'passwordHash': passwordHash,
              'userType': UserType.admin.toString(),
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            },
          );
        }
      }
    } catch (e) {
      // Log error but don't throw - initialization should not break app startup
      print('Error initializing predefined admins: $e');
    }
  }

  // Auth state stream (for compatibility)
  Stream<UserModel?> get authStateChanges {
    return Stream.value(_currentUser);
  }
}
