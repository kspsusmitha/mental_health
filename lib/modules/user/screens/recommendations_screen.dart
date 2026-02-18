import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/recommendation_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/page_transitions.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';
import 'journal_screen.dart';
import 'wellness_screen.dart';
import 'therapist_matching_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<Recommendation> _recommendations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final recommendationService = Provider.of<RecommendationService>(
        context,
        listen: false,
      );
      final userId = authService.currentUser?.id;
      if (userId != null) {
        final recommendations = await recommendationService
            .getPersonalizedRecommendations(userId);
        setState(() {
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
        return Colors.purpleAccent;
      case RecommendationType.journaling:
        return Colors.orangeAccent;
      case RecommendationType.breathing:
        return Colors.blueAccent;
      case RecommendationType.therapy:
        return Colors.greenAccent;
      case RecommendationType.wellness:
        return Colors.tealAccent;
    }
  }

  Color _getPriorityColor(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.high:
        return Colors.redAccent;
      case RecommendationPriority.medium:
        return Colors.orangeAccent;
      case RecommendationPriority.low:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Personalized Recommendations',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRecommendations,
          ),
        ],
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1519834785169-98be25ec3f84?auto=format&fit=crop&q=80',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _recommendations.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadRecommendations,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                  itemCount: _recommendations.length,
                  itemBuilder: (context, index) {
                    final recommendation = _recommendations[index];
                    return _buildRecommendationCard(recommendation);
                  },
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
          const Icon(Icons.lightbulb_outline, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'No recommendations yet',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start using the app to get personalized suggestions',
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Recommendation recommendation) {
    final icon = _getRecommendationIcon(recommendation.type);
    final color = _getRecommendationColor(recommendation.type);
    final priorityColor = _getPriorityColor(recommendation.priority);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      opacity: 0.1,
      child: InkWell(
        onTap: () => _handleRecommendationTap(recommendation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            recommendation.priority
                                .toString()
                                .split('.')
                                .last
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
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
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recommendation.action,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w500,
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
}
