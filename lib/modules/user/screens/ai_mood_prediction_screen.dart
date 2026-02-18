import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/mood_prediction_service.dart';
import '../../../services/recommendation_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/page_transitions.dart';
import 'wellness_screen.dart';
import 'journal_screen.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';
import 'therapist_matching_screen.dart';

class AIMoodPredictionScreen extends StatefulWidget {
  const AIMoodPredictionScreen({super.key});

  @override
  State<AIMoodPredictionScreen> createState() => _AIMoodPredictionScreenState();
}

class _AIMoodPredictionScreenState extends State<AIMoodPredictionScreen> {
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
      final predictionService = Provider.of<MoodPredictionService>(
        context,
        listen: false,
      );
      final recommendationService = Provider.of<RecommendationService>(
        context,
        listen: false,
      );

      final userId = authService.currentUser?.id;
      if (userId != null) {
        final result = await predictionService.predictMoodPatterns(userId);
        // Get personalized recommendations based on predicted mood
        final recommendations = await recommendationService
            .getPersonalizedRecommendations(userId);

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'AI Mood Prediction',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrediction,
            color: Colors.white,
          ),
        ],
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1518531933037-8845d583afa2?auto=format&fit=crop&q=80',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _predictionResult == null
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadPrediction,
                color: Colors.white,
                backgroundColor: Colors.white24,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights_outlined, size: 64, color: Colors.white60),
          const SizedBox(height: 16),
          const Text(
            'No mood data available',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start journaling to get mood predictions',
            style: TextStyle(color: Colors.white54, fontSize: 14),
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

    return GlassContainer(
      opacity: 0.2,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(
              moodIcons[mood] ?? Icons.sentiment_neutral,
              size: 64,
              color: moodColors[mood] ?? Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              'Predicted Mood',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              moodLabels[mood] ?? mood,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: moodColors[mood] ?? Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Confidence: ',
                  style: TextStyle(color: Colors.white60),
                ),
                Text(
                  '${(confidence * 100).toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: confidence > 0.7
                        ? Colors.lightGreen
                        : Colors.orangeAccent,
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
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._predictionResult!.patterns.map(
          (pattern) => GlassContainer(
            margin: const EdgeInsets.only(bottom: 12),
            opacity: 0.1,
            child: ListTile(
              leading: Icon(
                pattern.impact == 'High'
                    ? Icons.warning
                    : pattern.impact == 'Medium'
                    ? Icons.info
                    : Icons.check_circle,
                color: pattern.impact == 'High'
                    ? Colors.redAccent
                    : pattern.impact == 'Medium'
                    ? Colors.orangeAccent
                    : Colors.greenAccent,
              ),
              title: Text(
                pattern.type,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                pattern.description,
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: Chip(
                label: Text(pattern.impact),
                backgroundColor: pattern.impact == 'High'
                    ? Colors.red.withOpacity(0.2)
                    : pattern.impact == 'Medium'
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
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
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _predictionResult!.stressTriggers
              .map(
                (trigger) => Chip(
                  label: Text(trigger),
                  backgroundColor: Colors.red.withOpacity(0.1),
                  avatar: const Icon(
                    Icons.warning,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
              )
              .toList(),
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Based on your identified patterns and stress triggers',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 16),
        ..._predictionResult!.recommendations.map(
          (rec) => GlassContainer(
            margin: const EdgeInsets.only(bottom: 12),
            opacity: 0.1,
            child: ListTile(
              leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
              title: Text(rec, style: const TextStyle(color: Colors.white)),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalizedRecommendationsSection() {
    return GlassContainer(
      opacity: 0.2,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.recommend, color: Colors.amber[400], size: 28),
                const SizedBox(width: 8),
                Text(
                  'Personalized Recommendations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tailored suggestions based on your predicted mood and history',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ..._recommendations
                .take(5)
                .map(
                  (recommendation) => _buildRecommendationCard(recommendation),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(Recommendation recommendation) {
    final icon = _getRecommendationIcon(recommendation.type);
    final color = _getRecommendationColor(recommendation.type);
    final priorityColor = _getPriorityColor(recommendation.priority);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      opacity: 0.15,
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
                  color: color.withOpacity(0.2),
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
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            recommendation.priority
                                .toString()
                                .split('.')
                                .last
                                .toUpperCase(),
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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.white54,
              ),
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
        Navigator.push(context, createAnimatedRoute(const JournalScreen()));
        break;
      case RecommendationType.wellness:
      case RecommendationType.meditation:
      case RecommendationType.breathing:
        Navigator.push(context, createAnimatedRoute(const WellnessScreen()));
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
