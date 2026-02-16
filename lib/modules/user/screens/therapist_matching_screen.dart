import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/therapist_model.dart';
import '../../../models/appointment_model.dart';
import '../../../models/review_model.dart';
import 'package:uuid/uuid.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

class TherapistMatchingScreen extends StatefulWidget {
  const TherapistMatchingScreen({super.key});

  @override
  State<TherapistMatchingScreen> createState() =>
      _TherapistMatchingScreenState();
}

class _TherapistMatchingScreenState extends State<TherapistMatchingScreen> {
  List<TherapistModel> _therapists = [];
  List<AppointmentModel> _userAppointments = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  Future<void> _getCurrentUserId() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() => _currentUserId = user.id);
      }
      _loadData();
    }
  }

  Future<void> _loadData() async {
    await Future.wait([_loadTherapists(), _loadUserAppointments()]);
  }

  Future<void> _loadUserAppointments() async {
    if (_currentUserId == null) return;
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final appointmentsData = await dbService.readList(
        '$userNodePath/$_currentUserId/appointments',
      );

      if (mounted) {
        setState(() {
          _userAppointments = appointmentsData
              .map((data) => AppointmentModel.fromMap(data))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading user appointments: $e');
    }
  }

  Future<void> _loadTherapists() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final therapistsData = await dbService.readList('therapists');

      if (mounted) {
        setState(() {
          _therapists = therapistsData
              .map((data) => TherapistModel.fromMap(data))
              .where((t) => t.isVerified)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _bookAppointment(TherapistModel therapist) async {
    if (_currentUserId == null) return;

    // Check if user already has an active appointment
    final hasActiveAppointment = _userAppointments.any(
      (apt) =>
          apt.status == AppointmentStatus.pending ||
          apt.status == AppointmentStatus.accepted ||
          apt.status == AppointmentStatus.scheduled,
    );

    if (hasActiveAppointment) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Booking Restricted'),
            content: const Text(
              'You already have an active appointment or request. Please complete or cancel your existing appointment before booking another one.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (selectedDate == null) return;

    if (!mounted) return;

    // Check availability and generate slots
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );

      // 1. Get existing appointments for this therapist on this day
      final appointmentsSnapshot = await dbService.readList(
        'therapists/${therapist.id}/appointments',
      );
      final existingAppointments = appointmentsSnapshot
          .map((data) => AppointmentModel.fromMap(data))
          .where((apt) {
            return apt.scheduledTime.year == selectedDate.year &&
                apt.scheduledTime.month == selectedDate.month &&
                apt.scheduledTime.day == selectedDate.day &&
                apt.status != AppointmentStatus.cancelled;
          })
          .toList();

      // 2. Check 25-slot limit
      if (existingAppointments.length >= 25) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This therapist is fully booked for the selected date (Max 25 slots).',
              ),
            ),
          );
        }
        return;
      }

      // 3. Generate available slots based on availability
      final dayName = DateFormat('EEEE').format(selectedDate);
      final List<String> availableRanges =
          therapist.availability?[dayName] ?? [];

      if (availableRanges.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Therapist is not available on this day.'),
            ),
          );
        }
        return;
      }

      List<TimeOfDay> availableSlots = [];
      for (final range in availableRanges) {
        final parts = range.split('-');
        if (parts.length != 2) continue;

        final start = _parseTime(parts[0]);
        final end = _parseTime(parts[1]);

        if (start == null || end == null) continue;

        var current = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          start.hour,
          start.minute,
        );
        final endTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          end.hour,
          end.minute,
        );

        while (current.isBefore(endTime)) {
          // Check if this slot is already booked
          final isBooked = existingAppointments.any((apt) {
            final aptTime = apt.scheduledTime;
            return aptTime.hour == current.hour &&
                aptTime.minute == current.minute;
          });

          if (!isBooked) {
            availableSlots.add(
              TimeOfDay(hour: current.hour, minute: current.minute),
            );
          }
          current = current.add(const Duration(minutes: 30)); // 30 min slots
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (availableSlots.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No available slots for this date.')),
          );
        }
        return;
      }

      // 4. Show slot selection dialog
      if (!mounted) return;
      final selectedTime = await showDialog<TimeOfDay>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Select Time for ${DateFormat('MMM dd').format(selectedDate)}',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: availableSlots.length,
              itemBuilder: (context, index) {
                final time = availableSlots[index];
                return OutlinedButton(
                  onPressed: () => Navigator.pop(context, time),
                  child: Text(
                    time.format(context),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedTime == null) return;

      final appointmentDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      if (!mounted) return;
      // Proceed with booking
      await _finalizeBooking(therapist, appointmentDateTime);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking availability: $e')),
        );
      }
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length != 2) return null;
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }

  Future<void> _finalizeBooking(
    TherapistModel therapist,
    DateTime appointmentDateTime,
  ) async {
    try {
      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final appointment = AppointmentModel(
        id: const Uuid().v4(),
        userId: _currentUserId!,
        therapistId: therapist.id,
        scheduledTime: appointmentDateTime,
        status: AppointmentStatus.pending,
        type: AppointmentType.video,
      );

      // Save appointment under user's node
      await dbService.writeData(
        '$userNodePath/$_currentUserId/appointments/${appointment.id}',
        appointment.toMap(),
      );

      // Also save under therapist's node for therapist to see
      await dbService.writeData(
        'therapists/${therapist.id}/appointments/${appointment.id}',
        appointment.toMap(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Appointment requested! Waiting for therapist approval.',
            ),
          ),
        );
      }
      // Reload appointments after booking
      await _loadUserAppointments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking appointment: $e')),
        );
      }
    }
  }

  void _showReviews(TherapistModel therapist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return GlassContainer(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Reviews for ${therapist.name}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<ReviewModel>>(
                    future: _fetchReviews(therapist.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }
                      final reviews = snapshot.data ?? [];
                      if (reviews.isEmpty) {
                        return const Center(
                          child: Text(
                            'No reviews yet',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: reviews.length,
                        itemBuilder: (context, index) {
                          final review = reviews[index];
                          return GlassContainer(
                            opacity: 0.1,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                        children: List.generate(5, (starIndex) {
                                          return Icon(
                                            starIndex < review.rating
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 16,
                                            color: Colors.amberAccent,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    review.comment,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                                    style: const TextStyle(
                                      color: Colors.white38,
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<ReviewModel>> _fetchReviews(String therapistId) async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final reviewsData = await dbService.readList(
        'therapists/$therapistId/reviews',
      );
      final reviews = reviewsData
          .map((data) => ReviewModel.fromMap(data))
          .toList();
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Find a Therapist',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1620147425253-33923055375d?q=80&w=2080&auto=format&fit=crop',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _therapists.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.white60),
                    const SizedBox(height: 16),
                    Text(
                      'No therapists available',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadTherapists,
                color: Colors.white,
                backgroundColor: Colors.white24,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                  itemCount: _therapists.length,
                  itemBuilder: (context, index) {
                    final therapist = _therapists[index];
                    final userAppointment = _userAppointments.firstWhere(
                      (apt) =>
                          apt.therapistId == therapist.id &&
                          (apt.status == AppointmentStatus.pending ||
                              apt.status == AppointmentStatus.accepted ||
                              apt.status == AppointmentStatus.scheduled),
                      orElse: () => AppointmentModel(
                        id: '',
                        userId: '',
                        therapistId: '',
                        scheduledTime: DateTime.now(),
                        status: AppointmentStatus.cancelled,
                        type: AppointmentType.text,
                      ),
                    );

                    return _TherapistCard(
                      therapist: therapist,
                      activeAppointment: userAppointment.id.isNotEmpty
                          ? userAppointment
                          : null,
                      onBook: () => _bookAppointment(therapist),
                      onSeeReviews: () => _showReviews(therapist),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _TherapistCard extends StatelessWidget {
  final TherapistModel therapist;
  final AppointmentModel? activeAppointment;
  final VoidCallback onBook;
  final VoidCallback onSeeReviews;

  const _TherapistCard({
    required this.therapist,
    this.activeAppointment,
    required this.onBook,
    required this.onSeeReviews,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      opacity: 0.2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: therapist.profileImageUrl != null
                      ? ClipOval(
                          child: Image.network(therapist.profileImageUrl!),
                        )
                      : const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            therapist.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (therapist.isVerified) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.verified,
                              color: Colors.lightBlueAccent,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        therapist.specialization,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amberAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${therapist.rating.toStringAsFixed(1)} (${therapist.totalSessions} sessions)',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              therapist.bio,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (therapist.specializations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: therapist.specializations.take(3).map((spec) {
                  return Chip(
                    label: Text(spec, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white10,
                    labelStyle: const TextStyle(color: Colors.white),
                    padding: EdgeInsets.zero,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSeeReviews,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    child: const Text('Reviews'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: activeAppointment != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              activeAppointment!.status,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getStatusColor(activeAppointment!.status),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _getStatusText(activeAppointment!.status),
                              style: TextStyle(
                                color: _getStatusColor(
                                  activeAppointment!.status,
                                ),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: onBook,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                          ),
                          child: const Text('Book'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return Colors.orangeAccent;
      case AppointmentStatus.accepted:
        return Colors.greenAccent;
      case AppointmentStatus.scheduled:
        return Colors.lightBlueAccent;
      default:
        return Colors.white70;
    }
  }

  String _getStatusText(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return 'Pending Approval';
      case AppointmentStatus.accepted:
        return 'Booking Accepted';
      case AppointmentStatus.scheduled:
        return 'Booked';
      default:
        return 'Booked';
    }
  }
}
