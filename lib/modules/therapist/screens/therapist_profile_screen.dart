import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import '../../../services/realtime_database_service.dart';
import '../../../screens/auth/module_selection_screen.dart';
import '../../../models/review_model.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

class TherapistProfileScreen extends StatefulWidget {
  const TherapistProfileScreen({super.key});

  @override
  State<TherapistProfileScreen> createState() => _TherapistProfileScreenState();
}

class _TherapistProfileScreenState extends State<TherapistProfileScreen> {
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
      });
      if (user != null && user.userType != UserType.therapist) {
        setState(() => _isLoading = false);
      } else {
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
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
                              Icons.person,
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
                    const SizedBox(height: 24),

                    // Edit Profile Button (Therapist Only)
                    if (_currentUser!.userType == UserType.therapist) ...[
                      OutlinedButton.icon(
                        onPressed: _showEditProfileDialog,
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          'Edit Profile',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _showScheduleDialog,
                        icon: const Icon(Icons.schedule, color: Colors.white),
                        label: const Text(
                          'Manage Schedule',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    GlassContainer(
                      opacity: 0.2,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.person,
                              color: Colors.white70,
                            ),
                            title: const Text(
                              'Account Type',
                              style: TextStyle(color: Colors.white),
                            ),
                            trailing: Text(
                              _currentUser!.userType.toString().toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Divider(color: Colors.white.withOpacity(0.1)),
                          ListTile(
                            leading: const Icon(
                              Icons.calendar_today,
                              color: Colors.white70,
                            ),
                            title: const Text(
                              'Member Since',
                              style: TextStyle(color: Colors.white),
                            ),
                            trailing: Text(
                              '${_currentUser!.createdAt.day}/${_currentUser!.createdAt.month}/${_currentUser!.createdAt.year}',
                              style: const TextStyle(color: Colors.white),
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
                    const SizedBox(height: 24),
                    if (_currentUser!.userType == UserType.therapist) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Reviews',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: Provider.of<RealtimeDatabaseService>(
                          context,
                          listen: false,
                        ).streamList('therapists/${_currentUser!.id}/reviews'),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            );
                          }

                          final reviewsData = snapshot.data ?? [];
                          if (reviewsData.isEmpty) {
                            return const Text(
                              'No reviews yet.',
                              style: TextStyle(color: Colors.white70),
                            );
                          }

                          final reviews = reviewsData
                              .map((data) => ReviewModel.fromMap(data))
                              .toList();
                          reviews.sort(
                            (a, b) => b.createdAt.compareTo(a.createdAt),
                          );

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reviews.length,
                            itemBuilder: (context, index) {
                              final review = reviews[index];
                              return GlassContainer(
                                margin: const EdgeInsets.only(bottom: 12),
                                opacity: 0.2,
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
                                              color: Colors.white,
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
                                      Text(
                                        review.comment,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
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

  Future<void> _showScheduleDialog() async {
    // Load current availability
    Map<String, List<String>> currentAvailability = {};
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final therapistData = await dbService.readData(
        'therapists/${_currentUser!.id}',
      );
      if (therapistData != null && therapistData['availability'] != null) {
        final availMap = therapistData['availability'] as Map;
        currentAvailability = Map<String, List<String>>.from(
          availMap.map(
            (key, value) => MapEntry(
              key.toString(),
              (value as List).map((e) => e.toString()).toList(),
            ),
          ),
        );
      }
    } catch (e) {
      // Error loading, start fresh
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => _ScheduleEditorDialog(
        initialAvailability: currentAvailability,
        therapistId: _currentUser!.id,
      ),
    );
  }
}

class _ScheduleEditorDialog extends StatefulWidget {
  final Map<String, List<String>> initialAvailability;
  final String therapistId;

  const _ScheduleEditorDialog({
    super.key,
    required this.initialAvailability,
    required this.therapistId,
  });

  @override
  State<_ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<_ScheduleEditorDialog> {
  late Map<String, bool> _selectedDays;
  late Map<String, TimeOfDay> _startTimes;
  late Map<String, TimeOfDay> _endTimes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDays = {
      'Monday': false,
      'Tuesday': false,
      'Wednesday': false,
      'Thursday': false,
      'Friday': false,
      'Saturday': false,
      'Sunday': false,
    };
    _startTimes = {};
    _endTimes = {};

    // Populate from initial availability
    widget.initialAvailability.forEach((day, times) {
      if (_selectedDays.containsKey(day) && times.isNotEmpty) {
        _selectedDays[day] = true;
        final parts = times.first.split('-'); // Assuming single slot for now
        if (parts.length == 2) {
          _startTimes[day] = _parseTime(parts[0]);
          _endTimes[day] = _parseTime(parts[1]);
        }
      }
    });
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _formatTimeForDb(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _saveSchedule() async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final Map<String, List<String>> newAvailability = {};

      _selectedDays.forEach((day, isSelected) {
        if (isSelected) {
          final start = _formatTimeForDb(
            _startTimes[day] ?? const TimeOfDay(hour: 9, minute: 0),
          );
          final end = _formatTimeForDb(
            _endTimes[day] ?? const TimeOfDay(hour: 17, minute: 0),
          );
          newAvailability[day] = ['$start-$end'];
        }
      });

      await dbService.updateData('therapists/${widget.therapistId}', {
        'availability': newAvailability,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving schedule: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Weekly Schedule'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...[
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
                'Sunday',
              ].map((day) {
                return _buildDayRow(day);
              }).toList(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveSchedule,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildDayRow(String day) {
    final isSelected = _selectedDays[day] ?? false;
    final startTime = _startTimes[day] ?? const TimeOfDay(hour: 9, minute: 0);
    final endTime = _endTimes[day] ?? const TimeOfDay(hour: 17, minute: 0);

    return Column(
      children: [
        CheckboxListTile(
          title: Text(day),
          value: isSelected,
          onChanged: (val) {
            setState(() {
              _selectedDays[day] = val ?? false;
              if (val == true && !_startTimes.containsKey(day)) {
                _startTimes[day] = const TimeOfDay(hour: 9, minute: 0);
                _endTimes[day] = const TimeOfDay(hour: 17, minute: 0);
              }
            });
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (isSelected)
          Padding(
            padding: const EdgeInsets.only(left: 0, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                      );
                      if (time != null) {
                        setState(() => _startTimes[day] = time);
                      }
                    },
                    child: Text(
                      _formatTime(startTime),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('-'),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: endTime,
                      );
                      if (time != null) {
                        setState(() => _endTimes[day] = time);
                      }
                    },
                    child: Text(
                      _formatTime(endTime),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
