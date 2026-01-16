import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/realtime_database_service.dart';
import '../../../models/therapist_model.dart';

class TherapistsManagementScreen extends StatefulWidget {
  const TherapistsManagementScreen({super.key});

  @override
  State<TherapistsManagementScreen> createState() => _TherapistsManagementScreenState();
}

class _TherapistsManagementScreenState extends State<TherapistsManagementScreen> {
  List<TherapistModel> _therapists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTherapists();
  }

  Future<void> _loadTherapists() async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final therapistsData = await dbService.readList('therapists');
      
      setState(() {
        _therapists = therapistsData.map((data) => TherapistModel.fromMap(data)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleVerification(TherapistModel therapist) async {
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      await dbService.updateData(
        'therapists/${therapist.id}',
        {'isVerified': !therapist.isVerified},
      );
      _loadTherapists();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating therapist: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapists Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _therapists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No therapists found', style: TextStyle(color: Colors.grey[600])),
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
                      onToggleVerification: () => _toggleVerification(_therapists[index]),
                    ),
                  ),
                ),
    );
  }
}

class _TherapistCard extends StatelessWidget {
  final TherapistModel therapist;
  final VoidCallback onToggleVerification;

  const _TherapistCard({required this.therapist, required this.onToggleVerification});

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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              therapist.bio,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onToggleVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: therapist.isVerified ? Colors.green : Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
              child: Text(therapist.isVerified ? 'Verified' : 'Verify Therapist'),
            ),
          ],
        ),
      ),
    );
  }
}

