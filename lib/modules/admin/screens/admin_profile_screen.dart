import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import '../../../screens/auth/module_selection_screen.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

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
    final user =
        authService.currentUser ??
        await authService.getUserData(
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Admin Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1542831371-29b0f74f9713?auto=format&fit=crop&q=80',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _currentUser == null
            ? const Center(
                child: Text(
                  'User not found',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white24,
                      child: _currentUser!.profileImageUrl != null
                          ? ClipOval(
                              child: Image.network(
                                _currentUser!.profileImageUrl!,
                              ),
                            )
                          : const Icon(
                              Icons.admin_panel_settings,
                              size: 50,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentUser!.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentUser!.email,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 32),
                    GlassContainer(
                      opacity: 0.2,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Account Type',
                              style: TextStyle(color: Colors.white),
                            ),
                            trailing: Text(
                              'ADMIN',
                              style: TextStyle(
                                color: Colors.redAccent.shade100,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Divider(color: Colors.white.withOpacity(0.1)),
                          ListTile(
                            leading: const Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Member Since',
                              style: TextStyle(color: Colors.white),
                            ),
                            trailing: Text(
                              '${_currentUser!.createdAt.day}/${_currentUser!.createdAt.month}/${_currentUser!.createdAt.year}',
                              style: const TextStyle(color: Colors.white70),
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
                        backgroundColor: Colors.red.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
