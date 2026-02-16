import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/realtime_database_service.dart';
import '../../models/appointment_model.dart';
import 'screens/appointments_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/therapist_profile_screen.dart';
import '../../screens/auth/module_selection_screen.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_container.dart';

class TherapistHomeScreen extends StatefulWidget {
  const TherapistHomeScreen({super.key});

  @override
  State<TherapistHomeScreen> createState() => _TherapistHomeScreenState();
}

class _TherapistHomeScreenState extends State<TherapistHomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  final List<Widget> _screens = [
    const TherapistDashboardScreen(),
    const AppointmentsScreen(),
    const TherapistProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    // Check if user is a therapist and verification status
    // Note: We need to ensure we have the latest therapist data, so we might need to fetch it
    // But for now, let's rely on the authService's user model which should be updated on login
    // If we need real-time updates of verification status without relogin, we would need a stream here.

    // Check if the current user object has the isVerified property (it should if it's a TherapistModel or if we cast it)
    // However, AuthService returns UserModel which doesn't have isVerified.
    // We need to fetch the therapist data to check isVerified status.

    return FutureBuilder<Map<String, dynamic>?>(
      future: Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      ).readData('therapists/${currentUser?.id}'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        bool isVerified = false;
        if (snapshot.hasData && snapshot.data != null) {
          isVerified = snapshot.data!['isVerified'] ?? false;
        }

        if (!isVerified) {
          return Scaffold(
            body: AnimatedBackground(
              imageUrl:
                  'https://images.unsplash.com/photo-1579684385136-1f91b402685d?auto=format&fit=crop&q=80',
              child: Center(
                child: GlassContainer(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(32),
                  opacity: 0.2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hourglass_empty_rounded,
                        size: 80,
                        color: Colors.orangeAccent,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Verification Pending',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your profile is currently under review by our administrators. '
                        'Please check back later or contact support if this persists.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await authService.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const ModuleSelectionScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

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
              backgroundColor: Colors.white,
              elevation: 0,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
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
      },
    );
  }
}

class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({super.key});

  @override
  State<TherapistDashboardScreen> createState() =>
      _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> {
  List<AppointmentModel> _upcomingAppointments = [];
  List<AppointmentModel> _pendingAppointments = [];
  int _totalClients = 0;
  int _completedSessions = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final therapistId = authService.currentUser?.id ?? '';

    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );

      // Load appointments
      final appointmentsData = await dbService.readList(
        'therapists/$therapistId/appointments',
      );
      final allAppointments = appointmentsData
          .map((data) => AppointmentModel.fromMap(data))
          .toList();

      final upcomingAppointments = allAppointments
          .where(
            (a) =>
                a.status == AppointmentStatus.scheduled ||
                a.status == AppointmentStatus.accepted,
          )
          .where((a) => a.scheduledTime.isAfter(DateTime.now()))
          .toList();

      upcomingAppointments.sort(
        (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
      );

      final pendingAppointments = allAppointments
          .where((a) => a.status == AppointmentStatus.pending)
          .toList();
      pendingAppointments.sort(
        (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
      );

      final completedAppointments = allAppointments
          .where((a) => a.status == AppointmentStatus.completed)
          .toList();

      // Count unique clients
      final clientIds = allAppointments.map((a) => a.userId).toSet();

      // Load user data for appointments
      final appointmentsWithUsers = <AppointmentModel>[];
      for (final appointment in upcomingAppointments.take(5)) {
        final userData = await dbService.readData(
          'users/${appointment.userId}',
        );
        if (userData != null) {
          appointmentsWithUsers.add(appointment);
        }
      }

      // Load user data for pending appointments
      final pendingWithUsers = <AppointmentModel>[];
      for (final appointment in pendingAppointments) {
        final userData = await dbService.readData(
          'users/${appointment.userId}',
        );
        if (userData != null) {
          pendingWithUsers.add(appointment);
        }
      }

      if (mounted) {
        setState(() {
          _upcomingAppointments = appointmentsWithUsers;
          _pendingAppointments = pendingWithUsers;
          _totalClients = clientIds.length;
          _completedSessions = completedAppointments.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Therapist Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1579684385136-1f91b402685d?auto=format&fit=crop&q=80',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                color: Colors.white,
                backgroundColor: Colors.white24,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.calendar_today,
                              title: 'Upcoming',
                              value: _upcomingAppointments.length.toString(),
                              color: Colors.lightBlueAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.pending_actions,
                              title: 'Pending',
                              value: _pendingAppointments.length.toString(),
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.check_circle,
                              title: 'Completed',
                              value: _completedSessions.toString(),
                              color: Colors.purpleAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.people,
                              title: 'Clients',
                              value: _totalClients.toString(),
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Pending Requests Section
                      if (_pendingAppointments.isNotEmpty) ...[
                        Text(
                          'Pending Requests',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 16),
                        GlassContainer(
                          opacity: 0.2,
                          child: Column(
                            children: _pendingAppointments.map((appointment) {
                              return FutureBuilder<Map<String, dynamic>?>(
                                future: _getUserData(appointment.userId),
                                builder: (context, snapshot) {
                                  final userName =
                                      snapshot.data?['name'] ?? 'Unknown User';
                                  final dateFormat = _getDateFormat(
                                    appointment.scheduledTime,
                                  );

                                  return Column(
                                    children: [
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.white24,
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.orangeAccent,
                                          ),
                                        ),
                                        title: Text(
                                          userName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${dateFormat['label']} at ${dateFormat['time']}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () {
                                            final parentState = context
                                                .findAncestorStateOfType<
                                                  _TherapistHomeScreenState
                                                >();
                                            if (parentState != null) {
                                              parentState.setState(() {
                                                parentState._currentIndex =
                                                    1; // Switch to Appointments tab
                                              });
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orangeAccent
                                                .withOpacity(0.8),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            elevation: 0,
                                          ),
                                          child: const Text('Review'),
                                        ),
                                      ),
                                      if (appointment !=
                                          _pendingAppointments.last)
                                        Divider(
                                          height: 1,
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                    ],
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Quick Actions
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.people,
                              title: 'Manage Clients',
                              value: 'View',
                              color: Colors.tealAccent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ClientsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: SizedBox(),
                          ), // Placeholder for balance
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Upcoming Appointments
                      Text(
                        'Upcoming Appointments',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _upcomingAppointments.isEmpty
                          ? GlassContainer(
                              opacity: 0.1,
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 48,
                                      color: Colors.white60,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No upcoming appointments',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : GlassContainer(
                              opacity: 0.2,
                              child: Column(
                                children: _upcomingAppointments.map((
                                  appointment,
                                ) {
                                  return FutureBuilder<Map<String, dynamic>?>(
                                    future: _getUserData(appointment.userId),
                                    builder: (context, snapshot) {
                                      final userName =
                                          snapshot.data?['name'] ??
                                          'Unknown User';
                                      final dateFormat = _getDateFormat(
                                        appointment.scheduledTime,
                                      );

                                      return Column(
                                        children: [
                                          ListTile(
                                            leading: const CircleAvatar(
                                              backgroundColor: Colors.white24,
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                              ),
                                            ),
                                            title: Text(
                                              userName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            subtitle: Text(
                                              appointment.type
                                                  .toString()
                                                  .toUpperCase()
                                                  .split('.')
                                                  .last,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  dateFormat['label'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  dateFormat['time'] ?? '',
                                                  style: TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (appointment !=
                                              _upcomingAppointments.last)
                                            Divider(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      return await dbService.readData('users/$userId');
    } catch (e) {
      return null;
    }
  }

  Map<String, String> _getDateFormat(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointmentDate = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
    );

    final difference = appointmentDate.difference(today).inDays;

    String label;
    if (difference == 0) {
      label = 'Today';
    } else if (difference == 1) {
      label = 'Tomorrow';
    } else {
      label = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final time =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    return {'label': label, 'time': time};
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GlassContainer(
      opacity: 0.2,
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
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
