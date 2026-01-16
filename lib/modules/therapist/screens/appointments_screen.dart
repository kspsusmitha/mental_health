import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/appointment_model.dart';

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
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final appointmentsData = await dbService.readList('therapists/$_therapistId/appointments');
      
      setState(() {
        _appointments = appointmentsData
            .map((data) => AppointmentModel.fromMap(data))
            .toList();
        _appointments.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAppointmentStatus(AppointmentModel appointment, AppointmentStatus status) async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
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
      appBar: AppBar(
        title: const Text('Appointments'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No appointments yet', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAppointments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _appointments.length,
                    itemBuilder: (context, index) => _AppointmentCard(
                      appointment: _appointments[index],
                      onUpdateStatus: (status) => _updateAppointmentStatus(_appointments[index], status),
                    ),
                  ),
                ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final Function(AppointmentStatus) onUpdateStatus;

  const _AppointmentCard({required this.appointment, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final statusColors = {
      AppointmentStatus.scheduled: Colors.blue,
      AppointmentStatus.completed: Colors.green,
      AppointmentStatus.cancelled: Colors.red,
      AppointmentStatus.rescheduled: Colors.orange,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColors[appointment.status]?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    appointment.status.toString().toUpperCase(),
                    style: TextStyle(
                      color: statusColors[appointment.status],
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
                Icon(Icons.video_call, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  appointment.type.toString().toUpperCase(),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            if (appointment.notes != null) ...[
              const SizedBox(height: 12),
              Text(
                'Notes: ${appointment.notes}',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ],
            if (appointment.status == AppointmentStatus.scheduled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onUpdateStatus(AppointmentStatus.completed),
                      child: const Text('Mark Complete'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onUpdateStatus(AppointmentStatus.cancelled),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

