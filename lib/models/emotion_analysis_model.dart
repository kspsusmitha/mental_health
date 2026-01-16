class EmotionAnalysisModel {
  final String userId;
  final DateTime timestamp;
  final String primaryEmotion;
  final Map<String, double> emotionScores; // e.g., {'anxiety': 0.7, 'stress': 0.5}
  final double overallScore; // 0.0 to 1.0
  final String riskLevel; // 'low', 'medium', 'high', 'critical'
  final List<String> suggestedActions;
  final String? analysisText;

  EmotionAnalysisModel({
    required this.userId,
    required this.timestamp,
    required this.primaryEmotion,
    required this.emotionScores,
    required this.overallScore,
    required this.riskLevel,
    this.suggestedActions = const [],
    this.analysisText,
  });

  factory EmotionAnalysisModel.fromMap(Map<String, dynamic> map) {
    return EmotionAnalysisModel(
      userId: map['userId'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      primaryEmotion: map['primaryEmotion'] ?? 'neutral',
      emotionScores: Map<String, double>.from(
        map['emotionScores']?.map((k, v) => MapEntry(k, v.toDouble())) ?? {},
      ),
      overallScore: (map['overallScore'] ?? 0.5).toDouble(),
      riskLevel: map['riskLevel'] ?? 'low',
      suggestedActions: List<String>.from(map['suggestedActions'] ?? []),
      analysisText: map['analysisText'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'primaryEmotion': primaryEmotion,
      'emotionScores': emotionScores,
      'overallScore': overallScore,
      'riskLevel': riskLevel,
      'suggestedActions': suggestedActions,
      'analysisText': analysisText,
    };
  }
}

