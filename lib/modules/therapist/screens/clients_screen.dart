import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/appointment_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<String> _clientIds = [];
  Map<String, UserModel> _clients = {};
  Map<String, int> _sessionCounts = {};
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
      _loadClients();
    }
  }

  Future<void> _loadClients() async {
    if (_therapistId == null) return;

    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );

      // Load appointments
      final appointmentsData = await dbService.readList(
        'therapists/$_therapistId/appointments',
      );
      final appointments = appointmentsData
          .map((data) => AppointmentModel.fromMap(data))
          .toList();

      // Get unique client IDs
      final clientIds = appointments.map((a) => a.userId).toSet().toList();

      // Load client data
      final clients = <String, UserModel>{};
      final sessionCounts = <String, int>{};

      for (final clientId in clientIds) {
        final userData = await dbService.readData('users/$clientId');
        if (userData != null) {
          clients[clientId] = UserModel.fromMap(userData);
        }
        sessionCounts[clientId] = appointments
            .where((a) => a.userId == clientId)
            .length;
      }

      setState(() {
        _clientIds = clientIds;
        _clients = clients;
        _sessionCounts = sessionCounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Clients', style: TextStyle(color: Colors.white)),
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
            : _clientIds.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.white60),
                    const SizedBox(height: 16),
                    Text(
                      'No clients yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadClients,
                color: Colors.white,
                backgroundColor: Colors.white24,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                  itemCount: _clientIds.length,
                  itemBuilder: (context, index) {
                    final clientId = _clientIds[index];
                    final client = _clients[clientId];
                    final sessionCount = _sessionCounts[clientId] ?? 0;

                    if (client == null) return const SizedBox.shrink();

                    return _ClientCard(
                      client: client,
                      sessionCount: sessionCount,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final UserModel client;
  final int sessionCount;

  const _ClientCard({required this.client, required this.sessionCount});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      opacity: 0.2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white24,
          child: client.profileImageUrl != null
              ? ClipOval(child: Image.network(client.profileImageUrl!))
              : const Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          client.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          '$sessionCount session${sessionCount != 1 ? 's' : ''}',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.white60,
        ),
        onTap: () {
          // TODO: Navigate to client details
        },
      ),
    );
  }
}
