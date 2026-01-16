import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import '../../../screens/auth/module_selection_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser ?? await authService.getUserData(
      authService.currentUser?.id ?? '',
      authService.currentUser?.userType,
    );
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
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
      appBar: AppBar(
        title: const Text('Admin Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? const Center(child: Text('User not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: _currentUser!.profileImageUrl != null
                            ? ClipOval(child: Image.network(_currentUser!.profileImageUrl!))
                            : Icon(Icons.admin_panel_settings, size: 50, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentUser!.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentUser!.email,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 32),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.admin_panel_settings),
                              title: const Text('Account Type'),
                              trailing: Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: const Text('Member Since'),
                              trailing: Text(
                                '${_currentUser!.createdAt.day}/${_currentUser!.createdAt.month}/${_currentUser!.createdAt.year}',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

