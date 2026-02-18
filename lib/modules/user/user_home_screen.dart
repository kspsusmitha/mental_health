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
import '../user/screens/user_appointments_screen.dart';
import '../../screens/auth/module_selection_screen.dart';
import '../user/screens/user_notifications_screen.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_container.dart';
import 'package:carousel_slider/carousel_slider.dart';

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
    const UserAppointmentsScreen(),
    const UserProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() {
          _currentIndex = 0;
        });
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
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
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Appointments',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
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
    final user =
        authService.currentUser ??
        await authService.getUserData(
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
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) {
        setState(() => _isLoading = false);
        return;
      }

      final entriesData = await dbService.readList(
        '$userNodePath/$userId/journal_entries',
      );

      final entries = entriesData
          .map((data) => JournalEntryModel.fromMap(data))
          .toList();

      entries.sort((a, b) => b.date.compareTo(a.date));

      // Get entries from last 7 days
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentEntries = entries
          .where((e) => e.date.isAfter(weekAgo))
          .toList();

      setState(() {
        _recentEntries = recentEntries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ModuleSelectionScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('MindCare'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                createAnimatedRoute(const UserNotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
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
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1506126613408-eca07ce68773?q=80&w=2000&auto=format&fit=crop',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : RefreshIndicator(
                onRefresh: _loadMoodData,
                color: Colors.white,
                backgroundColor: Colors.white24,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
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
                              color: Colors.lightBlueAccent,
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
                              color: Colors.purpleAccent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  createAnimatedRoute(
                                    const MoodTrackingScreen(),
                                  ),
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
                              color: Colors.orangeAccent,
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
                              color: Colors.lightGreenAccent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const WellnessScreen(),
                                  ),
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
                              color: Colors.tealAccent,
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
                              color: Colors.redAccent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  createAnimatedRoute(
                                    const TherapistMatchingScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Daily Insights Carousel
                      _buildDailyInsightsCarousel(context),
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
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final userName = _currentUser?.name ?? 'User';
    return GlassContainer(
      opacity: 0.6,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $userName!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'How are you feeling today?',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
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
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
              child: const Text('Check In'),
            ),
          ],
        ),
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
    return GlassContainer(
      opacity: 0.6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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
      return GlassContainer(
        opacity: 0.6,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.mood_outlined, size: 48, color: Colors.black26),
                const SizedBox(height: 16),
                const Text(
                  'No mood data this week',
                  style: TextStyle(color: Colors.black54),
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
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    foregroundColor: Theme.of(context).primaryColor,
                    elevation: 0,
                  ),
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
      'happy': Colors.lightGreenAccent,
      'sad': Colors.lightBlueAccent,
      'anxious': Colors.orangeAccent,
      'stressed': Colors.redAccent,
      'angry': Colors.deepOrangeAccent,
      'neutral': Colors.white70,
      'depressed': Colors.purpleAccent,
      'overwhelmed': Colors.pinkAccent,
    };

    final moodByDay = <String, JournalEntryModel>{};
    for (final entry in _recentEntries) {
      final dayOfWeek = weekDays[entry.date.weekday - 1];
      if (!moodByDay.containsKey(dayOfWeek)) {
        moodByDay[dayOfWeek] = entry;
      }
    }

    return GlassContainer(
      opacity: 0.6,
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
                    moodColors[entry.mood] ?? Colors.black45,
                  );
                } else {
                  return _buildMoodDay(
                    day,
                    Icons.circle_outlined,
                    Colors.black12,
                  );
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.1),
                foregroundColor: Theme.of(context).primaryColor,
                elevation: 0,
              ),
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
        Text(day, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _buildDailyInsightsCarousel(BuildContext context) {
    final insights = [
      {
        'title': 'Mindfulness Tip',
        'description':
            'Take 5 minutes today to focus solely on your breathing. It reduces cortisol levels.',
        'icon': Icons.spa,
        'color': Colors.lightGreenAccent,
      },
      {
        'title': 'Daily Reflection',
        'description':
            'What is one thing you are grateful for today? Writing it down improves mood.',
        'icon': Icons.edit_note,
        'color': Colors.orangeAccent,
      },
      {
        'title': 'Self-Care Reminder',
        'description':
            'Hydration is key for mental clarity. Don\'t forget to drink water!',
        'icon': Icons.water_drop,
        'color': Colors.lightBlueAccent,
      },
      {
        'title': 'Connection',
        'description':
            'Reach out to a friend today. Human connection is a powerful stress buffer.',
        'icon': Icons.people,
        'color': Colors.pinkAccent,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Insights',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        CarouselSlider(
          options: CarouselOptions(
            height: 140,
            enlargeCenterPage: true,
            autoPlay: true,
            aspectRatio: 2.0,
            autoPlayCurve: Curves.fastOutSlowIn,
            enableInfiniteScroll: true,
            autoPlayAnimationDuration: const Duration(milliseconds: 1000),
            viewportFraction: 0.9,
          ),
          items: insights.map((insight) {
            return Builder(
              builder: (BuildContext context) {
                return GlassContainer(
                  opacity: 0.6,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (insight['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            insight['icon'] as IconData,
                            color: insight['color'] as Color,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insight['title'] as String,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                insight['description'] as String,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
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
}
