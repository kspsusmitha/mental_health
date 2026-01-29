import '../models/journal_entry_model.dart';
import '../models/wellness_resource_model.dart';
import 'realtime_database_service.dart';
import 'auth_service.dart';

class RecommendationService {
  final RealtimeDatabaseService _database = RealtimeDatabaseService();

  /// Get personalized recommendations for user
  Future<List<Recommendation>> getPersonalizedRecommendations(String userId) async {
    try {
      final authService = AuthService();
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) {
        return _getDefaultRecommendations();
      }

      // Load recent journal entries
      final entriesData = await _database.readList('$userNodePath/$userId/journal_entries');
      final entries = entriesData
          .map((data) => JournalEntryModel.fromMap(data))
          .toList();

      // Load wellness resources
      final resourcesData = await _database.readList('wellness_resources');
      final resources = resourcesData
          .map((data) => WellnessResourceModel.fromMap(data))
          .where((r) => r.isApproved)
          .toList();

      // Analyze user's current state
      final currentMood = entries.isNotEmpty ? entries.first.moodScore : 0.5;
      final recentMood = entries.length >= 7
          ? entries.take(7).map((e) => e.moodScore).reduce((a, b) => a + b) / 7
          : currentMood;

      final recommendations = <Recommendation>[];

      // Mood-based recommendations
      if (currentMood < 0.4 || recentMood < 0.4) {
        // User is stressed/depressed
        recommendations.add(Recommendation(
          type: RecommendationType.wellness,
          title: 'Guided Meditation & Breathing',
          description: 'Try meditation and breathing exercises to calm your mind',
          priority: RecommendationPriority.high,
          action: 'Browse Wellness',
        ));

        recommendations.add(Recommendation(
          type: RecommendationType.therapy,
          title: 'Speak with a Therapist',
          description: 'Consider booking a session with a professional',
          priority: RecommendationPriority.medium,
          action: 'Find Therapist',
        ));
      } else if (currentMood < 0.6) {
        // User is neutral/anxious
        recommendations.add(Recommendation(
          type: RecommendationType.journaling,
          title: 'Journal Your Thoughts',
          description: 'Writing can help process your feelings',
          priority: RecommendationPriority.medium,
          action: 'Open Journal',
        ));

        recommendations.add(Recommendation(
          type: RecommendationType.wellness,
          title: 'Mindfulness & Wellness',
          description: 'Try meditation or wellness content to center yourself',
          priority: RecommendationPriority.medium,
          action: 'Browse Wellness',
        ));
      } else {
        // User is doing well
        recommendations.add(Recommendation(
          type: RecommendationType.journaling,
          title: 'Maintain Your Journal',
          description: 'Keep tracking your positive progress',
          priority: RecommendationPriority.low,
          action: 'Open Journal',
        ));

        recommendations.add(Recommendation(
          type: RecommendationType.wellness,
          title: 'Explore Wellness Content',
          description: 'Discover meditation, breathing exercises, and wellness resources',
          priority: RecommendationPriority.low,
          action: 'Browse Wellness',
        ));
      }

      // Check for stress triggers
      final stressTriggers = <String>[];
      for (final entry in entries.take(10)) {
        if (entry.stressTriggers != null) {
          stressTriggers.addAll(entry.stressTriggers!);
        }
      }

      if (stressTriggers.isNotEmpty) {
        final commonTrigger = stressTriggers.first;
        recommendations.add(Recommendation(
          type: RecommendationType.therapy,
          title: 'Manage ${commonTrigger}',
          description: 'Consider strategies to handle this stress trigger',
          priority: RecommendationPriority.medium,
          action: 'Get Help',
        ));
      }

      // Check journal consistency
      final daysSinceLastEntry = entries.isNotEmpty
          ? DateTime.now().difference(entries.first.date).inDays
          : 999;

      if (daysSinceLastEntry > 3) {
        recommendations.add(Recommendation(
          type: RecommendationType.journaling,
          title: 'Catch Up on Journaling',
          description: 'It\'s been $daysSinceLastEntry days since your last entry',
          priority: RecommendationPriority.medium,
          action: 'Open Journal',
        ));
      }

      // Add specific wellness resources
      if (resources.isNotEmpty) {
        final relevantResources = _getRelevantResources(resources, currentMood);
        for (final resource in relevantResources.take(2)) {
          recommendations.add(Recommendation(
            type: RecommendationType.wellness,
            title: resource.title,
            description: resource.description,
            priority: RecommendationPriority.low,
            action: 'View Resource',
            resourceId: resource.id,
          ));
        }
      }

      // Ensure we have at least some recommendations
      if (recommendations.isEmpty) {
        return _getDefaultRecommendations();
      }

      // Sort by priority
      recommendations.sort((a, b) {
        final priorityOrder = {
          RecommendationPriority.high: 3,
          RecommendationPriority.medium: 2,
          RecommendationPriority.low: 1,
        };
        return priorityOrder[b.priority]!.compareTo(priorityOrder[a.priority]!);
      });

      return recommendations.take(6).toList();
    } catch (e) {
      return _getDefaultRecommendations();
    }
  }

  List<WellnessResourceModel> _getRelevantResources(
    List<WellnessResourceModel> resources,
    double moodScore,
  ) {
    if (moodScore < 0.4) {
      // Prefer meditation and breathing exercises
      return resources
          .where((r) => r.type.toString().contains('meditation') ||
              r.type.toString().contains('breathing'))
          .toList();
    }
    return resources;
  }

  List<Recommendation> _getDefaultRecommendations() {
    return [
      Recommendation(
        type: RecommendationType.journaling,
        title: 'Start Journaling',
        description: 'Begin tracking your thoughts and feelings',
        priority: RecommendationPriority.medium,
        action: 'Open Journal',
      ),
      Recommendation(
        type: RecommendationType.wellness,
        title: 'Explore Wellness Content',
        description: 'Discover meditation, breathing exercises, and wellness resources',
        priority: RecommendationPriority.medium,
        action: 'Browse Wellness',
      ),
    ];
  }
}

class Recommendation {
  final RecommendationType type;
  final String title;
  final String description;
  final RecommendationPriority priority;
  final String action;
  final String? resourceId;

  Recommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.action,
    this.resourceId,
  });
}

enum RecommendationType {
  meditation,
  journaling,
  breathing,
  therapy,
  wellness,
}

enum RecommendationPriority {
  high,
  medium,
  low,
}
