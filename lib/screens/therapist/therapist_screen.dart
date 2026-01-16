import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/mock_firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/therapist_model.dart';
import '../../models/appointment_model.dart';

class TherapistScreen extends StatefulWidget {
  const TherapistScreen({super.key});

  @override
  State<TherapistScreen> createState() => _TherapistScreenState();
}

class _TherapistScreenState extends State<TherapistScreen> {
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
      setState(() => _currentUserId = user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Therapists'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Find Therapist'),
              Tab(icon: Icon(Icons.calendar_today), text: 'Appointments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TherapistList(userId: _currentUserId!),
            _AppointmentsList(userId: _currentUserId!),
          ],
        ),
      ),
    );
  }
}

class _TherapistList extends StatelessWidget {
  final String userId;

  const _TherapistList({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TherapistModel>>(
      stream: Provider.of<MockFirestoreService>(context).getTherapists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No therapists available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final therapists = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: therapists.length,
          itemBuilder: (context, index) {
            return _TherapistCard(therapist: therapists[index], userId: userId);
          },
        );
      },
    );
  }
}

class _TherapistCard extends StatelessWidget {
  final TherapistModel therapist;
  final String userId;

  const _TherapistCard({required this.therapist, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[300],
                  child: therapist.profileImageUrl != null
                      ? Image.network(therapist.profileImageUrl!)
                      : Text(
                          therapist.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 24),
                        ),
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
                            ),
                          ),
                          if (therapist.isVerified) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.verified, color: Colors.blue, size: 20),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        therapist.specialization,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            therapist.rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${therapist.totalSessions} sessions',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (therapist.bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                therapist.bio,
                style: TextStyle(color: Colors.grey[700]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (therapist.specializations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: therapist.specializations.take(3).map((spec) {
                  return Chip(
                    label: Text(spec),
                    labelStyle: const TextStyle(fontSize: 11),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // TODO: View therapist profile
                  },
                  child: const Text('View Profile'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _bookAppointment(context),
                  child: const Text('Book Session'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookAppointment(BuildContext context) async {
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    AppointmentType selectedType = AppointmentType.text;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Book Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AppointmentType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Session Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AppointmentType.text,
                      child: Text('Text Chat'),
                    ),
                    DropdownMenuItem(
                      value: AppointmentType.audio,
                      child: Text('Audio Call'),
                    ),
                    DropdownMenuItem(
                      value: AppointmentType.video,
                      child: Text('Video Call'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (date != null) {
                      dateController.text = date.toString().split(' ')[0];
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      timeController.text = time.format(context);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (dateController.text.isNotEmpty && timeController.text.isNotEmpty) {
                  await _createAppointment(
                    context,
                    dateController.text,
                    timeController.text,
                    selectedType,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAppointment(
    BuildContext context,
    String dateStr,
    String timeStr,
    AppointmentType type,
  ) async {
    try {
      final firestoreService = Provider.of<MockFirestoreService>(context, listen: false);
      
      // Parse date and time
      final date = DateTime.parse(dateStr);
      final timeParts = timeStr.split(':');
      final scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1].split(' ')[0]),
      );

      final appointment = AppointmentModel(
        id: const Uuid().v4(),
        userId: userId,
        therapistId: therapist.id,
        scheduledTime: scheduledTime,
        status: AppointmentStatus.scheduled,
        type: type,
      );

      await firestoreService.saveAppointment(appointment);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment booked successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking appointment: ${e.toString()}')),
        );
      }
    }
  }
}

class _AppointmentsList extends StatelessWidget {
  final String userId;

  const _AppointmentsList({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppointmentModel>>(
      stream: Provider.of<MockFirestoreService>(context).getUserAppointments(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No appointments scheduled',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final appointments = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            return _AppointmentCard(appointment: appointments[index]);
          },
        );
      },
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
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
                  appointment.scheduledTime.toString().split('.')[0],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  appointment.type == AppointmentType.video
                      ? Icons.videocam
                      : appointment.type == AppointmentType.audio
                          ? Icons.phone
                          : Icons.chat,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  appointment.type.toString().toUpperCase(),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            if (appointment.status == AppointmentStatus.scheduled) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      // TODO: Cancel appointment
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Join session
                    },
                    child: const Text('Join Session'),
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

