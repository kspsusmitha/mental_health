import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/realtime_database_service.dart';
import '../../models/appointment_model.dart';
import 'screens/appointments_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/therapist_profile_screen.dart';

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
  int _totalClients = 0;
  int _completedSessions = 0;
  double _rating = 0.0;
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
          .where((a) => a.status == AppointmentStatus.scheduled)
          .where((a) => a.scheduledTime.isAfter(DateTime.now()))
          .toList();

      upcomingAppointments.sort(
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

      setState(() {
        _upcomingAppointments = appointmentsWithUsers;
        _totalClients = clientIds.length;
        _completedSessions = completedAppointments.length;
        _rating = 4.8; // Default rating, can be calculated from feedback later
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
        title: const Text('Therapist Dashboard'),
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
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
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            icon: Icons.people,
                            title: 'Clients',
                            value: _totalClients.toString(),
                            color: Colors.green,
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
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            icon: Icons.star,
                            title: 'Rating',
                            value: _rating.toStringAsFixed(1),
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
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
                          child: _buildStatCard(
                            context,
                            icon: Icons.people,
                            title: 'Manage Clients',
                            value: 'View',
                            color: Colors.teal,
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
                      ),
                    ),
                    const SizedBox(height: 16),
                    _upcomingAppointments.isEmpty
                        ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No upcoming appointments',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Card(
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
                                            child: Icon(Icons.person),
                                          ),
                                          title: Text(userName),
                                          subtitle: Text(
                                            appointment.type
                                                .toString()
                                                .toUpperCase(),
                                          ),
                                          trailing: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                dateFormat['label'] ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                dateFormat['time'] ?? '',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (appointment !=
                                            _upcomingAppointments.last)
                                          const Divider(),
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
    return Card(
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
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
