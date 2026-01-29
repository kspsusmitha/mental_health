class CommunityCommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userProfileImageUrl;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isApproved;
  final int likesCount;
  final List<String> likedBy; // User IDs who liked this comment

  CommunityCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userProfileImageUrl,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.isApproved = true,
    this.likesCount = 0,
    this.likedBy = const [],
  });

  factory CommunityCommentModel.fromMap(Map<String, dynamic> map) {
    return CommunityCommentModel(
      id: map['id'] ?? '',
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userProfileImageUrl: map['userProfileImageUrl'],
      content: map['content'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
      isApproved: map['isApproved'] ?? true,
      likesCount: map['likesCount'] ?? 0,
      likedBy: map['likedBy'] != null ? List<String>.from(map['likedBy']) : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userProfileImageUrl': userProfileImageUrl,
      'content': content,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'isApproved': isApproved,
      'likesCount': likesCount,
      'likedBy': likedBy,
    };
  }

  CommunityCommentModel copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? userProfileImageUrl,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isApproved,
    int? likesCount,
    List<String>? likedBy,
  }) {
    return CommunityCommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isApproved: isApproved ?? this.isApproved,
      likesCount: likesCount ?? this.likesCount,
      likedBy: likedBy ?? this.likedBy,
    );
  }
}
