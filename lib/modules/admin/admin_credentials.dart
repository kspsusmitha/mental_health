/// Predefined Admin Credentials
/// 
/// This file contains the predefined admin credentials for the application.
/// Admins cannot register through the app - they must use these predefined credentials.
class AdminCredentials {
  /// List of predefined admin accounts
  static const List<AdminAccount> predefinedAdmins = [
    AdminAccount(
      email: 'admin@mentalhealth.com',
      password: 'Admin@123',
      name: 'System Administrator',
    ),
    AdminAccount(
      email: 'admin1@mentalhealth.com',
      password: 'Admin1@123',
      name: 'Admin User 1',
    ),
  ];

  /// Get admin account by email
  static AdminAccount? getAdminByEmail(String email) {
    try {
      return predefinedAdmins.firstWhere(
        (admin) => admin.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if email belongs to a predefined admin
  static bool isPredefinedAdmin(String email) {
    return getAdminByEmail(email) != null;
  }
}

/// Admin Account Model
class AdminAccount {
  final String email;
  final String password;
  final String name;

  const AdminAccount({
    required this.email,
    required this.password,
    required this.name,
  });
}
