import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/realtime_database_service.dart';
import '../../../models/user_model.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final usersData = await dbService.readList('users');
      
      setState(() {
        _users = usersData
            .map((data) => UserModel.fromMap(data))
            .where((u) => u.userType == UserType.user)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
        await dbService.deleteData('users/$userId');
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting user: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No users found', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) => _UserCard(
                      user: _users[index],
                      onDelete: () => _deleteUser(_users[index].id),
                    ),
                  ),
                ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onDelete;

  const _UserCard({required this.user, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: user.profileImageUrl != null
              ? ClipOval(child: Image.network(user.profileImageUrl!))
              : Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(user.email),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

