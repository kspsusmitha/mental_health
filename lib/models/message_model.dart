class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? emotionData;
  final String? suggestedAction;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.emotionData,
    this.suggestedAction,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      emotionData: map['emotionData'],
      suggestedAction: map['suggestedAction'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'emotionData': emotionData,
      'suggestedAction': suggestedAction,
    };
  }
}

