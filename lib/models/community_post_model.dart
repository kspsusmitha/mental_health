class CommunityPostModel {
  final String id;
  final String userId;
  final String userName;
  final String? userProfileImageUrl;
  final String title;
  final String content;
  final List<String>? tags;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isApproved;
  final String? approvedBy;
  final DateTime? approvedAt;
  final int likesCount;
  final int commentsCount;
  final List<String> likedBy; // User IDs who liked this post

  CommunityPostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userProfileImageUrl,
    required this.title,
    required this.content,
    this.tags,
    required this.createdAt,
    this.updatedAt,
    this.isApproved = false,
    this.approvedBy,
    this.approvedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedBy = const [],
  });

  factory CommunityPostModel.fromMap(Map<String, dynamic> map) {
    return CommunityPostModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userProfileImageUrl: map['userProfileImageUrl'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
      isApproved: map['isApproved'] ?? false,
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['approvedAt'] as int)
          : null,
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      likedBy: map['likedBy'] != null ? List<String>.from(map['likedBy']) : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userProfileImageUrl': userProfileImageUrl,
      'title': title,
      'content': content,
      'tags': tags,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'isApproved': isApproved,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.millisecondsSinceEpoch,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'likedBy': likedBy,
    };
  }

  CommunityPostModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userProfileImageUrl,
    String? title,
    String? content,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isApproved,
    String? approvedBy,
    DateTime? approvedAt,
    int? likesCount,
    int? commentsCount,
    List<String>? likedBy,
  }) {
    return CommunityPostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isApproved: isApproved ?? this.isApproved,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedBy: likedBy ?? this.likedBy,
    );
  }
}
