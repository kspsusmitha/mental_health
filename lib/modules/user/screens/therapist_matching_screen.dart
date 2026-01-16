import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/therapist_model.dart';
import '../../../models/appointment_model.dart';
import 'package:uuid/uuid.dart';

class TherapistMatchingScreen extends StatefulWidget {
  const TherapistMatchingScreen({super.key});

  @override
  State<TherapistMatchingScreen> createState() => _TherapistMatchingScreenState();
}

class _TherapistMatchingScreenState extends State<TherapistMatchingScreen> {
  List<TherapistModel> _therapists = [];
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
      setState(() => _currentUserId = user.id);
      _loadTherapists();
    }
  }

  Future<void> _loadTherapists() async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final therapistsData = await dbService.readList('therapists');
      
      setState(() {
        _therapists = therapistsData
            .map((data) => TherapistModel.fromMap(data))
            .where((t) => t.isVerified)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _bookAppointment(TherapistModel therapist) async {
    if (_currentUserId == null) return;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (selectedDate == null) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime == null) return;

    final appointmentDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;
      
      final appointment = AppointmentModel(
        id: const Uuid().v4(),
        userId: _currentUserId!,
        therapistId: therapist.id,
        scheduledTime: appointmentDateTime,
        status: AppointmentStatus.scheduled,
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
          const SnackBar(content: Text('Appointment booked successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking appointment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Therapist'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _therapists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No therapists available', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTherapists,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _therapists.length,
                    itemBuilder: (context, index) => _TherapistCard(
                      therapist: _therapists[index],
                      onBook: () => _bookAppointment(_therapists[index]),
                    ),
                  ),
                ),
    );
  }
}

class _TherapistCard extends StatelessWidget {
  final TherapistModel therapist;
  final VoidCallback onBook;

  const _TherapistCard({required this.therapist, required this.onBook});

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
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: therapist.profileImageUrl != null
                      ? ClipOval(child: Image.network(therapist.profileImageUrl!))
                      : Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${therapist.rating.toStringAsFixed(1)} (${therapist.totalSessions} sessions)',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
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
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
              child: const Text('Book Appointment'),
            ),
          ],
        ),
      ),
    );
  }
}

