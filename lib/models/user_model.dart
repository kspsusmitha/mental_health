class UserModel {
  final String id;
  final String email;
  final String name;
  final String password; // Storing plain text password as requested
  final String? profileImageUrl;
  final UserType userType;
  final DateTime createdAt;
  final Map<String, dynamic>? additionalInfo;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.password,
    this.profileImageUrl,
    required this.userType,
    required this.createdAt,
    this.additionalInfo,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      password: map['password'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      userType: UserType.fromString(map['userType'] ?? 'user'),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      additionalInfo: map['additionalInfo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'password': password,
      'profileImageUrl': profileImageUrl,
      'userType': userType.toString(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'additionalInfo': additionalInfo,
    };
  }
}

enum UserType {
  user,
  therapist,
  admin;

  static UserType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'therapist':
        return UserType.therapist;
      case 'admin':
        return UserType.admin;
      default:
        return UserType.user;
    }
  }

  @override
  String toString() {
    switch (this) {
      case UserType.therapist:
        return 'therapist';
      case UserType.admin:
        return 'admin';
      default:
        return 'user';
    }
  }
}
