class WellnessResourceModel {
  final String id;
  final String title;
  final String description;
  final ResourceType type;
  final String url;
  final String? thumbnailUrl;
  final int duration; // in minutes
  final List<String> tags;
  final bool isApproved;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final int views;
  final double rating;

  WellnessResourceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    this.duration = 0,
    this.tags = const [],
    this.isApproved = false,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    this.views = 0,
    this.rating = 0.0,
  });

  factory WellnessResourceModel.fromMap(Map<String, dynamic> map) {
    return WellnessResourceModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: ResourceType.fromString(map['type'] ?? 'meditation'),
      url: map['url'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      duration: map['duration'] ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
      isApproved: map['isApproved'] ?? false,
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['approvedAt'] as int)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      views: map['views'] ?? 0,
      rating: (map['rating'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString(),
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'tags': tags,
      'isApproved': isApproved,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'views': views,
      'rating': rating,
    };
  }
}

enum ResourceType {
  meditation,
  video,
  audio,
  article;

  static ResourceType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'video':
        return ResourceType.video;
      case 'audio':
        return ResourceType.audio;
      case 'article':
        return ResourceType.article;
      default:
        return ResourceType.meditation;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ResourceType.video:
        return 'video';
      case ResourceType.audio:
        return 'audio';
      case ResourceType.article:
        return 'article';
      default:
        return 'meditation';
    }
  }
}

