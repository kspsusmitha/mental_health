import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/realtime_database_service.dart';
import '../../../models/appointment_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

class AdminAppointmentsScreen extends StatefulWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  State<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState extends State<AdminAppointmentsScreen> {
  bool _isLoading = true;
  List<AppointmentModel> _appointments = [];
  Map<String, UserModel> _users = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );

      // 1. Fetch all users to map IDs to names
      // Optimally, we should only fetch users involved in appointments, but for now fetching all users
      // is simpler given the structure.
      final usersData = await dbService.readList('users');
      final usersMap = <String, UserModel>{};
      for (var data in usersData) {
        final user = UserModel.fromMap(data);
        usersMap[user.id] = user;
      }

      // 2. Fetch all therapists (to get their appointments)
      final therapistsData = await dbService.readList('therapists');
      // Note: Therapist data might be in 'therapists' node, but we also have them in 'users' map.
      // However, appointments are stored under 'therapists/{id}/appointments'.

      List<AppointmentModel> allAppointments = [];

      for (var therapistData in therapistsData) {
        final therapistId = therapistData['id'];
        if (therapistId != null) {
          // Store therapist details if needed specifically from therapist node,
          // but we already have them in usersMap if they are users.
          // Let's ensure we have them in _therapists map for easy access if they differ.
          // Actually, using usersMap for names is enough usually.

          // Fetch appointments for this therapist
          final appointmentsData = await dbService.readList(
            'therapists/$therapistId/appointments',
          );
          for (var appData in appointmentsData) {
            try {
              final appointment = AppointmentModel.fromMap(appData);
              allAppointments.add(appointment);
            } catch (e) {
              debugPrint('Error parsing appointment: $e');
            }
          }
        }
      }

      // Sort by date descending
      allAppointments.sort(
        (a, b) => b.scheduledTime.compareTo(a.scheduledTime),
      );

      if (mounted) {
        setState(() {
          _users = usersMap;
          _appointments = allAppointments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading appointments: $e')),
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
          'All Appointments',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1576091160550-2187d80aeff2?auto=format&fit=crop&q=80',
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: Colors.white,
          backgroundColor: Colors.white24,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _appointments.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(
                      child: Text(
                        'No appointments found',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                  itemCount: _appointments.length,
                  itemBuilder: (context, index) {
                    final appointment = _appointments[index];
                    final client = _users[appointment.userId];
                    final therapist = _users[appointment.therapistId];

                    return _AdminAppointmentCard(
                      appointment: appointment,
                      clientName: client?.name ?? 'Unknown Client',
                      therapistName: therapist?.name ?? 'Unknown Therapist',
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AdminAppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final String clientName;
  final String therapistName;

  const _AdminAppointmentCard({
    required this.appointment,
    required this.clientName,
    required this.therapistName,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final statusColor = _getStatusColor(appointment.status);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
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
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    appointment.status.toString().toUpperCase().split('.').last,
                    style: TextStyle(
                      color: statusColor.withOpacity(0.9), // Slightly brighter
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: Colors.white.withOpacity(0.1)),
            _buildInfoRow(Icons.person, 'Client:', clientName),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.medical_services, 'Therapist:', therapistName),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.videocam,
              'Type:',
              appointment.type.toString().toUpperCase().split('.').last,
            ),
            if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.note, 'Notes:', appointment.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white60),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white60)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return Colors.lightBlueAccent;
      case AppointmentStatus.completed:
        return Colors.lightGreenAccent; // Brighter for dark bg
      case AppointmentStatus.cancelled:
        return Colors.redAccent;
      case AppointmentStatus.pending:
        return Colors.purpleAccent;
      case AppointmentStatus.accepted:
        return Colors.tealAccent;
      case AppointmentStatus.declined:
        return Colors.grey;
      case AppointmentStatus.rescheduled:
        return Colors.orangeAccent;
    }
  }
}
