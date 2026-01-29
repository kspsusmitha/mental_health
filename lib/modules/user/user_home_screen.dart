import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/realtime_database_service.dart';
import '../../models/user_model.dart';
import '../../models/journal_entry_model.dart';
import '../../utils/page_transitions.dart';
import '../user/screens/ai_chat_screen.dart';
import '../user/screens/mood_tracking_screen.dart';
import '../user/screens/journal_screen.dart';
import '../user/screens/wellness_screen.dart';
import '../user/screens/therapist_matching_screen.dart';
import '../user/screens/profile_screen.dart';
import '../user/screens/community_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  final List<Widget> _screens = [
    const UserDashboardScreen(),
    const JournalScreen(),
    const WellnessScreen(),
    const CommunityScreen(),
    const UserProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa),
            label: 'Wellness',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  UserModel? _currentUser;
  List<JournalEntryModel> _recentEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadMoodData();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser ?? await authService.getUserData(
      authService.currentUser?.id ?? '',
      authService.currentUser?.userType,
    );
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  Future<void> _loadMoodData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final entriesData = await dbService.readList('$userNodePath/$userId/journal_entries');
      
      final entries = entriesData
          .map((data) => JournalEntryModel.fromMap(data))
          .toList();
      
      entries.sort((a, b) => b.date.compareTo(a.date));
      
      // Get entries from last 7 days
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentEntries = entries.where((e) => e.date.isAfter(weekAgo)).toList();
      
      setState(() {
        _recentEntries = recentEntries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MindCare'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                createAnimatedRoute(const AIChatScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMoodData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    _buildWelcomeCard(context),
            const SizedBox(height: 24),
            
            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.chat_bubble,
                    title: 'AI Chat',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        createAnimatedRoute(const AIChatScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.mood,
                    title: 'Mood Check',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        createAnimatedRoute(const MoodTrackingScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.book,
                    title: 'Journal',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        createAnimatedRoute(const JournalScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.spa,
                    title: 'Wellness',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WellnessScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.people,
                    title: 'Community',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        createAnimatedRoute(const CommunityScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.medical_services,
                    title: 'Find Therapist',
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        createAnimatedRoute(const TherapistMatchingScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
                    const SizedBox(height: 24),
                    
                    // Recent Mood Summary
                    Text(
                      'Your Mood This Week',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildMoodSummaryCard(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final userName = _currentUser?.name ?? 'User';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $userName!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'How are you feeling today?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                createAnimatedRoute(const MoodTrackingScreen()),
              ).then((_) => _loadMoodData());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Check In'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodSummaryCard(BuildContext context) {
    if (_recentEntries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.mood_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No mood data this week', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      createAnimatedRoute(const MoodTrackingScreen()),
                    ).then((_) => _loadMoodData());
                  },
                  child: const Text('Start Tracking'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Group entries by day of week
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final moodIcons = {
      'happy': Icons.sentiment_very_satisfied,
      'sad': Icons.sentiment_dissatisfied,
      'anxious': Icons.sentiment_very_dissatisfied,
      'stressed': Icons.sentiment_dissatisfied,
      'angry': Icons.sentiment_very_dissatisfied,
      'neutral': Icons.sentiment_neutral,
      'depressed': Icons.sentiment_dissatisfied,
      'overwhelmed': Icons.sentiment_dissatisfied,
    };
    final moodColors = {
      'happy': Colors.green,
      'sad': Colors.blue,
      'anxious': Colors.orange,
      'stressed': Colors.red,
      'angry': Colors.deepOrange,
      'neutral': Colors.grey,
      'depressed': Colors.purple,
      'overwhelmed': Colors.pink,
    };

    final moodByDay = <String, JournalEntryModel>{};
    for (final entry in _recentEntries) {
      final dayOfWeek = weekDays[entry.date.weekday - 1];
      if (!moodByDay.containsKey(dayOfWeek)) {
        moodByDay[dayOfWeek] = entry;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays.map((day) {
                final entry = moodByDay[day];
                if (entry != null) {
                  return _buildMoodDay(
                    day,
                    moodIcons[entry.mood] ?? Icons.sentiment_neutral,
                    moodColors[entry.mood] ?? Colors.grey,
                  );
                } else {
                  return _buildMoodDay(day, Icons.circle_outlined, Colors.grey[300]!);
                }
              }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  createAnimatedRoute(const MoodTrackingScreen()),
                ).then((_) => _loadMoodData());
              },
              child: const Text('View Full Analytics'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodDay(String day, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          day,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

