class JournalEntryModel {
  final String id;
  final String userId;
  final String content;
  final String mood;
  final double moodScore; // 0.0 to 1.0
  final List<String> tags;
  final DateTime date;
  final Map<String, dynamic>? emotionAnalysis;
  final List<String>? stressTriggers;

  JournalEntryModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.mood,
    required this.moodScore,
    this.tags = const [],
    required this.date,
    this.emotionAnalysis,
    this.stressTriggers,
  });

  factory JournalEntryModel.fromMap(Map<String, dynamic> map) {
    return JournalEntryModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      content: map['content'] ?? '',
      mood: map['mood'] ?? 'neutral',
      moodScore: (map['moodScore'] ?? 0.5).toDouble(),
      tags: List<String>.from(map['tags'] ?? []),
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date'] as int)
          : DateTime.now(),
      emotionAnalysis: map['emotionAnalysis'],
      stressTriggers: map['stressTriggers'] != null
          ? List<String>.from(map['stressTriggers'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'content': content,
      'mood': mood,
      'moodScore': moodScore,
      'tags': tags,
      'date': date.millisecondsSinceEpoch,
      'emotionAnalysis': emotionAnalysis,
      'stressTriggers': stressTriggers,
    };
  }
}

