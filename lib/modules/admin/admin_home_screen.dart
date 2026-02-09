import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/realtime_database_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../models/wellness_resource_model.dart';
import 'screens/users_management_screen.dart';
import 'screens/therapists_management_screen.dart';
import 'screens/content_approval_screen.dart';
import 'screens/admin_profile_screen.dart';
import 'package:uuid/uuid.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const ContentApprovalScreen(),
    const AdminProfileScreen(),
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
              icon: Icon(Icons.approval_outlined),
              selectedIcon: Icon(Icons.approval),
              label: 'Content',
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

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _totalUsers = 0;
  int _totalTherapists = 0;
  int _pendingContent = 0;
  int _totalResources = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );

      final usersData = await dbService.readList('users');
      final therapistsData = await dbService.readList('therapists');
      final resourcesData = await dbService.readList('wellness_resources');

      setState(() {
        _totalUsers = usersData
            .where((u) => UserModel.fromMap(u).userType == UserType.user)
            .length;
        _totalTherapists = therapistsData.length;
        _pendingContent = resourcesData
            .where((r) => !WellnessResourceModel.fromMap(r).isApproved)
            .length;
        _totalResources = resourcesData.length;
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: SingleChildScrollView(
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
                    icon: Icons.people,
                    title: 'Total Users',
                    value: _totalUsers.toString(),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.medical_services,
                    title: 'Therapists',
                    value: _totalTherapists.toString(),
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
                    icon: Icons.approval,
                    title: 'Pending',
                    value: _pendingContent.toString(),
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.spa,
                    title: 'Resources',
                    value: _totalResources.toString(),
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildActionCard(
                  context,
                  icon: Icons.people,
                  title: 'Manage Users',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UsersManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  icon: Icons.medical_services,
                  title: 'Manage Therapists',
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TherapistsManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  icon: Icons.approval,
                  title: 'Approve Content',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContentApprovalScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  icon: Icons.add_circle,
                  title: 'Add Resource',
                  color: Colors.purple,
                  onTap: () {
                    _showAddResourceDialog(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddResourceDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final urlController = TextEditingController();
    final durationController = TextEditingController();
    ResourceType selectedType = ResourceType.meditation;
    bool isApproved = true; // Admin can approve directly

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Wellness Resource'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text('Resource Type:'),
                Wrap(
                  spacing: 8,
                  children: ResourceType.values.map((type) {
                    return ChoiceChip(
                      label: Text(type.toString().split('.').last),
                      selected: selectedType == type,
                      onSelected: (selected) {
                        setState(() => selectedType = type);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty &&
                    descriptionController.text.isNotEmpty &&
                    urlController.text.isNotEmpty) {
                  try {
                    final dbService = Provider.of<RealtimeDatabaseService>(
                      context,
                      listen: false,
                    );
                    final authService = Provider.of<AuthService>(
                      context,
                      listen: false,
                    );
                    final adminId = authService.currentUser?.id ?? '';

                    final now = DateTime.now();
                    final resource = WellnessResourceModel(
                      id: const Uuid().v4(),
                      title: titleController.text,
                      description: descriptionController.text,
                      type: selectedType,
                      url: urlController.text,
                      duration: int.tryParse(durationController.text) ?? 0,
                      createdAt: now,
                      isApproved: isApproved,
                      approvedBy: adminId,
                      approvedAt: now,
                    );

                    await dbService.writeData(
                      'wellness_resources/${resource.id}',
                      resource.toMap(),
                    );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Resource added successfully'),
                        ),
                      );
                      _loadStats();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding resource: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
