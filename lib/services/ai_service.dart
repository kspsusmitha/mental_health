import 'package:flutter/foundation.dart';
import '../models/emotion_analysis_model.dart';
import 'mental_health_api_service.dart';

class AIService {
  final MentalHealthApiService apiService;

  AIService({required this.apiService});

  // Get simple AI response (for chat)
  Future<String> getAIResponse(String userMessage) async {
    try {
      return await apiService.chat(userMessage);
    } catch (e) {
      debugPrint('Error in AIService.getAIResponse: $e');
      return 'I apologize, but I\'m having trouble processing your request right now. Please try again later.';
    }
  }

  // Get AI chatbot response
  Future<String> getChatResponse(
    String userMessage,
    List<Map<String, String>> chatHistory,
  ) async {
    try {
      // The backend API handles the conversation
      return await apiService.chat(userMessage);
    } catch (e) {
      debugPrint('Error in AIService.getChatResponse: $e');
      return 'I apologize, but I\'m having trouble processing your request right now. Please try again later.';
    }
  }

  // Analyze emotions from text using Backend API
  Future<EmotionAnalysisModel> analyzeEmotions(
    String text,
    String userId,
    List<Map<String, dynamic>>? journalHistory,
  ) async {
    try {
      final analysisData = await apiService.analyzeMood();

      // Map API response to our internal model
      return EmotionAnalysisModel(
        userId: userId,
        timestamp: DateTime.now(),
        primaryEmotion:
            analysisData['overall_mood']?.toString().toLowerCase() ?? 'neutral',
        emotionScores: {
          'anxiety': 0.5,
          'stress': (analysisData['intensity_level'] ?? 5) / 10.0,
          'sadness': 0.5,
          'anger': 0.5,
          'happiness': 0.5,
        },
        overallScore: (analysisData['intensity_level'] ?? 5) / 10.0,
        riskLevel: 'low',
        suggestedActions: List<String>.from(analysisData['emotion_tags'] ?? []),
      );
    } catch (e) {
      debugPrint('Error in AIService.analyzeEmotions: $e');
      return _getDefaultEmotionAnalysis(userId);
    }
  }

  // Predict mood based on user data
  Future<Map<String, dynamic>> predictMood(
    String userId,
    List<Map<String, dynamic>> chatHistory,
    List<Map<String, dynamic>> journalEntries,
  ) async {
    try {
      final analysisData = await apiService.analyzeMood();
      return {
        'predictedMood': analysisData['overall_mood'] ?? 'neutral',
        'confidence': 0.7,
        'trend': 'stable',
        'riskFactors': analysisData['emotion_tags'] ?? [],
      };
    } catch (e) {
      debugPrint('Error in AIService.predictMood: $e');
      return _getDefaultMoodPrediction();
    }
  }

  // Get personalized wellness recommendations using API
  Future<List<String>> getWellnessRecommendations(
    String userId,
    EmotionAnalysisModel emotionAnalysis,
    List<String>? pastRecommendations,
  ) async {
    try {
      final recommendationsData = await apiService.getRecommendations();
      if (recommendationsData['activities'] != null) {
        return List<String>.from(recommendationsData['activities']);
      }
      return List<String>.from(recommendationsData['recommendations'] ?? []);
    } catch (e) {
      debugPrint('Error in AIService.getWellnessRecommendations: $e');
      return _getDefaultRecommendations(emotionAnalysis.primaryEmotion);
    }
  }

  // Default emotion analysis (Fallback)
  EmotionAnalysisModel _getDefaultEmotionAnalysis(String userId) {
    return EmotionAnalysisModel(
      userId: userId,
      timestamp: DateTime.now(),
      primaryEmotion: 'neutral',
      emotionScores: {
        'anxiety': 0.3,
        'stress': 0.3,
        'sadness': 0.3,
        'anger': 0.2,
        'happiness': 0.5,
      },
      overallScore: 0.5,
      riskLevel: 'low',
      suggestedActions: [
        'Take deep breaths',
        'Practice mindfulness',
        'Consider talking to someone',
      ],
    );
  }

  // Default mood prediction (Fallback)
  Map<String, dynamic> _getDefaultMoodPrediction() {
    return {
      'predictedMood': 'neutral',
      'confidence': 0.5,
      'trend': 'stable',
      'riskFactors': [],
    };
  }

  // Default recommendations (Fallback)
  List<String> _getDefaultRecommendations(String emotion) {
    final recommendations = {
      'anxious': [
        'Try deep breathing exercises',
        'Practice progressive muscle relaxation',
        'Take a short walk in nature',
        'Listen to calming music',
        'Write down your thoughts',
      ],
      'stressed': [
        'Take a break and rest',
        'Do some light stretching',
        'Practice meditation',
        'Talk to a friend',
        'Engage in a hobby you enjoy',
      ],
      'sad': [
        'Reach out to someone you trust',
        'Engage in physical activity',
        'Practice gratitude journaling',
        'Listen to uplifting music',
        'Do something kind for yourself',
      ],
      'depressed': [
        'Consider speaking with a therapist',
        'Maintain a regular sleep schedule',
        'Eat nutritious meals',
        'Get some sunlight',
        'Engage in gentle exercise',
      ],
    };

    return recommendations[emotion] ??
        [
          'Take deep breaths',
          'Go for a walk',
          'Practice mindfulness',
          'Write in your journal',
          'Listen to calming music',
        ];
  }

  void resetChat() {
    // API reset logic if needed
  }
}
