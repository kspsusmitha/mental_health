class TherapistModel {
  final String id;
  final String userId;
  final String name;
  final String specialization;
  final String bio;
  final String? profileImageUrl;
  final List<String> ageGroups; // e.g., ['adolescent', 'adult', 'senior']
  final List<String> specializations; // e.g., ['anxiety', 'depression', 'stress']
  final double rating;
  final int totalSessions;
  final bool isVerified;
  final List<String> languages;
  final Map<String, dynamic>? availability;

  TherapistModel({
    required this.id,
    required this.userId,
    required this.name,
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
  });

  factory TherapistModel.fromMap(Map<String, dynamic> map) {
    return TherapistModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      specialization: map['specialization'] ?? '',
      bio: map['bio'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      ageGroups: List<String>.from(map['ageGroups'] ?? []),
      specializations: List<String>.from(map['specializations'] ?? []),
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalSessions: map['totalSessions'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      languages: List<String>.from(map['languages'] ?? []),
      availability: map['availability'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
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
    };
  }
}

