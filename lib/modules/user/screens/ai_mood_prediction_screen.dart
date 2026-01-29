import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/mood_prediction_service.dart';
import '../../../services/recommendation_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/page_transitions.dart';
import 'wellness_screen.dart';
import 'journal_screen.dart';
import 'therapist_matching_screen.dart';

class AIMoodPredictionScreen extends StatefulWidget {
  const AIMoodPredictionScreen({super.key});

  @override
  State<AIMoodPredictionScreen> createState() => _AIMoodPredictionScreenState();
}

class _AIMoodPredictionScreenState extends State<AIMoodPredictionScreen> {
  final MoodPredictionService _predictionService = MoodPredictionService();
  final RecommendationService _recommendationService = RecommendationService();
  MoodPredictionResult? _predictionResult;
  List<Recommendation> _recommendations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrediction();
  }

  Future<void> _loadPrediction() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId != null) {
        final result = await _predictionService.predictMoodPatterns(userId);
        // Get personalized recommendations based on predicted mood
        final recommendations = await _recommendationService.getPersonalizedRecommendations(userId);
        
        setState(() {
          _predictionResult = result;
          _recommendations = recommendations;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Mood Prediction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrediction,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _predictionResult == null
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPrediction,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPredictionCard(),
                        const SizedBox(height: 24),
                        _buildPatternsSection(),
                        const SizedBox(height: 24),
                        _buildStressTriggersSection(),
                        const SizedBox(height: 24),
                        _buildPredictionRecommendationsSection(),
                        if (_recommendations.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildPersonalizedRecommendationsSection(),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No mood data available',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Start journaling to get mood predictions',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionCard() {
    final mood = _predictionResult!.predictedMood;
    final confidence = _predictionResult!.confidence;
    
    final moodIcons = {
      'depressed': Icons.sentiment_very_dissatisfied,
      'stressed': Icons.sentiment_dissatisfied,
      'anxious': Icons.sentiment_very_dissatisfied,
      'neutral': Icons.sentiment_neutral,
      'happy': Icons.sentiment_satisfied,
      'very_happy': Icons.sentiment_very_satisfied,
    };

    final moodColors = {
      'depressed': Colors.purple,
      'stressed': Colors.red,
      'anxious': Colors.orange,
      'neutral': Colors.grey,
      'happy': Colors.green,
      'very_happy': Colors.lightGreen,
    };

    final moodLabels = {
      'depressed': 'Depressed',
      'stressed': 'Stressed',
      'anxious': 'Anxious',
      'neutral': 'Neutral',
      'happy': 'Happy',
      'very_happy': 'Very Happy',
    };

    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              moodColors[mood]?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.1),
              moodColors[mood]?.withOpacity(0.05) ?? Colors.grey.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              moodIcons[mood] ?? Icons.sentiment_neutral,
              size: 64,
              color: moodColors[mood] ?? Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Predicted Mood',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              moodLabels[mood] ?? mood,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: moodColors[mood] ?? Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Confidence: ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  '${(confidence * 100).toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: confidence > 0.7 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternsSection() {
    if (_predictionResult!.patterns.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Identified Patterns',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ..._predictionResult!.patterns.map((pattern) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  pattern.impact == 'High'
                      ? Icons.warning
                      : pattern.impact == 'Medium'
                          ? Icons.info
                          : Icons.check_circle,
                  color: pattern.impact == 'High'
                      ? Colors.red
                      : pattern.impact == 'Medium'
                          ? Colors.orange
                          : Colors.green,
                ),
                title: Text(pattern.type),
                subtitle: Text(pattern.description),
                trailing: Chip(
                  label: Text(pattern.impact),
                  backgroundColor: pattern.impact == 'High'
                      ? Colors.red.withOpacity(0.1)
                      : pattern.impact == 'Medium'
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildStressTriggersSection() {
    if (_predictionResult!.stressTriggers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Common Stress Triggers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _predictionResult!.stressTriggers.map((trigger) => Chip(
                label: Text(trigger),
                backgroundColor: Colors.red.withOpacity(0.1),
                avatar: const Icon(Icons.warning, size: 18, color: Colors.red),
              )).toList(),
        ),
      ],
    );
  }

  Widget _buildPredictionRecommendationsSection() {
    if (_predictionResult!.recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insights, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Pattern-Based Recommendations',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Based on your identified patterns and stress triggers',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 16),
        ..._predictionResult!.recommendations.map((rec) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                title: Text(rec),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
            )),
      ],
    );
  }

  Widget _buildPersonalizedRecommendationsSection() {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber[50]!,
              Colors.orange[50]!,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.recommend, color: Colors.amber[700], size: 28),
                const SizedBox(width: 8),
                Text(
                  'Personalized Recommendations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tailored suggestions based on your predicted mood and history',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 16),
            ..._recommendations.take(5).map((recommendation) => _buildRecommendationCard(recommendation)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(Recommendation recommendation) {
    final icon = _getRecommendationIcon(recommendation.type);
    final color = _getRecommendationColor(recommendation.type);
    final priorityColor = _getPriorityColor(recommendation.priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: recommendation.priority == RecommendationPriority.high ? 3 : 1,
      child: InkWell(
        onTap: () => _handleRecommendationTap(recommendation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recommendation.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            recommendation.priority.toString().split('.').last.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recommendation.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRecommendationIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.meditation:
        return Icons.self_improvement;
      case RecommendationType.journaling:
        return Icons.book;
      case RecommendationType.breathing:
        return Icons.air;
      case RecommendationType.therapy:
        return Icons.medical_services;
      case RecommendationType.wellness:
        return Icons.spa;
    }
  }

  Color _getRecommendationColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.meditation:
        return Colors.purple;
      case RecommendationType.journaling:
        return Colors.orange;
      case RecommendationType.breathing:
        return Colors.blue;
      case RecommendationType.therapy:
        return Colors.green;
      case RecommendationType.wellness:
        return Colors.teal;
    }
  }

  Color _getPriorityColor(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.high:
        return Colors.red;
      case RecommendationPriority.medium:
        return Colors.orange;
      case RecommendationPriority.low:
        return Colors.green;
    }
  }

  void _handleRecommendationTap(Recommendation recommendation) {
    switch (recommendation.type) {
      case RecommendationType.journaling:
        Navigator.push(
          context,
          createAnimatedRoute(const JournalScreen()),
        );
        break;
      case RecommendationType.wellness:
      case RecommendationType.meditation:
      case RecommendationType.breathing:
        Navigator.push(
          context,
          createAnimatedRoute(const WellnessScreen()),
        );
        break;
      case RecommendationType.therapy:
        Navigator.push(
          context,
          createAnimatedRoute(const TherapistMatchingScreen()),
        );
        break;
    }
  }
}
