import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/recommendation_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/page_transitions.dart';
import 'journal_screen.dart';
import 'wellness_screen.dart';
import 'therapist_matching_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final RecommendationService _recommendationService = RecommendationService();
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
      final userId = authService.currentUser?.id;
      if (userId != null) {
        final recommendations = await _recommendationService.getPersonalizedRecommendations(userId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalized Recommendations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecommendations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recommendations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRecommendations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _recommendations.length,
                    itemBuilder: (context, index) {
                      final recommendation = _recommendations[index];
                      return _buildRecommendationCard(recommendation);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No recommendations yet',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Start using the app to get personalized suggestions',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: recommendation.priority == RecommendationPriority.high ? 4 : 2,
      child: InkWell(
        onTap: () => _handleRecommendationTap(recommendation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            recommendation.priority.toString().split('.').last.toUpperCase(),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
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
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
