import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/community_post_model.dart';
import '../../../models/community_comment_model.dart';
import '../../../models/user_model.dart';
import '../../../utils/page_transitions.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  List<CommunityPostModel> _posts = [];
  bool _isLoading = true;
  String? _currentUserId;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadPosts();
  }

  Future<void> _getCurrentUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
        _currentUser = user;
      });
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final postsData = await dbService.readList('community_posts');
      
      setState(() {
        _posts = postsData
            .map((data) => CommunityPostModel.fromMap(data))
            .where((post) => post.isApproved) // Only show approved posts
            .toList();
        
        // Sort by creation date (newest first)
        _posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createPost() async {
    if (_currentUserId == null || _currentUser == null) return;

    final titleController = TextEditingController();
    final contentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Post'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                maxLength: 100,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                maxLength: 1000,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty &&
                  contentController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
        final postId = const Uuid().v4();
        
        final post = CommunityPostModel(
          id: postId,
          userId: _currentUserId!,
          userName: _currentUser!.name,
          userProfileImageUrl: _currentUser!.profileImageUrl,
          title: titleController.text.trim(),
          content: contentController.text.trim(),
          createdAt: DateTime.now(),
          isApproved: false, // Needs admin approval
        );

        await dbService.writeData(
          'community_posts/$postId',
          post.toMap(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post submitted for approval'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadPosts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating post: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleLike(CommunityPostModel post) async {
    if (_currentUserId == null) return;

    final isLiked = post.likedBy.contains(_currentUserId!);
    final newLikedBy = List<String>.from(post.likedBy);
    
    if (isLiked) {
      newLikedBy.remove(_currentUserId!);
    } else {
      newLikedBy.add(_currentUserId!);
    }

    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      await dbService.updateData(
        'community_posts/${post.id}',
        {
          'likesCount': isLiked ? post.likesCount - 1 : post.likesCount + 1,
          'likedBy': newLikedBy,
        },
      );
      _loadPosts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createPost,
            tooltip: 'Create Post',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPosts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      return _buildPostCard(_posts[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your experience!',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createPost,
            icon: const Icon(Icons.add),
            label: const Text('Create Post'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(CommunityPostModel post) {
    final isLiked = _currentUserId != null && post.likedBy.contains(_currentUserId!);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showPostDetail(post),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: post.userProfileImageUrl != null
                        ? NetworkImage(post.userProfileImageUrl!)
                        : null,
                    child: post.userProfileImageUrl == null
                        ? Text(post.userName[0].toUpperCase())
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatDate(post.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                post.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              // Content (truncated)
              Text(
                post.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700]),
              ),
              if (post.content.length > 150) ...[
                const SizedBox(height: 4),
                Text(
                  'Read more...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Tags
              if (post.tags != null && post.tags!.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: post.tags!.map((tag) => Chip(
                        label: Text(
                          tag,
                          style: const TextStyle(fontSize: 12),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                ),
              const SizedBox(height: 12),
              // Actions
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => _toggleLike(post),
                  ),
                  Text('${post.likesCount}'),
                  const SizedBox(width: 24),
                  const Icon(Icons.comment_outlined, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('${post.commentsCount}'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showPostDetail(post),
                    child: const Text('View Comments'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPostDetail(CommunityPostModel post) {
    Navigator.push(
      context,
      createAnimatedRoute(PostDetailScreen(post: post)),
    ).then((_) => _loadPosts());
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class PostDetailScreen extends StatefulWidget {
  final CommunityPostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<CommunityCommentModel> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = true;
  String? _currentUserId;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
        _currentUser = user;
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final commentsData = await dbService.readList('community_posts/${widget.post.id}/comments');
      
      setState(() {
        _comments = commentsData
            .map((data) => CommunityCommentModel.fromMap(data))
            .where((comment) => comment.isApproved)
            .toList();
        
        _comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    if (_currentUserId == null || _currentUser == null) return;
    if (_commentController.text.trim().isEmpty) return;

    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final commentId = const Uuid().v4();
      
      final comment = CommunityCommentModel(
        id: commentId,
        postId: widget.post.id,
        userId: _currentUserId!,
        userName: _currentUser!.name,
        userProfileImageUrl: _currentUser!.profileImageUrl,
        content: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await dbService.writeData(
        'community_posts/${widget.post.id}/comments/$commentId',
        comment.toMap(),
      );

      // Update comment count
      await dbService.updateData(
        'community_posts/${widget.post.id}',
        {'commentsCount': widget.post.commentsCount + 1},
      );

      _commentController.clear();
      _loadComments();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
      ),
      body: Column(
        children: [
          // Post content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: widget.post.userProfileImageUrl != null
                            ? NetworkImage(widget.post.userProfileImageUrl!)
                            : null,
                        child: widget.post.userProfileImageUrl == null
                            ? Text(widget.post.userName[0].toUpperCase())
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.post.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _formatDate(widget.post.createdAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.post.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.post.content,
                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Comments section
                  Text(
                    'Comments (${_comments.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _comments.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  'No comments yet. Be the first to comment!',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            )
                          : Column(
                              children: _comments.map((comment) => _buildCommentCard(comment)).toList(),
                            ),
                ],
              ),
            ),
          ),
          // Comment input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(CommunityCommentModel comment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: comment.userProfileImageUrl != null
                  ? NetworkImage(comment.userProfileImageUrl!)
                  : null,
              child: comment.userProfileImageUrl == null
                  ? Text(comment.userName[0].toUpperCase(), style: const TextStyle(fontSize: 12))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(comment.createdAt),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
