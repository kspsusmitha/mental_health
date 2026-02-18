import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/appointment_model.dart';
import '../../../models/therapist_model.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';
import './appointment_detail_screen.dart';

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
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 64,
                      color: Colors.white60,
                    ),
                    SizedBox(height: 16),
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
                  itemBuilder: (context, index) => _UserAppointmentCard(
                    appointment: _appointments[index],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppointmentDetailScreen(
                          appointment: _appointments[index],
                        ),
                      ),
                    ).then((_) => _loadAppointments()),
                  ),
                ),
              ),
      ),
    );
  }
}

class _UserAppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final VoidCallback onTap;

  const _UserAppointmentCard({required this.appointment, required this.onTap});

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
      if (data != null) return TherapistModel.fromMap(data);
    } catch (e) {}
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
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
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
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (statusColors[appointment.status] ?? Colors.white)
                                  .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          appointment.status.toString().toUpperCase(),
                          style: TextStyle(
                            color:
                                statusColors[appointment.status] ??
                                Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white24,
                        backgroundImage: therapistImage != null
                            ? NetworkImage(therapistImage)
                            : null,
                        child: therapistImage == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
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
                              appointment.type.toString().toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
