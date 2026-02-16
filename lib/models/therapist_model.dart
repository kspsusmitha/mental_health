import 'user_model.dart';

class TherapistModel extends UserModel {
  @override
  final String id;
  final String userId;
  @override
  final String name;
  final String specialization;
  @override
  final String email;
  @override
  final String password;
  final String bio;
  @override
  final String? profileImageUrl;
  final List<String> ageGroups;
  final List<String> specializations;
  final double rating;
  final int totalSessions;
  final bool isVerified;
  final List<String> languages;
  final Map<String, List<String>>? availability;

  TherapistModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.password,
    required this.specialization,
    required this.bio,
    this.profileImageUrl,
    this.ageGroups = const [],
    this.specializations = const [],
    this.rating = 0.0,
    this.totalSessions = 0,
    this.isVerified = false,
    this.languages = const [],
    this.availability,
  }) : super(
         id: id,
         email: email,
         name: name,
         password: password,
         profileImageUrl: profileImageUrl,
         userType: UserType.therapist,
         createdAt: DateTime.now(), // Or pass it if needed
       );

  factory TherapistModel.fromMap(Map<String, dynamic> map) {
    // Helper to parse availability map
    Map<String, List<String>>? parseAvailability(dynamic avail) {
      if (avail == null) return null;
      if (avail is! Map) return null;
      try {
        return Map<String, List<String>>.from(
          avail.map(
            (key, value) => MapEntry(
              key.toString(),
              (value as List).map((e) => e.toString()).toList(),
            ),
          ),
        );
      } catch (e) {
        return null;
      }
    }

    return TherapistModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      specialization: map['specialization'] ?? '',
      bio: map['bio'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      ageGroups: List<String>.from(map['ageGroups'] ?? []),
      specializations: List<String>.from(map['specializations'] ?? []),
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalSessions: map['totalSessions'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      languages: List<String>.from(map['languages'] ?? []),
      availability: parseAvailability(map['availability']),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'password': password,
      'specialization': specialization,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'ageGroups': ageGroups,
      'specializations': specializations,
      'rating': rating,
      'totalSessions': totalSessions,
      'isVerified': isVerified,
      'languages': languages,
      'availability': availability,
      // Include UserModel fields if needed by generic user parsers
      'userType': UserType.therapist.toString(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
