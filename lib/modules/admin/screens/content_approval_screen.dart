import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/wellness_resource_model.dart';
import '../../../models/community_post_model.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

class ContentApprovalScreen extends StatefulWidget {
  const ContentApprovalScreen({super.key});

  @override
  State<ContentApprovalScreen> createState() => _ContentApprovalScreenState();
}

class _ContentApprovalScreenState extends State<ContentApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<WellnessResourceModel> _pendingResources = [];
  List<CommunityPostModel> _pendingPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPendingContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingContent() async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );

      // Load Resources
      final resourcesData = await dbService.readList('wellness_resources');

      // Load Posts
      final postsData = await dbService.readList('community_posts');

      setState(() {
        _pendingResources = resourcesData
            .map((data) => WellnessResourceModel.fromMap(data))
            .where((r) => !r.isApproved)
            .toList();

        _pendingPosts = postsData
            .map((data) => CommunityPostModel.fromMap(data))
            .where((p) => !p.isApproved)
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

      _loadPendingContent();

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

  Future<void> _approvePost(String postId, bool approve) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminId = authService.currentUser?.id ?? '';

      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      await dbService.updateData('community_posts/$postId', {
        'isApproved': approve,
        'approvedBy': approve ? adminId : null,
        'approvedAt': approve ? DateTime.now().millisecondsSinceEpoch : null,
      });

      _loadPendingContent();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Post approved' : 'Post rejected')),
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
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black45,
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: 'Resources (${_pendingResources.length})'),
            Tab(text: 'Community (${_pendingPosts.length})'),
          ],
        ),
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1499728603263-137ad9fdef1f?auto=format&fit=crop&q=80',
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [_buildResourcesList(), _buildPostsList()],
              ),
      ),
    );
  }

  Widget _buildResourcesList() {
    if (_pendingResources.isEmpty) {
      return _buildEmptyState('No pending resources');
    }
    return RefreshIndicator(
      onRefresh: _loadPendingContent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 140, 16, 16),
        itemCount: _pendingResources.length,
        itemBuilder: (context, index) => _ResourceCard(
          resource: _pendingResources[index],
          onApprove: () => _approveResource(_pendingResources[index].id, true),
          onReject: () => _approveResource(_pendingResources[index].id, false),
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    if (_pendingPosts.isEmpty) {
      return _buildEmptyState('No pending posts');
    }
    return RefreshIndicator(
      onRefresh: _loadPendingContent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 140, 16, 16),
        itemCount: _pendingPosts.length,
        itemBuilder: (context, index) => _PostCard(
          post: _pendingPosts[index],
          onApprove: () => _approvePost(_pendingPosts[index].id, true),
          onReject: () => _approvePost(_pendingPosts[index].id, false),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.approval_outlined,
            size: 64,
            color: Colors.black.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.black.withOpacity(0.6))),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPostModel post;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PostCard({
    required this.post,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      opacity: 0.6,
      border: Border.all(color: Colors.white.withOpacity(0.2)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'COMMUNITY POST',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  post.createdAt.toString().split(' ').first,
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.black12,
                  child: post.userProfileImageUrl != null
                      ? ClipOval(
                          child: Image.network(post.userProfileImageUrl!),
                        )
                      : Text(
                          post.userName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'User Submission',
                        style: TextStyle(color: Colors.black45, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.content,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButtons(onApprove, onReject),
          ],
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
      opacity: 0.6,
      border: Border.all(color: Colors.white.withOpacity(0.2)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    resource.type.toString().toUpperCase().split('.').last,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Spacer(),
                if (resource.duration > 0)
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.black45,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${resource.duration} min',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icons[resource.type] ?? Icons.spa,
                    size: 24,
                    color: Theme.of(context).primaryColor,
                  ),
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
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Resource Content',
                        style: TextStyle(color: Colors.black45, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              resource.description,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButtons(onApprove, onReject),
          ],
        ),
      ),
    );
  }
}

Widget _buildActionButtons(VoidCallback onApprove, VoidCallback onReject) {
  return Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: onReject,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Reject'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onApprove,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Approve'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.withOpacity(0.9),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ],
  );
}
