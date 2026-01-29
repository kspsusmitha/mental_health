/// Pre-configured meditation resources with YouTube video links
/// These are manually curated meditation sessions for the wellness module

class MeditationResource {
  final String id;
  final String title;
  final String category; // Stress, Anxiety, Sleep, Focus, Beginner
  final int duration; // in minutes
  final String description;
  final String youtubeVideoId; // YouTube video ID for embedding

  const MeditationResource({
    required this.id,
    required this.title,
    required this.category,
    required this.duration,
    required this.description,
    required this.youtubeVideoId,
  });

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$youtubeVideoId';
  String get embedUrl => 'https://www.youtube.com/embed/$youtubeVideoId';
}

class MeditationResources {
  static final List<MeditationResource> allMeditations = [
    // Beginner & Short Guided Meditations
    MeditationResource(
      id: 'med_001',
      title: '5-Minute Mindfulness Meditation',
      category: 'Beginner',
      duration: 5,
      description: 'A short and calming mindfulness session perfect for beginners. Learn to focus on the present moment and find peace in just 5 minutes.',
      youtubeVideoId: 'ssss7V1_eyA',
    ),
    MeditationResource(
      id: 'med_002',
      title: '10-Minute Meditation for Beginners',
      category: 'Beginner',
      duration: 10,
      description: 'An easy entry-level mindfulness meditation designed for those new to meditation. Gentle guidance helps you relax and center yourself.',
      youtubeVideoId: 'U9YKY7fdwyg',
    ),
    MeditationResource(
      id: 'med_003',
      title: '10-Minute Stress & Anxiety Release Meditation',
      category: 'Anxiety',
      duration: 10,
      description: 'Release stress and anxiety with this guided meditation. Learn techniques to relax your body and calm your mind.',
      youtubeVideoId: 'H_uc-uQ3Nkc',
    ),
    MeditationResource(
      id: 'med_004',
      title: '10-Minute Mindfulness Calm Meditation',
      category: 'Focus',
      duration: 10,
      description: 'Focus on the present moment with this calming mindfulness meditation. Perfect for finding clarity and inner peace.',
      youtubeVideoId: 'y8KSid0WFwY',
    ),

    // Standard Daily Meditations
    MeditationResource(
      id: 'med_005',
      title: '10-Minute Daily Calm Guided Mindfulness',
      category: 'Focus',
      duration: 10,
      description: 'A daily mindfulness practice to bring calm and clarity to your day. Ideal for morning or evening routine.',
      youtubeVideoId: 'ZToicYcHIOU',
    ),
    MeditationResource(
      id: 'med_006',
      title: '10-Minute Guided Meditation to Clear Your Mind',
      category: 'Focus',
      duration: 10,
      description: 'Clear mental clutter and find mental clarity with this guided meditation. Perfect for when you need to reset and refocus.',
      youtubeVideoId: 'uTN29kj7e-w',
    ),

    // Sleep & Anxiety Focused
    MeditationResource(
      id: 'med_007',
      title: '20-Minute Sleep Meditation – Let Go of Anxiety',
      category: 'Sleep',
      duration: 20,
      description: 'A longer meditation session designed to help you let go of anxiety and prepare for restful sleep. Perfect for bedtime.',
      youtubeVideoId: 'QJreY2d32js',
    ),
    MeditationResource(
      id: 'med_008',
      title: '20-Minute Guided Meditation for Anxiety & Sleep',
      category: 'Sleep',
      duration: 20,
      description: 'Comprehensive guided meditation addressing both anxiety relief and sleep preparation. Ideal for evening relaxation.',
      youtubeVideoId: 'Ar1WRzIsrO4',
    ),
    MeditationResource(
      id: 'med_009',
      title: '10-Minute Meditation for Sleep & Relaxation',
      category: 'Sleep',
      duration: 10,
      description: 'Gentle meditation with rain sounds and calming guidance to help you relax and drift into peaceful sleep.',
      youtubeVideoId: 'bG3AcN-XOrw',
    ),
  ];

  // Get meditations by category
  static List<MeditationResource> getByCategory(String category) {
    if (category.toLowerCase() == 'all') return allMeditations;
    return allMeditations.where((m) => m.category.toLowerCase() == category.toLowerCase()).toList();
  }

  // Get meditations by duration
  static List<MeditationResource> getByDuration(int? duration) {
    if (duration == null) return allMeditations;
    return allMeditations.where((m) => m.duration == duration).toList();
  }

  // Get meditations by category and duration
  static List<MeditationResource> getFiltered({
    String? category,
    int? duration,
  }) {
    var filtered = allMeditations;
    
    if (category != null && category.toLowerCase() != 'all') {
      filtered = filtered.where((m) => m.category.toLowerCase() == category.toLowerCase()).toList();
    }
    
    if (duration != null) {
      filtered = filtered.where((m) => m.duration == duration).toList();
    }
    
    return filtered;
  }

  // Get all unique categories
  static List<String> get categories => allMeditations.map((m) => m.category).toSet().toList()..sort();
}
