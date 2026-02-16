import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/appointment_model.dart';
import '../../../models/notification_model.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<AppointmentModel> _appointments = [];
  bool _isLoading = true;
  String? _therapistId;

  @override
  void initState() {
    super.initState();
    _getTherapistId();
  }

  Future<void> _getTherapistId() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user != null) {
      setState(() => _therapistId = user.id);
      _loadAppointments();
    }
  }

  Future<void> _loadAppointments() async {
    if (_therapistId == null) return;

    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final appointmentsData = await dbService.readList(
        'therapists/$_therapistId/appointments',
      );

      setState(() {
        _appointments = appointmentsData
            .map((data) => AppointmentModel.fromMap(data))
            .toList();
        _appointments.sort(
          (a, b) => b.scheduledTime.compareTo(a.scheduledTime),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAppointmentStatus(
    AppointmentModel appointment,
    AppointmentStatus status,
  ) async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final notificationService = NotificationService(dbService);

      // Update in therapist's node
      await dbService.updateData(
        'therapists/$_therapistId/appointments/${appointment.id}',
        {'status': status.toString()},
      );
      // Also update in user's node
      await dbService.updateData(
        'users/${appointment.userId}/appointments/${appointment.id}',
        {'status': status.toString()},
      );

      // Send notification to user
      String title = '';
      String body = '';
      NotificationType type = NotificationType.info;

      if (status == AppointmentStatus.accepted) {
        title = 'Appointment Accepted';
        body = 'Your appointment has been confirmed by the therapist.';
        type = NotificationType.success;
      } else if (status == AppointmentStatus.declined) {
        title = 'Appointment Declined';
        body = 'Your appointment request was declined by the therapist.';
        type = NotificationType.warning;
      }

      if (title.isNotEmpty) {
        await notificationService.sendNotification(
          userId: appointment.userId,
          title: title,
          body: body,
          type: type,
        );
      }

      _loadAppointments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating appointment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Appointments',
          style: TextStyle(color: Colors.white),
        ),
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
                  itemBuilder: (context, index) => _AppointmentCard(
                    appointment: _appointments[index],
                    onUpdateStatus: (status) =>
                        _updateAppointmentStatus(_appointments[index], status),
                  ),
                ),
              ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final Function(AppointmentStatus) onUpdateStatus;

  const _AppointmentCard({
    required this.appointment,
    required this.onUpdateStatus,
  });

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
                        statusColors[appointment.status]?.withOpacity(0.2) ??
                        Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          statusColors[appointment.status]?.withOpacity(0.5) ??
                          Colors.grey.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    appointment.status.toString().toUpperCase().split('.').last,
                    style: TextStyle(
                      color: statusColors[appointment.status] ?? Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.video_call, size: 20, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  appointment.type.toString().toUpperCase().split('.').last,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
            if (appointment.notes != null) ...[
              const SizedBox(height: 12),
              Text(
                'Notes: ${appointment.notes}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
            if (appointment.status == AppointmentStatus.pending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          onUpdateStatus(AppointmentStatus.accepted),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          onUpdateStatus(AppointmentStatus.declined),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent.shade100,
                        side: BorderSide(color: Colors.redAccent.shade100),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ],
            if (appointment.status == AppointmentStatus.scheduled ||
                appointment.status == AppointmentStatus.accepted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => onUpdateStatus(AppointmentStatus.cancelled),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent.shade100,
                    side: BorderSide(color: Colors.redAccent.shade100),
                  ),
                  child: const Text('Cancel Appointment'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
