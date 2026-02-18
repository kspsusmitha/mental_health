import 'package:flutter/foundation.dart';
import '../models/journal_entry_model.dart';
import 'realtime_database_service.dart';
import 'auth_service.dart';
import 'ai_service.dart';

class MoodPredictionService {
  final RealtimeDatabaseService _database = RealtimeDatabaseService();
  final AuthService authService;
  final AIService aiService;

  MoodPredictionService({required this.authService, required this.aiService});

  /// Predict mood patterns based on historical data
  Future<MoodPredictionResult> predictMoodPatterns(String userId) async {
    try {
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) {
        return _getFallbackResult({});
      }

      // Load journal entries for local and AI analysis
      final entriesData = await _database.readList(
        '$userNodePath/$userId/journal_entries',
      );

      final entries = entriesData
          .map((data) => JournalEntryModel.fromMap(data))
          .toList();

      if (entries.isEmpty) {
        return _getFallbackResult({});
      }

      // Sort by date
      entries.sort((a, b) => b.date.compareTo(a.date));

      // 1. AI Prediction from AIService
      final aiPrediction = await aiService.predictMood(
        userId,
        [], // We could pass chat history here if we had it easily
        entriesData,
      );

      // 2. Local pattern analysis (complementary)
      final patterns = _analyzePatterns(entries);
      final stressTriggers = _identifyStressTriggers(entries);

      final predictedMood =
          aiPrediction['predictedMood'] ?? _predictNextMood(entries);
      final confidence = (aiPrediction['confidence'] ?? 0.8).toDouble();

      // Combine AI recommendations with local ones
      final recommendations = _generateRecommendations(
        entries,
        patterns,
        stressTriggers,
      );

      // Add AI identified risk factors to stress triggers or patterns
      if (aiPrediction['riskFactors'] != null) {
        final aiFactors = List<String>.from(aiPrediction['riskFactors']);
        for (var factor in aiFactors) {
          if (!stressTriggers.contains(factor)) {
            stressTriggers.add(factor);
          }
        }
      }

      return MoodPredictionResult(
        predictedMood: predictedMood,
        confidence: confidence,
        patterns: patterns,
        stressTriggers: stressTriggers,
        recommendations: recommendations,
      );
    } catch (e) {
      debugPrint('Error in predictMoodPatterns: $e');
      return MoodPredictionResult(
        predictedMood: 'neutral',
        confidence: 0.0,
        patterns: [],
        stressTriggers: [],
        recommendations: [],
      );
    }
  }

  MoodPredictionResult _getFallbackResult(Map<String, dynamic> apiResponse) {
    return MoodPredictionResult(
      predictedMood:
          apiResponse['overall_mood']?.toString().toLowerCase() ?? 'neutral',
      confidence: (apiResponse['intensity_level'] ?? 5).toDouble() / 10.0,
      patterns: [],
      stressTriggers: List<String>.from(apiResponse['emotion_tags'] ?? []),
      recommendations: [
        apiResponse['description'] ?? 'Keep monitoring your mood.',
      ],
    );
  }

  /// Analyze recurring patterns in mood data
  List<MoodPattern> _analyzePatterns(List<JournalEntryModel> entries) {
    final patterns = <MoodPattern>[];

    // Analyze weekly patterns
    final moodByDayOfWeek = <int, List<double>>{};
    for (final entry in entries) {
      final dayOfWeek = entry.date.weekday;
      if (!moodByDayOfWeek.containsKey(dayOfWeek)) {
        moodByDayOfWeek[dayOfWeek] = <double>[];
      }
      moodByDayOfWeek[dayOfWeek]!.add(entry.moodScore);
    }

    for (final entry in moodByDayOfWeek.entries) {
      final avgMood = entry.value.reduce((a, b) => a + b) / entry.value.length;
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      patterns.add(
        MoodPattern(
          type: 'Weekly Pattern',
          description:
              'Average mood on ${dayNames[entry.key - 1]}: ${_getMoodLabel(avgMood)}',
          frequency: entry.value.length,
          impact: avgMood < 0.4
              ? 'High'
              : avgMood > 0.6
              ? 'Low'
              : 'Medium',
        ),
      );
    }

    // Analyze time-based patterns
    final moodByHour = <int, List<double>>{};
    for (final entry in entries) {
      final hour = entry.date.hour;
      if (!moodByHour.containsKey(hour)) {
        moodByHour[hour] = <double>[];
      }
      moodByHour[hour]!.add(entry.moodScore);
    }

    // Find stress periods
    final stressPeriods = <int>[];
    for (final entry in moodByHour.entries) {
      final avgMood = entry.value.reduce((a, b) => a + b) / entry.value.length;
      if (avgMood < 0.4) {
        stressPeriods.add(entry.key);
      }
    }

    if (stressPeriods.isNotEmpty) {
      patterns.add(
        MoodPattern(
          type: 'Time Pattern',
          description:
              'Higher stress periods: ${stressPeriods.map((h) => '$h:00').join(', ')}',
          frequency: stressPeriods.length,
          impact: 'High',
        ),
      );
    }

    // Analyze mood trends
    if (entries.length >= 7) {
      final recentAvg =
          entries.take(7).map((e) => e.moodScore).reduce((a, b) => a + b) / 7;
      final olderAvg =
          entries
              .skip(7)
              .take(7)
              .map((e) => e.moodScore)
              .reduce((a, b) => a + b) /
          7;

      if (recentAvg < olderAvg - 0.1) {
        patterns.add(
          MoodPattern(
            type: 'Trend',
            description: 'Mood has been declining recently',
            frequency: 1,
            impact: 'High',
          ),
        );
      } else if (recentAvg > olderAvg + 0.1) {
        patterns.add(
          MoodPattern(
            type: 'Trend',
            description: 'Mood has been improving recently',
            frequency: 1,
            impact: 'Low',
          ),
        );
      }
    }

    return patterns;
  }

  /// Identify common stress triggers
  List<String> _identifyStressTriggers(List<JournalEntryModel> entries) {
    final triggerCounts = <String, int>{};

    for (final entry in entries) {
      if (entry.stressTriggers != null) {
        for (final trigger in entry.stressTriggers!) {
          triggerCounts[trigger] = (triggerCounts[trigger] ?? 0) + 1;
        }
      }

      // Also analyze content for common stress words
      final content = entry.content.toLowerCase();
      if (entry.moodScore < 0.4) {
        if (content.contains('work') || content.contains('job')) {
          triggerCounts['Work'] = (triggerCounts['Work'] ?? 0) + 1;
        }
        if (content.contains('family') || content.contains('relationship')) {
          triggerCounts['Relationships'] =
              (triggerCounts['Relationships'] ?? 0) + 1;
        }
        if (content.contains('money') || content.contains('financial')) {
          triggerCounts['Financial'] = (triggerCounts['Financial'] ?? 0) + 1;
        }
        if (content.contains('health') || content.contains('illness')) {
          triggerCounts['Health'] = (triggerCounts['Health'] ?? 0) + 1;
        }
      }
    }

    // Return top 5 triggers
    final sortedTriggers = triggerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedTriggers.take(5).map((e) => e.key).toList();
  }

  /// Predict next mood based on patterns
  String _predictNextMood(List<JournalEntryModel> entries) {
    if (entries.isEmpty) return 'neutral';

    // Get recent mood average
    final recentEntries = entries.take(7);
    final avgMoodScore =
        recentEntries.map((e) => e.moodScore).reduce((a, b) => a + b) /
        recentEntries.length;

    // Check for declining trend
    if (entries.length >= 3) {
      final lastThree = entries.take(3).map((e) => e.moodScore).toList();
      if (lastThree[0] < lastThree[1] && lastThree[1] < lastThree[2]) {
        return 'stressed'; // Declining trend
      }
    }

    return _getMoodLabel(avgMoodScore);
  }

  /// Generate recommendations based on patterns
  List<String> _generateRecommendations(
    List<JournalEntryModel> entries,
    List<MoodPattern> patterns,
    List<String> stressTriggers,
  ) {
    final recommendations = <String>[];

    // Analyze current mood
    final recentMood = entries.isNotEmpty ? entries.first.moodScore : 0.5;

    if (recentMood < 0.4) {
      recommendations.add('Try a guided meditation session');
      recommendations.add('Practice deep breathing exercises');
      recommendations.add('Consider journaling your thoughts');
    }

    // Check for stress triggers
    if (stressTriggers.isNotEmpty) {
      recommendations.add('Focus on managing: ${stressTriggers.first}');
    }

    // Check patterns
    final highImpactPatterns = patterns
        .where((p) => p.impact == 'High')
        .toList();
    if (highImpactPatterns.isNotEmpty) {
      recommendations.add('Be aware of your stress patterns');
    }

    // Check for declining trend
    if (entries.length >= 7) {
      final recentAvg =
          entries.take(7).map((e) => e.moodScore).reduce((a, b) => a + b) / 7;
      final olderAvg =
          entries
              .skip(7)
              .take(7)
              .map((e) => e.moodScore)
              .reduce((a, b) => a + b) /
          7;
      if (recentAvg < olderAvg - 0.1) {
        recommendations.add('Consider speaking with a therapist');
      }
    }

    // Default recommendations
    if (recommendations.isEmpty) {
      recommendations.add('Continue your wellness routine');
      recommendations.add('Stay consistent with journaling');
    }

    return recommendations;
  }

  String _getMoodLabel(double moodScore) {
    if (moodScore < 0.3) return 'depressed';
    if (moodScore < 0.4) return 'stressed';
    if (moodScore < 0.5) return 'anxious';
    if (moodScore < 0.7) return 'neutral';
    if (moodScore < 0.9) return 'happy';
    return 'very_happy';
  }
}

class MoodPredictionResult {
  final String predictedMood;
  final double confidence;
  final List<MoodPattern> patterns;
  final List<String> stressTriggers;
  final List<String> recommendations;

  MoodPredictionResult({
    required this.predictedMood,
    required this.confidence,
    required this.patterns,
    required this.stressTriggers,
    required this.recommendations,
  });
}

class MoodPattern {
  final String type;
  final String description;
  final int frequency;
  final String impact; // High, Medium, Low

  MoodPattern({
    required this.type,
    required this.description,
    required this.frequency,
    required this.impact,
  });
}
