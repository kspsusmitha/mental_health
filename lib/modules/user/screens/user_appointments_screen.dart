import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/appointment_model.dart';
import '../../../models/therapist_model.dart';
import '../../../models/review_model.dart';
import 'package:uuid/uuid.dart';
import '../../../services/notification_service.dart';
import '../../../models/notification_model.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

class UserAppointmentsScreen extends StatefulWidget {
  const UserAppointmentsScreen({super.key});

  @override
  State<UserAppointmentsScreen> createState() => _UserAppointmentsScreenState();
}

class _UserAppointmentsScreenState extends State<UserAppointmentsScreen> {
  List<AppointmentModel> _appointments = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _getUserId();
  }

  Future<void> _getUserId() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() => _userId = user.id);
      }
      _loadAppointments();
    }
  }

  Future<void> _loadAppointments() async {
    if (_userId == null) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();

      if (userNodePath != null) {
        final appointmentsData = await dbService.readList(
          '$userNodePath/$_userId/appointments',
        );

        if (mounted) {
          setState(() {
            _appointments = appointmentsData
                .map((data) => AppointmentModel.fromMap(data))
                .toList();
            _appointments.sort(
              (a, b) => b.scheduledTime.compareTo(a.scheduledTime),
            );
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelAppointment(AppointmentModel appointment) async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();

      if (userNodePath == null) return;

      // Update in user's node
      await dbService.updateData(
        '$userNodePath/$_userId/appointments/${appointment.id}',
        {'status': AppointmentStatus.cancelled.toString()},
      );

      // Update in therapist's node
      await dbService.updateData(
        'therapists/${appointment.therapistId}/appointments/${appointment.id}',
        {'status': AppointmentStatus.cancelled.toString()},
      );

      _loadAppointments();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling appointment: $e')),
        );
      }
    }
  }

  Future<void> _markAppointmentCompleted(AppointmentModel appointment) async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();

      if (userNodePath == null) return;

      // Update in user's node
      await dbService.updateData(
        '$userNodePath/$_userId/appointments/${appointment.id}',
        {'status': AppointmentStatus.completed.toString()},
      );

      // Update in therapist's node
      await dbService.updateData(
        'therapists/${appointment.therapistId}/appointments/${appointment.id}',
        {'status': AppointmentStatus.completed.toString()},
      );

      // Send notification to therapist
      final notificationService = NotificationService(dbService);
      await notificationService.sendNotification(
        userId: appointment.therapistId,
        title: 'Appointment Completed',
        body:
            'User ${authService.currentUser?.name ?? "A user"} have marked your appointment as completed.',
        type: NotificationType.success,
      );

      _loadAppointments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment marked as completed')),
        );
        // Prompt for review
        _showReviewDialog(appointment);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating appointment: $e')),
        );
      }
    }
  }

  Future<void> _showReviewDialog(AppointmentModel appointment) async {
    final commentController = TextEditingController();
    double rating = 5.0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate Your Experience'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was your session?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() => rating = index + 1.0);
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Write a review (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _submitReview(
                  appointment,
                  rating,
                  commentController.text,
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReview(
    AppointmentModel appointment,
    double rating,
    String comment,
  ) async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);

      final review = ReviewModel(
        id: const Uuid().v4(),
        therapistId: appointment.therapistId,
        userId: _userId!,
        userName: authService.currentUser?.name ?? 'Anonymous',
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );

      // Save review under therapist's reviews node
      await dbService.writeData(
        'therapists/${appointment.therapistId}/reviews/${review.id}',
        review.toMap(),
      );

      // Update therapist's average rating (simplified)
      final reviewsData = await dbService.readList(
        'therapists/${appointment.therapistId}/reviews',
      );
      final reviews = reviewsData
          .map((data) => ReviewModel.fromMap(data))
          .toList();

      if (reviews.isNotEmpty) {
        final totalRating = reviews.fold(0.0, (sum, r) => sum + r.rating);
        final newAverage = totalRating / reviews.length;

        await dbService.updateData('therapists/${appointment.therapistId}', {
          'rating': newAverage,
        });
      }

      // Send notification to therapist
      final notificationService = NotificationService(dbService);
      await notificationService.sendNotification(
        userId: appointment.therapistId,
        title: 'New Review Received',
        body:
            'You have received a new ${rating.toStringAsFixed(1)}-star review.',
        type: NotificationType.info,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting review: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'My Appointments',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1518531933037-8845d583afa2?auto=format&fit=crop&q=80',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _appointments.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 64,
                      color: Colors.white60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No appointments yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to find therapist tab (index 3)
                        // This requires access to the parent navigation controller or passing a callback
                        // For now, just show a message or pop if pushed
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('Find a Therapist'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadAppointments,
                color: Colors.white,
                backgroundColor: Colors.white24,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                  itemCount: _appointments.length,
                  itemBuilder: (context, index) => _UserAppointmentCard(
                    appointment: _appointments[index],
                    onCancel: () => _cancelAppointment(_appointments[index]),
                    onReview: () => _showReviewDialog(_appointments[index]),
                    onComplete: () =>
                        _markAppointmentCompleted(_appointments[index]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _UserAppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final VoidCallback onCancel;
  final VoidCallback onReview;
  final VoidCallback onComplete;

  const _UserAppointmentCard({
    required this.appointment,
    required this.onCancel,
    required this.onReview,
    required this.onComplete,
  });

  Future<TherapistModel?> _getTherapistDetails(
    BuildContext context,
    String therapistId,
  ) async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final data = await dbService.readData('therapists/$therapistId');
      if (data != null) {
        return TherapistModel.fromMap(data);
      }
    } catch (e) {
      // Ignore error
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final statusColors = {
      AppointmentStatus.scheduled: Colors.lightBlueAccent,
      AppointmentStatus.completed: Colors.lightGreenAccent,
      AppointmentStatus.cancelled: Colors.redAccent,
      AppointmentStatus.rescheduled: Colors.orangeAccent,
      AppointmentStatus.pending: Colors.purpleAccent,
      AppointmentStatus.accepted: Colors.tealAccent,
      AppointmentStatus.declined: Colors.grey,
    };

    return FutureBuilder<TherapistModel?>(
      future: _getTherapistDetails(context, appointment.therapistId),
      builder: (context, snapshot) {
        final therapistName = snapshot.data?.name ?? 'Therapist';
        final therapistImage = snapshot.data?.profileImageUrl;

        return GlassContainer(
          margin: const EdgeInsets.only(bottom: 16),
          opacity: 0.2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateFormat.format(appointment.scheduledTime),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            statusColors[appointment.status]?.withOpacity(
                              0.2,
                            ) ??
                            Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              statusColors[appointment.status]?.withOpacity(
                                0.5,
                              ) ??
                              Colors.grey.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        appointment.status
                            .toString()
                            .toUpperCase()
                            .split('.')
                            .last,
                        style: TextStyle(
                          color:
                              statusColors[appointment.status] ??
                              Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: therapistImage != null
                          ? ClipOval(child: Image.network(therapistImage))
                          : const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          therapistName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Video Consultation',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (appointment.status == AppointmentStatus.scheduled ||
                    appointment.status == AppointmentStatus.pending) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent.shade100,
                        side: BorderSide(color: Colors.redAccent.shade100),
                      ),
                      child: const Text('Cancel Appointment'),
                    ),
                  ),
                ],
                if (appointment.status == AppointmentStatus.accepted) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onComplete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.withOpacity(0.8),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          child: const Text('Mark Completed'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent.shade100,
                            side: BorderSide(color: Colors.redAccent.shade100),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (appointment.status == AppointmentStatus.completed) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onReview,
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Leave a Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.withOpacity(0.2),
                        foregroundColor: Colors.amberAccent,
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
