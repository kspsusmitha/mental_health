import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/appointment_model.dart';
import '../../../models/therapist_model.dart';
import '../../../models/review_model.dart';
import 'package:uuid/uuid.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final AppointmentModel appointment;

  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  TherapistModel? _therapist;
  bool _isLoadingTherapist = true;

  @override
  void initState() {
    super.initState();
    _loadTherapistDetails();
  }

  Future<void> _loadTherapistDetails() async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final data = await dbService.readData(
        'therapists/${widget.appointment.therapistId}',
      );
      if (data != null && mounted) {
        setState(() {
          _therapist = TherapistModel.fromMap(data);
          _isLoadingTherapist = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTherapist = false);
      }
    }
  }

  Future<void> _cancelAppointment() async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      final userId = authService.currentUser?.id;

      if (userNodePath == null || userId == null) return;

      setState(() => _isLoadingTherapist = true);

      // Update in user's node
      await dbService.updateData(
        '$userNodePath/$userId/appointments/${widget.appointment.id}',
        {'status': AppointmentStatus.cancelled.toString()},
      );

      // Update in therapist's node
      await dbService.updateData(
        'therapists/${widget.appointment.therapistId}/appointments/${widget.appointment.id}',
        {'status': AppointmentStatus.cancelled.toString()},
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTherapist = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _markAppointmentCompleted() async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      final userId = authService.currentUser?.id;

      if (userNodePath == null || userId == null) return;

      setState(() => _isLoadingTherapist = true);

      // Update in user's node
      await dbService.updateData(
        '$userNodePath/$userId/appointments/${widget.appointment.id}',
        {'status': AppointmentStatus.completed.toString()},
      );

      // Update in therapist's node
      await dbService.updateData(
        'therapists/${widget.appointment.therapistId}/appointments/${widget.appointment.id}',
        {'status': AppointmentStatus.completed.toString()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment marked as completed')),
        );
        // Trigger review dialog
        _showReviewDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTherapist = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showReviewDialog() {
    double selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Rate your experience',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How was your session with the therapist?',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amberAccent,
                      size: 32,
                    ),
                    onPressed: () {
                      setDialogState(() => selectedRating = index + 1.0);
                    },
                  );
                }),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your feedback (optional)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Later',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitReview(selectedRating, commentController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReview(double rating, String comment) async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      final userName = authService.currentUser?.name ?? 'Anonymous';

      if (userId == null) return;

      setState(() => _isLoadingTherapist = true);

      final review = ReviewModel(
        id: const Uuid().v4(),
        therapistId: widget.appointment.therapistId,
        userId: userId,
        userName: userName,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );

      // 1. Save review
      await dbService.writeData(
        'therapists/${widget.appointment.therapistId}/reviews/${review.id}',
        review.toMap(),
      );

      // 2. Mark appointment as reviewed
      final userNodePath = authService.getCurrentUserNodePath();
      await dbService.updateData(
        '$userNodePath/$userId/appointments/${widget.appointment.id}',
        {'isReviewed': true},
      );
      await dbService.updateData(
        'therapists/${widget.appointment.therapistId}/appointments/${widget.appointment.id}',
        {'isReviewed': true},
      );

      // 3. Update therapist metrics
      if (_therapist != null) {
        final currentCount = _therapist!.totalSessions;
        final currentRating = _therapist!.rating;
        final newCount = currentCount + 1;
        final newRating = ((currentRating * currentCount) + rating) / newCount;

        await dbService.updateData(
          'therapists/${widget.appointment.therapistId}',
          {'rating': newRating, 'totalSessions': newCount},
        );
      }

      if (mounted) {
        setState(() => _isLoadingTherapist = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        Navigator.pop(context); // Exit detail screen
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTherapist = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting review: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (rest of the build method)
    // Add buttons at the end of Column
    /*
              const SizedBox(height: 40),
              if (widget.appointment.status == AppointmentStatus.scheduled ||
                  widget.appointment.status == AppointmentStatus.pending)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _cancelAppointment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel Appointment', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              if (widget.appointment.status == AppointmentStatus.accepted)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _markAppointmentCompleted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Mark Completed', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _cancelAppointment,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel Appointment'),
                      ),
                    ),
                  ],
                ),
    */
    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    final statusColors = {
      AppointmentStatus.scheduled: Colors.lightBlueAccent,
      AppointmentStatus.completed: Colors.lightGreenAccent,
      AppointmentStatus.cancelled: Colors.redAccent,
      AppointmentStatus.rescheduled: Colors.orangeAccent,
      AppointmentStatus.pending: Colors.purpleAccent,
      AppointmentStatus.accepted: Colors.tealAccent,
      AppointmentStatus.declined: Colors.grey,
    };

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Appointment Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1518531933037-8845d583afa2?auto=format&fit=crop&q=80',
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Therapist Header
              GlassContainer(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white24,
                        backgroundImage: _therapist?.profileImageUrl != null
                            ? NetworkImage(_therapist!.profileImageUrl!)
                            : null,
                        child: _therapist?.profileImageUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _therapist?.name ?? 'Loading...',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _therapist?.specialization ?? 'Therapist',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Appointment Info
              const Text(
                'Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              GlassContainer(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Date',
                        dateFormat.format(widget.appointment.scheduledTime),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.white24, height: 1),
                      ),
                      _buildDetailRow(
                        Icons.access_time,
                        'Time',
                        timeFormat.format(widget.appointment.scheduledTime),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.white24, height: 1),
                      ),
                      _buildDetailRow(
                        Icons.info_outline,
                        'Status',
                        widget.appointment.status.toString().toUpperCase(),
                        valueColor: statusColors[widget.appointment.status],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Session Type
              const Text(
                'Session Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              GlassContainer(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        _getSessionIcon(widget.appointment.type),
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        widget.appointment.type.toString().toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.appointment.notes != null &&
                  widget.appointment.notes!.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                GlassContainer(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      widget.appointment.notes!,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              if (_isLoadingTherapist)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else ...[
                if (widget.appointment.status == AppointmentStatus.scheduled ||
                    widget.appointment.status == AppointmentStatus.pending)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _cancelAppointment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel Appointment',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                if (widget.appointment.status == AppointmentStatus.accepted)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _markAppointmentCompleted,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent.withOpacity(
                              0.8,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Mark Completed',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _cancelAppointment,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel Appointment'),
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  IconData _getSessionIcon(AppointmentType type) {
    switch (type) {
      case AppointmentType.audio:
        return Icons.phone;
      case AppointmentType.video:
        return Icons.videocam;
      case AppointmentType.text:
        return Icons.chat;
    }
  }
}
