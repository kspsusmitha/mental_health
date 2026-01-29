import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/recommendation_service.dart';
import '../../../models/wellness_resource_model.dart';
import '../../../data/meditation_resources.dart';
import '../../../utils/page_transitions.dart';
import 'mood_tracking_screen.dart';
import 'journal_screen.dart';
import 'therapist_matching_screen.dart';
import 'meditation_player_screen.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> with SingleTickerProviderStateMixin {
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
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      
      // Convert LinkedMap to Map<String, dynamic>
      dynamic convertValue(dynamic value) {
        if (value is Map) {
          return Map<String, dynamic>.from(
            value.map((key, val) => MapEntry(
              key.toString(),
              convertValue(val),
            )),
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
          final Map<String, dynamic> resourceMap = convertValue(data) as Map<String, dynamic>;
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
        final recommendations = await _recommendationService.getPersonalizedRecommendations(userId);
        setState(() => _recommendations = recommendations);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadDailyTip() async {
    // Load daily wellness tip from database or use default
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final tipsData = await dbService.readList('wellness_tips');
      if (tipsData.isNotEmpty) {
        final tipIndex = DateTime.now().day % tipsData.length;
        if (tipIndex < tipsData.length) {
          final tip = tipsData[tipIndex];
          setState(() => _dailyTip = tip['text'] ?? 'Take a moment to breathe deeply and center yourself.');
        }
      } else {
        setState(() => _dailyTip = 'Take a moment to breathe deeply and center yourself.');
      }
    } catch (e) {
      setState(() => _dailyTip = 'Take a moment to breathe deeply and center yourself.');
    }
  }

  Future<void> _loadLastSession() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final username = authService.currentUser?.name.toLowerCase().replaceAll(' ', '_');
      final lastSessionData = await dbService.readData('$userNodePath/$username/last_session');
      
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
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final username = authService.currentUser?.name.toLowerCase().replaceAll(' ', '_');
      final favoritesData = await dbService.readData('$userNodePath/$username/favorites');
      
      if (favoritesData != null && favoritesData['wellness'] != null) {
        final List<dynamic> favoritesList = favoritesData['wellness'] is List
            ? favoritesData['wellness']
            : [];
        setState(() => _favorites = favoritesList.map((e) => e.toString()).toSet());
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadSessionCounts() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final username = authService.currentUser?.name.toLowerCase().replaceAll(' ', '_');
      final sessionsData = await dbService.readData('$userNodePath/$username/session_counts');
      
      if (sessionsData != null) {
        final Map<String, dynamic> counts = Map<String, dynamic>.from(sessionsData);
        setState(() {
          _sessionCounts = counts.map((key, value) => MapEntry(key, value as int));
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _toggleFavorite(String resourceId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final username = authService.currentUser?.name.toLowerCase().replaceAll(' ', '_');
      
      setState(() {
        if (_favorites.contains(resourceId)) {
          _favorites.remove(resourceId);
        } else {
          _favorites.add(resourceId);
        }
      });

      await dbService.writeData(
        '$userNodePath/$username/favorites',
        {'wellness': _favorites.toList()},
      );
    } catch (e) {
      // Revert on error
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
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final username = authService.currentUser?.name.toLowerCase().replaceAll(' ', '_');
      
      setState(() {
        _sessionCounts[resourceId] = (_sessionCounts[resourceId] ?? 0) + 1;
      });

      await dbService.writeData(
        '$userNodePath/$username/session_counts',
        _sessionCounts,
      );

      // Update last session
      final resource = _allResources.firstWhere((r) => r.id == resourceId);
      await dbService.writeData(
        '$userNodePath/$username/last_session',
        {
          'resourceId': resourceId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'title': resource.title,
        },
      );
      setState(() => _lastSession = resource);
    } catch (e) {
      // Handle error silently
    }
  }

  List<WellnessResourceModel> _getFilteredResources(ResourceType? type, {String? category, int? duration}) {
    var filtered = _allResources;
    
    if (type != null) {
      filtered = filtered.where((r) => r.type == type).toList();
    }
    
    if (category != null) {
      filtered = filtered.where((r) => r.tags.contains(category.toLowerCase())).toList();
    }
    
    if (duration != null) {
      filtered = filtered.where((r) => r.duration == duration).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellness'),
        backgroundColor: Colors.purple[50],
        foregroundColor: Colors.purple[900],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.purple[900],
          unselectedLabelColor: Colors.purple[400],
          indicatorColor: Colors.purple[900],
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'All'),
            Tab(icon: Icon(Icons.self_improvement), text: 'Meditation'),
            Tab(icon: Icon(Icons.audiotrack), text: 'Audio'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllTab(),
                _buildMeditationTab(),
                _buildAudioTab(),
              ],
            ),
    );
  }

  Widget _buildAllTab() {
    return RefreshIndicator(
      onRefresh: _initializeData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Mood Check-in
            _buildMoodCheckIn(),
            const SizedBox(height: 16),
            
            // AI Recommendation Card
            if (_recommendations.isNotEmpty) ...[
              _buildAIRecommendationCard(),
              const SizedBox(height: 16),
            ],
            
            // Continue Last Session
            if (_lastSession != null) ...[
              _buildContinueLastSession(),
              const SizedBox(height: 16),
            ],
            
            // Daily Wellness Tip
            _buildDailyTip(),
            const SizedBox(height: 16),
            
            // Need Help Now Button
            _buildNeedHelpNow(),
            const SizedBox(height: 16),
            
            // Quick Access to Resources
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mood, color: Colors.purple[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Daily Mood Check-in',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'How are you feeling today?',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: moods.map((mood) {
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      createAnimatedRoute(
                        const MoodTrackingScreen(),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
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
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple[100]!,
            Colors.purple[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.transparent,
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
                    color: Colors.purple[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Recommendation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[900],
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
                color: Colors.purple[900],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              topRecommendation.description,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (topRecommendation.type == RecommendationType.therapy) {
                  Navigator.push(
                    context,
                    createAnimatedRoute(const TherapistMatchingScreen()),
                  );
                } else if (topRecommendation.type == RecommendationType.journaling) {
                  Navigator.push(
                    context,
                    createAnimatedRoute(const JournalScreen()),
                  );
                } else {
                  // Switch to appropriate tab
                  if (topRecommendation.type == RecommendationType.meditation) {
                    _tabController.animateTo(1);
                  } else {
                    _tabController.animateTo(2);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
              ),
              child: Text(topRecommendation.action),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildContinueLastSession() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _playResource(_lastSession!),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.play_arrow, color: Colors.purple[700], size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Last Session',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastSession!.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[900],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTip() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Daily Wellness Tip',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _dailyTip ?? 'Take a moment to breathe deeply and center yourself.',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedHelpNow() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showHelpOptions(),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red[400]!,
                Colors.red[600]!,
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
    final quickResources = _allResources.take(3).toList();
    if (quickResources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.purple[900],
          ),
        ),
        const SizedBox(height: 12),
        ...quickResources.map((resource) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildResourceCard(resource, showFavorite: true),
            )),
      ],
    );
  }

  Widget _buildMeditationTab() {
    String? selectedCategory;
    int? selectedDuration;

    return StatefulBuilder(
      builder: (context, setState) {
        // Get meditation resources
        final meditations = MeditationResources.getFiltered(
          category: selectedCategory,
          duration: selectedDuration,
        );

        return Column(
          children: [
            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.purple[50],
              child: Column(
                children: [
                  // Category Filter
                  Row(
                    children: [
                      Text(
                        'Category:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[900]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip('All', selectedCategory == null, () {
                              setState(() => selectedCategory = null);
                            }),
                            ...MeditationResources.categories.map((cat) => _buildFilterChip(
                                  cat,
                                  selectedCategory == cat.toLowerCase(),
                                  () {
                                    setState(() => selectedCategory = cat.toLowerCase());
                                  },
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Duration Filter
                  Row(
                    children: [
                      Text(
                        'Duration:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[900]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip('All', selectedDuration == null, () {
                              setState(() => selectedDuration = null);
                            }),
                            _buildFilterChip('5 min', selectedDuration == 5, () {
                              setState(() => selectedDuration = 5);
                            }),
                            _buildFilterChip('10 min', selectedDuration == 10, () {
                              setState(() => selectedDuration = 10);
                            }),
                            _buildFilterChip('20 min', selectedDuration == 20, () {
                              setState(() => selectedDuration = 20);
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Meditation List
            Expanded(
              child: _buildMeditationList(meditations),
            ),
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
            Icon(Icons.self_improvement_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No meditations found', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadResources,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: meditations.length,
        itemBuilder: (context, index) => _buildMeditationCard(meditations[index]),
      ),
    );
  }

  Widget _buildMeditationCard(MeditationResource meditation) {
    final sessionCount = _sessionCounts[meditation.id] ?? 0;
    final isFavorite = _favorites.contains(meditation.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            createAnimatedRoute(
              MeditationPlayerScreen(meditation: meditation),
            ),
          ).then((_) {
            // Track session when returning from player
            _trackSession(meditation.id);
          });
        },
        borderRadius: BorderRadius.circular(12),
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
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.self_improvement,
                      color: Colors.purple[700],
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
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meditation.description,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => _toggleFavorite(meditation.id),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      meditation.category.toUpperCase(),
                      style: TextStyle(
                        color: Colors.purple[900],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${meditation.duration} min', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  if (sessionCount > 0) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$sessionCount sessions',
                      style: TextStyle(color: Colors.green[600], fontSize: 12),
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
    final sleepAudios = audioResources.where((r) => r.tags.contains('sleep')).toList();

    return Column(
      children: [
        // Night Suggestion
        if (isNight && sleepAudios.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo[100]!, Colors.indigo[50]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.nightlight_round, color: Colors.indigo[700], size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sleep Audio Suggested',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[900],
                        ),
                      ),
                      Text(
                        sleepAudios.first.title,
                        style: TextStyle(color: Colors.indigo[700], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.play_arrow, color: Colors.indigo[700]),
                  onPressed: () => _playResource(sleepAudios.first),
                ),
              ],
            ),
          ),
        ],
        // Audio List
        Expanded(
          child: _buildResourcesList(audioResources, showAutoStop: true),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.purple[200],
      checkmarkColor: Colors.purple[900],
      labelStyle: TextStyle(
        color: selected ? Colors.purple[900] : Colors.grey[700],
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildResourcesList(List<WellnessResourceModel> resources, {bool showCategory = false, bool showAutoStop = false}) {
    if (resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.spa_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No resources available', style: TextStyle(color: Colors.grey[600])),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _playResource(resource),
        borderRadius: BorderRadius.circular(12),
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
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      resource.type == ResourceType.meditation
                          ? Icons.self_improvement
                          : Icons.audiotrack,
                      color: Colors.purple[700],
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
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resource.description,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                        color: isFavorite ? Colors.red : Colors.grey,
                      ),
                      onPressed: () => _toggleFavorite(resource.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (resource.duration > 0) ...[
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${resource.duration} min', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(width: 16),
                  ],
                  if (showCategory && resource.tags.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        resource.tags.first.toUpperCase(),
                        style: TextStyle(
                          color: Colors.purple[900],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (sessionCount > 0) ...[
                    Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$sessionCount sessions',
                      style: TextStyle(color: Colors.green[600], fontSize: 12),
                    ),
                  ],
                ],
              ),
              if (showAutoStop)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Auto-stop available',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
        action: SnackBarAction(
          label: 'Stop',
          onPressed: () {},
        ),
      ),
    );
  }


  void _showHelpOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Need Help Now?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.purple[900],
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.air, color: Colors.blue[700]),
              ),
              title: const Text('Breathing Exercise'),
              subtitle: const Text('Quick 5-minute breathing exercise'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to breathing exercise
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.people, color: Colors.purple[700]),
              ),
              title: const Text('Find a Therapist'),
              subtitle: const Text('Connect with a professional'),
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
    );
  }
}
