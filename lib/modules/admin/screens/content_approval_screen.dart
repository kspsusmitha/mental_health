import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/wellness_resource_model.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

class ContentApprovalScreen extends StatefulWidget {
  const ContentApprovalScreen({super.key});

  @override
  State<ContentApprovalScreen> createState() => _ContentApprovalScreenState();
}

class _ContentApprovalScreenState extends State<ContentApprovalScreen> {
  List<WellnessResourceModel> _pendingResources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingResources();
  }

  Future<void> _loadPendingResources() async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final resourcesData = await dbService.readList('wellness_resources');

      setState(() {
        _pendingResources = resourcesData
            .map((data) => WellnessResourceModel.fromMap(data))
            .where((r) => !r.isApproved)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveResource(String resourceId, bool approve) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminId = authService.currentUser?.id ?? '';

      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      await dbService.updateData('wellness_resources/$resourceId', {
        'isApproved': approve,
        'approvedBy': approve ? adminId : null,
        'approvedAt': approve ? DateTime.now().millisecondsSinceEpoch : null,
      });

      _loadPendingResources();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Resource approved' : 'Resource rejected'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Content Approval',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1499728603263-137ad9fdef1f?auto=format&fit=crop&q=80',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _pendingResources.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.approval_outlined,
                      size: 64,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pending content',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadPendingResources,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                  itemCount: _pendingResources.length,
                  itemBuilder: (context, index) => _ResourceCard(
                    resource: _pendingResources[index],
                    onApprove: () =>
                        _approveResource(_pendingResources[index].id, true),
                    onReject: () =>
                        _approveResource(_pendingResources[index].id, false),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final WellnessResourceModel resource;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ResourceCard({
    required this.resource,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final icons = {
      ResourceType.meditation: Icons.self_improvement,
      ResourceType.video: Icons.video_library,
      ResourceType.audio: Icons.audiotrack,
      ResourceType.article: Icons.article,
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
              children: [
                Icon(
                  icons[resource.type] ?? Icons.spa,
                  size: 32,
                  color: Colors.white,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        resource.type.toString().toUpperCase().split('.').last,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              resource.description,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (resource.duration > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.white60,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${resource.duration} minutes',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('Approve'),
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
