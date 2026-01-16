import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/mock_auth_service.dart';
import '../chat/chat_screen.dart';
import '../journal/journal_screen.dart';
import '../wellness/wellness_screen.dart';
import '../therapist/therapist_screen.dart';
import '../admin/admin_screen.dart';
import '../analytics/mood_analytics_screen.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<MockAuthService>(context);
    final user = authService.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    final screens = _getScreensForUserType(user.userType);

    return FutureBuilder<UserModel?>(
      future: authService.getUserData(user.id),
      builder: (context, userSnapshot) {
        final currentUser = userSnapshot.data ?? user;

        return Scaffold(
          appBar: AppBar(
            title: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: Text('Hello, ${currentUser.name}'),
                  ),
                );
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  // TODO: Implement notifications
                },
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'logout') {
                    await Provider.of<MockAuthService>(context, listen: false).signOut();
                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: _getDestinationsForUserType(currentUser.userType),
          ),
        );
      },
    );
  }

  List<Widget> _getScreensForUserType(UserType userType) {
    switch (userType) {
      case UserType.admin:
        return [
          const AdminDashboardScreen(),
          const ChatScreen(),
          const JournalScreen(),
          const WellnessScreen(),
        ];
      case UserType.therapist:
        return [
          const TherapistScreen(),
          const ChatScreen(),
          const JournalScreen(),
          const WellnessScreen(),
        ];
      default:
        return [
          const UserDashboardScreen(),
          const ChatScreen(),
          const JournalScreen(),
          const WellnessScreen(),
          const TherapistScreen(),
        ];
    }
  }

  List<NavigationDestination> _getDestinationsForUserType(UserType userType) {
    switch (userType) {
      case UserType.admin:
        return const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Admin',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.book),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa),
            label: 'Wellness',
          ),
        ];
      case UserType.therapist:
        return const [
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.book),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa),
            label: 'Wellness',
          ),
        ];
      default:
        return const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.book),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa),
            label: 'Wellness',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Therapists',
          ),
        ];
    }
  }
}

// User Dashboard Screen
class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeTransition(
            opacity: _animationController,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOut,
              )),
              child: Text(
                'Your Wellness Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildQuickActionCard(
            context,
            'Talk to AI Assistant',
            'Get instant support and guidance',
            Icons.chat_bubble,
            Colors.blue,
            () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildQuickActionCard(
            context,
            'Write in Journal',
            'Record your thoughts and feelings',
            Icons.book,
            Colors.purple,
            () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JournalScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildQuickActionCard(
            context,
            'Wellness Resources',
            'Meditation, videos, and more',
            Icons.spa,
            Colors.green,
            () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WellnessScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildQuickActionCard(
            context,
            'Find a Therapist',
            'Connect with professionals',
            Icons.people,
            Colors.orange,
            () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TherapistScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildQuickActionCard(
            context,
            'Mood Analytics',
            'Track your emotional trends',
            Icons.analytics,
            Colors.teal,
            () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MoodAnalyticsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 32),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

