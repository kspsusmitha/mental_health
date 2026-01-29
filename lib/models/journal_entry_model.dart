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
    // Convert emotionAnalysis if it's a Map
    Map<String, dynamic>? emotionAnalysisMap;
    if (map['emotionAnalysis'] != null) {
      if (map['emotionAnalysis'] is Map) {
        emotionAnalysisMap = Map<String, dynamic>.from(map['emotionAnalysis']);
      } else {
        emotionAnalysisMap = map['emotionAnalysis'];
      }
    }
    
    // Convert stressTriggers if it's a List
    List<String>? stressTriggersList;
    if (map['stressTriggers'] != null) {
      if (map['stressTriggers'] is List) {
        stressTriggersList = List<String>.from(map['stressTriggers']);
      } else {
        stressTriggersList = map['stressTriggers'];
      }
    }
    
    return JournalEntryModel(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      mood: map['mood']?.toString() ?? 'neutral',
      moodScore: (map['moodScore'] ?? 0.5).toDouble(),
      tags: map['tags'] != null 
          ? List<String>.from(map['tags'].map((e) => e.toString()))
          : [],
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['date'] is int ? map['date'] as int : int.parse(map['date'].toString())
            )
          : DateTime.now(),
      emotionAnalysis: emotionAnalysisMap,
      stressTriggers: stressTriggersList,
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

