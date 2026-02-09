import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/therapist_model.dart';
import '../../../models/appointment_model.dart';
import '../../../models/review_model.dart';
import 'package:uuid/uuid.dart';

class TherapistMatchingScreen extends StatefulWidget {
  const TherapistMatchingScreen({super.key});

  @override
  State<TherapistMatchingScreen> createState() =>
      _TherapistMatchingScreenState();
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
      if (mounted) {
        setState(() => _currentUserId = user.id);
      }
      _loadTherapists();
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

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (selectedDate == null) return;

    if (!mounted) return;

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

  void _showReviews(TherapistModel therapist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Reviews for ${therapist.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ReviewModel>>(
                future: _fetchReviews(therapist.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final reviews = snapshot.data ?? [];
                  if (reviews.isEmpty) {
                    return const Center(child: Text('No reviews yet'));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      return Card(
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
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(5, (starIndex) {
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
                              Text(review.comment),
                              const SizedBox(height: 4),
                              Text(
                                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                                style: TextStyle(
                                  color: Colors.grey[500],
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
      appBar: AppBar(title: const Text('Find a Therapist')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _therapists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No therapists available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
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
                  onSeeReviews: () => _showReviews(_therapists[index]),
                ),
              ),
            ),
    );
  }
}

class _TherapistCard extends StatelessWidget {
  final TherapistModel therapist;
  final VoidCallback onBook;
  final VoidCallback onSeeReviews;

  const _TherapistCard({
    required this.therapist,
    required this.onBook,
    required this.onSeeReviews,
  });

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
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  child: therapist.profileImageUrl != null
                      ? ClipOval(
                          child: Image.network(therapist.profileImageUrl!),
                        )
                      : Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${therapist.rating.toStringAsFixed(1)} (${therapist.totalSessions} sessions)',
                            style: TextStyle(
                              color: Colors.grey[600],
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSeeReviews,
                    child: const Text('Reviews'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onBook,
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
}
