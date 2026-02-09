import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import '../../../services/realtime_database_service.dart';
import '../../../screens/auth/module_selection_screen.dart';
import '../../../models/review_model.dart';

class TherapistProfileScreen extends StatefulWidget {
  const TherapistProfileScreen({super.key});

  @override
  State<TherapistProfileScreen> createState() => _TherapistProfileScreenState();
}

class _TherapistProfileScreenState extends State<TherapistProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;
  List<ReviewModel> _reviews = [];

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
      });
      if (user != null && user.userType == UserType.therapist) {
        _loadReviews(user.id);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadReviews(String therapistId) async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final reviewsData = await dbService.readList(
        'therapists/$therapistId/reviews',
      );
      if (mounted) {
        setState(() {
          _reviews = reviewsData
              .map((data) => ReviewModel.fromMap(data))
              .toList();
          _reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      appBar: AppBar(title: const Text('Profile')),
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
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    child: _currentUser!.profileImageUrl != null
                        ? ClipOval(
                            child: Image.network(
                              _currentUser!.profileImageUrl!,
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 50,
                            color: Theme.of(context).colorScheme.primary,
                          ),
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
                  const SizedBox(height: 24),

                  // Edit Profile Button (Therapist Only)
                  if (_currentUser!.userType == UserType.therapist)
                    OutlinedButton.icon(
                      onPressed: _showEditProfileDialog,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                    ),

                  const SizedBox(height: 24),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Account Type'),
                          trailing: Text(
                            _currentUser!.userType.toString().toUpperCase(),
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
                  const SizedBox(height: 24),
                  if (_currentUser!.userType == UserType.therapist) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Reviews',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _reviews.isEmpty
                        ? const Text('No reviews yet.')
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _reviews.length,
                            itemBuilder: (context, index) {
                              final review = _reviews[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            review.userName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Row(
                                            children: List.generate(5, (
                                              starIndex,
                                            ) {
                                              return Icon(
                                                starIndex < review.rating
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                size: 16,
                                                color: Colors.amber,
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(review.comment),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _currentUser!.name);
    final specializationController = TextEditingController();
    final bioController = TextEditingController();

    // Fetch current therapist details to pre-fill
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final therapistData = await dbService.readData(
        'therapists/${_currentUser!.id}',
      );
      if (therapistData != null) {
        specializationController.text = therapistData['specialization'] ?? '';
        bioController.text = therapistData['bio'] ?? '';
      }
    } catch (e) {
      // Ignore error, start with empty fields
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: specializationController,
                decoration: const InputDecoration(labelText: 'Specialization'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final dbService = Provider.of<RealtimeDatabaseService>(
                  context,
                  listen: false,
                );

                // Update user node (name)
                await dbService.updateData('users/${_currentUser!.id}', {
                  'name': nameController.text.trim(),
                });

                // Update therapist node (all details)
                await dbService.updateData('therapists/${_currentUser!.id}', {
                  'name': nameController.text.trim(),
                  'specialization': specializationController.text.trim(),
                  'bio': bioController.text.trim(),
                });

                // Refresh user data
                _loadUser();

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating profile: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
