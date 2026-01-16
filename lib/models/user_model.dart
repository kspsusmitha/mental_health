class UserModel {
  final String id;
  final String email;
  final String name;
  final String? profileImageUrl;
  final UserType userType;
  final DateTime createdAt;
  final Map<String, dynamic>? additionalInfo;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
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

