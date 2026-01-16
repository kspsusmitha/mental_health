import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/emotion_analysis_model.dart';

class AIService {
  static const String _apiKey = 'AIzaSyChcxUCymMoKzf9ckJNJMRgw_oAlTPnYCs';
  static const String _modelName = 'gemini-flash-lite-latest';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent';

  // Get simple AI response (for chat)
  Future<String> getAIResponse(String userMessage) async {
    try {
      final response = await getChatResponse(userMessage, []);
      return response;
    } catch (e) {
      return 'I apologize, but I\'m having trouble processing your request right now. Please try again later.';
    }
  }

  // Get AI chatbot response
  Future<String> getChatResponse(String userMessage, List<Map<String, String>> chatHistory) async {
    try {
      final prompt = _buildChatPrompt(userMessage, chatHistory);
      
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        return text.trim();
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode}');
      }
    } catch (e) {
      return 'I apologize, but I\'m having trouble processing your request right now. Please try again later.';
    }
  }

  // Analyze emotions from text
  Future<EmotionAnalysisModel> analyzeEmotions(
    String text,
    String userId,
    List<Map<String, dynamic>>? journalHistory,
  ) async {
    try {
      final prompt = _buildEmotionAnalysisPrompt(text, journalHistory);
      
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 512,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final analysisText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        return _parseEmotionAnalysis(analysisText, userId, text);
      } else {
        return _getDefaultEmotionAnalysis(userId);
      }
    } catch (e) {
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
      final prompt = _buildMoodPredictionPrompt(chatHistory, journalEntries);
      
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.4,
            'maxOutputTokens': 256,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictionText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        return _parseMoodPrediction(predictionText);
      } else {
        return _getDefaultMoodPrediction();
      }
    } catch (e) {
      return _getDefaultMoodPrediction();
    }
  }

  // Get personalized wellness recommendations
  Future<List<String>> getWellnessRecommendations(
    String userId,
    EmotionAnalysisModel emotionAnalysis,
    List<String>? pastRecommendations,
  ) async {
    try {
      final prompt = _buildRecommendationsPrompt(emotionAnalysis, pastRecommendations);
      
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.6,
            'maxOutputTokens': 512,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final recommendationsText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        return _parseRecommendations(recommendationsText);
      } else {
        return _getDefaultRecommendations(emotionAnalysis.primaryEmotion);
      }
    } catch (e) {
      return _getDefaultRecommendations(emotionAnalysis.primaryEmotion);
    }
  }

  // Build chat prompt
  String _buildChatPrompt(String userMessage, List<Map<String, String>> chatHistory) {
    final buffer = StringBuffer();
    buffer.writeln('You are a compassionate and empathetic AI mental health support assistant. Your role is to:');
    buffer.writeln('1. Listen actively and provide emotional support');
    buffer.writeln('2. Offer coping strategies and wellness suggestions');
    buffer.writeln('3. Recognize when professional help might be needed');
    buffer.writeln('4. Be non-judgmental, supportive, and encouraging');
    buffer.writeln('5. Provide evidence-based mental health information');
    buffer.writeln('');
    buffer.writeln('IMPORTANT: You are NOT a replacement for professional therapy. For serious mental health concerns, always recommend consulting a licensed therapist.');
    buffer.writeln('');
    
    if (chatHistory.isNotEmpty) {
      buffer.writeln('Previous conversation:');
      for (var entry in chatHistory.take(10)) {
        buffer.writeln('User: ${entry['user']}');
        buffer.writeln('Assistant: ${entry['assistant']}');
        buffer.writeln('');
      }
    }
    
    buffer.writeln('Current user message: $userMessage');
    buffer.writeln('');
    buffer.writeln('Please provide a supportive, empathetic, and helpful response:');
    
    return buffer.toString();
  }

  // Build emotion analysis prompt
  String _buildEmotionAnalysisPrompt(String text, List<Map<String, dynamic>>? journalHistory) {
    final buffer = StringBuffer();
    buffer.writeln('Analyze the emotional state from the following text. Provide a JSON response with:');
    buffer.writeln('1. primaryEmotion: one of (happy, sad, anxious, stressed, angry, neutral, depressed, overwhelmed)');
    buffer.writeln('2. emotionScores: object with scores 0.0-1.0 for: anxiety, stress, sadness, anger, happiness');
    buffer.writeln('3. overallScore: 0.0-1.0 (0.0 = very negative, 1.0 = very positive)');
    buffer.writeln('4. riskLevel: one of (low, medium, high, critical)');
    buffer.writeln('5. suggestedActions: array of 3-5 action suggestions');
    buffer.writeln('');
    
    if (journalHistory != null && journalHistory.isNotEmpty) {
      buffer.writeln('Recent journal entries context:');
      for (var entry in journalHistory.take(5)) {
        buffer.writeln('- ${entry['mood']}: ${entry['content']?.toString().substring(0, entry['content'].toString().length > 100 ? 100 : entry['content'].toString().length)}');
      }
      buffer.writeln('');
    }
    
    buffer.writeln('Text to analyze: $text');
    buffer.writeln('');
    buffer.writeln('Respond ONLY with valid JSON, no additional text:');
    
    return buffer.toString();
  }

  // Build mood prediction prompt
  String _buildMoodPredictionPrompt(
    List<Map<String, dynamic>> chatHistory,
    List<Map<String, dynamic>> journalEntries,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Based on the following user data, predict their current mood and provide a JSON response with:');
    buffer.writeln('1. predictedMood: one of (happy, sad, anxious, stressed, neutral, depressed)');
    buffer.writeln('2. confidence: 0.0-1.0');
    buffer.writeln('3. trend: one of (improving, stable, declining)');
    buffer.writeln('4. riskFactors: array of potential risk factors');
    buffer.writeln('');
    
    if (chatHistory.isNotEmpty) {
      buffer.writeln('Recent chat messages:');
      for (var msg in chatHistory.take(10)) {
        buffer.writeln('- ${msg['text']}');
      }
      buffer.writeln('');
    }
    
    if (journalEntries.isNotEmpty) {
      buffer.writeln('Recent journal entries:');
      for (var entry in journalEntries.take(7)) {
        buffer.writeln('- Mood: ${entry['mood']}, Score: ${entry['moodScore']}');
      }
    }
    
    buffer.writeln('');
    buffer.writeln('Respond ONLY with valid JSON:');
    
    return buffer.toString();
  }

  // Build recommendations prompt
  String _buildRecommendationsPrompt(
    EmotionAnalysisModel emotionAnalysis,
    List<String>? pastRecommendations,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Based on the following emotional analysis, provide 5 personalized wellness recommendations.');
    buffer.writeln('Each recommendation should be a specific, actionable activity.');
    buffer.writeln('');
    buffer.writeln('Emotional State:');
    buffer.writeln('- Primary Emotion: ${emotionAnalysis.primaryEmotion}');
    buffer.writeln('- Overall Score: ${emotionAnalysis.overallScore}');
    buffer.writeln('- Risk Level: ${emotionAnalysis.riskLevel}');
    buffer.writeln('');
    
    if (pastRecommendations != null && pastRecommendations.isNotEmpty) {
      buffer.writeln('Avoid repeating these recent recommendations: ${pastRecommendations.join(", ")}');
      buffer.writeln('');
    }
    
    buffer.writeln('Provide 5 recommendations as a JSON array of strings:');
    
    return buffer.toString();
  }

  // Parse emotion analysis from AI response
  EmotionAnalysisModel _parseEmotionAnalysis(String analysisText, String userId, String originalText) {
    try {
      // Try to extract JSON from the response
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(analysisText);
      if (jsonMatch != null) {
        final jsonData = jsonDecode(jsonMatch.group(0)!);
        return EmotionAnalysisModel(
          userId: userId,
          timestamp: DateTime.now(),
          primaryEmotion: jsonData['primaryEmotion'] ?? 'neutral',
          emotionScores: Map<String, double>.from(jsonData['emotionScores'] ?? {}),
          overallScore: (jsonData['overallScore'] ?? 0.5).toDouble(),
          riskLevel: jsonData['riskLevel'] ?? 'low',
          suggestedActions: List<String>.from(jsonData['suggestedActions'] ?? []),
          analysisText: analysisText,
        );
      }
    } catch (e) {
      // Fall through to default
    }
    
    return _getDefaultEmotionAnalysis(userId);
  }

  // Parse mood prediction
  Map<String, dynamic> _parseMoodPrediction(String predictionText) {
    try {
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(predictionText);
      if (jsonMatch != null) {
        return jsonDecode(jsonMatch.group(0)!);
      }
    } catch (e) {
      // Fall through to default
    }
    
    return _getDefaultMoodPrediction();
  }

  // Parse recommendations
  List<String> _parseRecommendations(String recommendationsText) {
    try {
      final jsonMatch = RegExp(r'\[[^\]]+\]').firstMatch(recommendationsText);
      if (jsonMatch != null) {
        return List<String>.from(jsonDecode(jsonMatch.group(0)!));
      }
    } catch (e) {
      // Fall through to default
    }
    
    return ['Take deep breaths', 'Go for a walk', 'Practice mindfulness', 'Write in your journal', 'Listen to calming music'];
  }

  // Default emotion analysis
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

  // Default mood prediction
  Map<String, dynamic> _getDefaultMoodPrediction() {
    return {
      'predictedMood': 'neutral',
      'confidence': 0.5,
      'trend': 'stable',
      'riskFactors': [],
    };
  }

  // Default recommendations
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
    
    return recommendations[emotion] ?? [
      'Take deep breaths',
      'Go for a walk',
      'Practice mindfulness',
      'Write in your journal',
      'Listen to calming music',
    ];
  }
}

