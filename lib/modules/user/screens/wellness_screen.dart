import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/recommendation_service.dart';
import '../../../models/wellness_resource_model.dart';
import '../../../data/meditation_resources.dart';
import '../../../utils/page_transitions.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';
import 'mood_tracking_screen.dart';
import 'journal_screen.dart';
import 'therapist_matching_screen.dart';
import 'meditation_player_screen.dart';
import 'package:carousel_slider/carousel_slider.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<WellnessResourceModel> _allResources = [];
  List<Recommendation> _recommendations = [];
  String? _dailyTip;
  WellnessResourceModel? _lastSession;
  Set<String> _favorites = {};
  Map<String, int> _sessionCounts = {}; // resourceId -> count
  bool _isLoading = true;
  final RecommendationService _recommendationService = RecommendationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _loadResources(),
      _loadRecommendations(),
      _loadDailyTip(),
      _loadLastSession(),
      _loadFavorites(),
      _loadSessionCounts(),
    ]);
  }

  Future<void> _loadResources() async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );

      dynamic convertValue(dynamic value) {
        if (value is Map) {
          return Map<String, dynamic>.from(
            value.map(
              (key, val) => MapEntry(key.toString(), convertValue(val)),
            ),
          );
        } else if (value is List) {
          return List<dynamic>.from(value.map((item) => convertValue(item)));
        }
        return value;
      }

      final resourcesData = await dbService.readList('wellness_resources');
      final List<WellnessResourceModel> resources = [];

      for (var data in resourcesData) {
        try {
          final Map<String, dynamic> resourceMap =
              convertValue(data) as Map<String, dynamic>;
          final resource = WellnessResourceModel.fromMap(resourceMap);
          if (resource.isApproved) {
            resources.add(resource);
          }
        } catch (e) {
          continue;
        }
      }

      setState(() {
        _allResources = resources;
        if (_isLoading) {
          _isLoading = false;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId != null) {
        final recommendations = await _recommendationService
            .getPersonalizedRecommendations(userId);
        setState(() => _recommendations = recommendations);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadDailyTip() async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final tipsData = await dbService.readList('wellness_tips');
      if (tipsData.isNotEmpty) {
        final tipIndex = DateTime.now().day % tipsData.length;
        if (tipIndex < tipsData.length) {
          final tip = tipsData[tipIndex];
          setState(
            () => _dailyTip =
                tip['text'] ??
                'Take a moment to breathe deeply and center yourself.',
          );
        }
      } else {
        setState(
          () => _dailyTip =
              'Take a moment to breathe deeply and center yourself.',
        );
      }
    } catch (e) {
      setState(
        () =>
            _dailyTip = 'Take a moment to breathe deeply and center yourself.',
      );
    }
  }

  Future<void> _loadLastSession() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final lastSessionData = await dbService.readData(
        '$userNodePath/$userId/last_session',
      );

      if (lastSessionData != null && lastSessionData['resourceId'] != null) {
        final resourceId = lastSessionData['resourceId'].toString();
        final resource = _allResources.firstWhere(
          (r) => r.id == resourceId,
          orElse: () => _allResources.first,
        );
        setState(() => _lastSession = resource);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final favoritesData = await dbService.readData(
        '$userNodePath/$userId/favorites',
      );

      if (favoritesData != null && favoritesData['wellness'] != null) {
        final List<dynamic> favoritesList = favoritesData['wellness'] is List
            ? favoritesData['wellness']
            : [];
        setState(
          () => _favorites = favoritesList.map((e) => e.toString()).toSet(),
        );
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadSessionCounts() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final sessionsData = await dbService.readData(
        '$userNodePath/$userId/session_counts',
      );

      if (sessionsData != null) {
        final Map<String, dynamic> counts = Map<String, dynamic>.from(
          sessionsData,
        );
        setState(() {
          _sessionCounts = counts.map(
            (key, value) => MapEntry(key, value as int),
          );
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _toggleFavorite(String resourceId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      setState(() {
        if (_favorites.contains(resourceId)) {
          _favorites.remove(resourceId);
        } else {
          _favorites.add(resourceId);
        }
      });

      await dbService.writeData('$userNodePath/$userId/favorites', {
        'wellness': _favorites.toList(),
      });
    } catch (e) {
      setState(() {
        if (_favorites.contains(resourceId)) {
          _favorites.remove(resourceId);
        } else {
          _favorites.add(resourceId);
        }
      });
    }
  }

  Future<void> _trackSession(String resourceId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      setState(() {
        _sessionCounts[resourceId] = (_sessionCounts[resourceId] ?? 0) + 1;
      });

      await dbService.writeData(
        '$userNodePath/$userId/session_counts',
        _sessionCounts,
      );

      final resource = _allResources.firstWhere((r) => r.id == resourceId);
      await dbService.writeData('$userNodePath/$userId/last_session', {
        'resourceId': resourceId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'title': resource.title,
      });
      setState(() => _lastSession = resource);
    } catch (e) {
      // Handle error silently
    }
  }

  List<WellnessResourceModel> _getFilteredResources(
    ResourceType? type, {
    String? category,
    int? duration,
  }) {
    var filtered = _allResources;

    if (type != null) {
      filtered = filtered.where((r) => r.type == type).toList();
    }

    if (category != null) {
      filtered = filtered
          .where((r) => r.tags.contains(category.toLowerCase()))
          .toList();
    }

    if (duration != null) {
      filtered = filtered.where((r) => r.duration == duration).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Wellness', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'All'),
            Tab(icon: Icon(Icons.self_improvement), text: 'Meditation'),
            Tab(icon: Icon(Icons.audiotrack), text: 'Audio'),
          ],
        ),
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1544367563-12123d8965cd?q=80&w=2070&auto=format&fit=crop',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildAllTab(),
                  _buildMeditationTab(),
                  _buildAudioTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildAllTab() {
    return RefreshIndicator(
      onRefresh: _initializeData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMoodCheckIn(),
            const SizedBox(height: 16),
            if (_recommendations.isNotEmpty) ...[
              _buildAIRecommendationCard(),
              const SizedBox(height: 16),
            ],
            if (_lastSession != null) ...[
              _buildContinueLastSession(),
              const SizedBox(height: 16),
            ],
            _buildDailyTip(),
            const SizedBox(height: 16),
            _buildNeedHelpNow(),
            const SizedBox(height: 16),
            _buildQuickResources(),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodCheckIn() {
    final moods = [
      {'emoji': '😊', 'label': 'Happy', 'value': 'happy'},
      {'emoji': '😌', 'label': 'Calm', 'value': 'calm'},
      {'emoji': '😰', 'label': 'Stressed', 'value': 'stressed'},
      {'emoji': '😢', 'label': 'Sad', 'value': 'sad'},
      {'emoji': '😟', 'label': 'Anxious', 'value': 'anxious'},
    ];

    return GlassContainer(
      opacity: 0.1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mood, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Daily Mood Check-in',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'How are you feeling today?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: moods.map((mood) {
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      createAnimatedRoute(const MoodTrackingScreen()),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          mood['emoji']!,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mood['label']!,
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIRecommendationCard() {
    final topRecommendation = _recommendations.first;

    return GlassContainer(
      opacity: 0.2, // Slightly more opaque for emphasis
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Recommendation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              topRecommendation.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              topRecommendation.description,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (topRecommendation.type == RecommendationType.therapy) {
                  Navigator.push(
                    context,
                    createAnimatedRoute(const TherapistMatchingScreen()),
                  );
                } else if (topRecommendation.type ==
                    RecommendationType.journaling) {
                  Navigator.push(
                    context,
                    createAnimatedRoute(const JournalScreen()),
                  );
                } else {
                  if (topRecommendation.type == RecommendationType.meditation) {
                    _tabController.animateTo(1);
                  } else {
                    _tabController.animateTo(2);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(topRecommendation.action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueLastSession() {
    return GlassContainer(
      opacity: 0.1,
      child: InkWell(
        onTap: () => _playResource(_lastSession!),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.purpleAccent,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Last Session',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastSession!.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTip() {
    return GlassContainer(
      opacity: 0.1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.amberAccent,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily Wellness Tip',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _dailyTip ??
                  'Take a moment to breathe deeply and center yourself.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedHelpNow() {
    return GlassContainer(
      opacity: 0.1,
      child: InkWell(
        onTap: () => _showHelpOptions(),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.withOpacity(0.4),
                Colors.red.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emergency, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                'Need Help Now',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickResources() {
    final quickResources = _allResources.take(5).toList();
    if (quickResources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Featured Resources',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text(
                'View All',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CarouselSlider(
          options: CarouselOptions(
            height: 200,
            enlargeCenterPage: true,
            autoPlay: true,
            aspectRatio: 16 / 9,
            autoPlayCurve: Curves.fastOutSlowIn,
            enableInfiniteScroll: true,
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            viewportFraction: 0.8,
          ),
          items: quickResources.map((resource) {
            return Builder(
              builder: (BuildContext context) {
                return GestureDetector(
                  onTap: () => _playResource(resource),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    margin: const EdgeInsets.symmetric(horizontal: 5.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: NetworkImage(
                          resource.thumbnailUrl ??
                              'https://images.unsplash.com/photo-1506126613408-eca07ce68773?q=80&w=2062&auto=format&fit=crop',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              resource.type == ResourceType.meditation
                                  ? 'Meditation'
                                  : 'Audio',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            resource.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${resource.duration} mins',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMeditationTab() {
    String? selectedCategory;
    int? selectedDuration;

    return StatefulBuilder(
      builder: (context, setState) {
        final meditations = MeditationResources.getFiltered(
          category: selectedCategory,
          duration: selectedDuration,
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 120, 16, 8),
              child: GlassContainer(
                opacity: 0.1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Category:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip(
                                  'All',
                                  selectedCategory == null,
                                  () {
                                    setState(() => selectedCategory = null);
                                  },
                                ),
                                ...MeditationResources.categories.map(
                                  (cat) => _buildFilterChip(
                                    cat,
                                    selectedCategory == cat.toLowerCase(),
                                    () {
                                      setState(
                                        () => selectedCategory = cat
                                            .toLowerCase(),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Duration:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip(
                                  'All',
                                  selectedDuration == null,
                                  () {
                                    setState(() => selectedDuration = null);
                                  },
                                ),
                                _buildFilterChip(
                                  '5 min',
                                  selectedDuration == 5,
                                  () {
                                    setState(() => selectedDuration = 5);
                                  },
                                ),
                                _buildFilterChip(
                                  '10 min',
                                  selectedDuration == 10,
                                  () {
                                    setState(() => selectedDuration = 10);
                                  },
                                ),
                                _buildFilterChip(
                                  '20 min',
                                  selectedDuration == 20,
                                  () {
                                    setState(() => selectedDuration = 20);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: _buildMeditationList(meditations)),
          ],
        );
      },
    );
  }

  Widget _buildMeditationList(List<MeditationResource> meditations) {
    if (meditations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.self_improvement_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              'No meditations found',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadResources,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: meditations.length,
        itemBuilder: (context, index) =>
            _buildMeditationCard(meditations[index]),
      ),
    );
  }

  Widget _buildMeditationCard(MeditationResource meditation) {
    final sessionCount = _sessionCounts[meditation.id] ?? 0;
    final isFavorite = _favorites.contains(meditation.id);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      opacity: 0.1,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            createAnimatedRoute(MeditationPlayerScreen(meditation: meditation)),
          ).then((_) {
            _trackSession(meditation.id);
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.self_improvement,
                      color: Colors.purpleAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meditation.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meditation.description,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.redAccent : Colors.white70,
                    ),
                    onPressed: () => _toggleFavorite(meditation.id),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      meditation.category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    '${meditation.duration} min',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  if (sessionCount > 0) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$sessionCount sessions',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioTab() {
    final isNight = DateTime.now().hour >= 20 || DateTime.now().hour < 6;
    final audioResources = _getFilteredResources(ResourceType.audio);
    final sleepAudios = audioResources
        .where((r) => r.tags.contains('sleep'))
        .toList();

    return Column(
      children: [
        if (isNight && sleepAudios.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 0),
            child: GlassContainer(
              opacity: 0.2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.nightlight_round,
                      color: Colors.indigoAccent,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sleep Audio Suggested',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            sleepAudios.first.title,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.play_arrow, color: Colors.white),
                      onPressed: () => _playResource(sleepAudios.first),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        // Audio List
        Expanded(
          child: Padding(
            padding: isNight && sleepAudios.isNotEmpty
                ? EdgeInsets.zero
                : const EdgeInsets.only(top: 120),
            child: _buildResourcesList(audioResources, showAutoStop: true),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.white.withOpacity(0.3),
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white10,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? Colors.white : Colors.white24),
      ),
    );
  }

  Widget _buildResourcesList(
    List<WellnessResourceModel> resources, {
    bool showCategory = false,
    bool showAutoStop = false,
  }) {
    if (resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.spa_outlined, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              'No resources available',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadResources,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: resources.length,
        itemBuilder: (context, index) => _buildResourceCard(
          resources[index],
          showFavorite: true,
          showCategory: showCategory,
          showAutoStop: showAutoStop,
        ),
      ),
    );
  }

  Widget _buildResourceCard(
    WellnessResourceModel resource, {
    bool showFavorite = false,
    bool showCategory = false,
    bool showAutoStop = false,
  }) {
    final isFavorite = _favorites.contains(resource.id);
    final sessionCount = _sessionCounts[resource.id] ?? 0;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      opacity: 0.1,
      child: InkWell(
        onTap: () => _playResource(resource),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      resource.type == ResourceType.meditation
                          ? Icons.self_improvement
                          : Icons.audiotrack,
                      color: Colors.purpleAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resource.description,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (showFavorite)
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.redAccent : Colors.white70,
                      ),
                      onPressed: () => _toggleFavorite(resource.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (resource.duration > 0) ...[
                    Icon(Icons.access_time, size: 14, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      '${resource.duration} min',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (showCategory && resource.tags.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        resource.tags.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (sessionCount > 0) ...[
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$sessionCount sessions',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                  ],
                ],
              ),
              if (showAutoStop)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Auto-stop available',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _playResource(WellnessResourceModel resource) {
    _trackSession(resource.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing: ${resource.title}'),
        action: SnackBarAction(label: 'Stop', onPressed: () {}),
      ),
    );
  }

  void _showHelpOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GlassContainer(
        opacity: 0.9,
        // Using high opacity for readability in modal
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Need Help Now?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.air, color: Colors.blueAccent),
                ),
                title: const Text(
                  'Breathing Exercise',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Quick 5-minute breathing exercise',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to breathing exercise
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.people, color: Colors.purpleAccent),
                ),
                title: const Text(
                  'Find a Therapist',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Connect with a professional',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    createAnimatedRoute(const TherapistMatchingScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
