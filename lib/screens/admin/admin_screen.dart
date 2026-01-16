import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Users'),
              Tab(icon: Icon(Icons.verified_user), text: 'Therapists'),
              Tab(icon: Icon(Icons.video_library), text: 'Content'),
              Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            UsersManagementTab(),
            TherapistsVerificationTab(),
            ContentApprovalTab(),
            AnalyticsTab(),
          ],
        ),
      ),
    );
  }
}

class UsersManagementTab extends StatelessWidget {
  const UsersManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Total Users'),
            trailing: Text('0', style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        // TODO: Implement user list
      ],
    );
  }
}

class TherapistsVerificationTab extends StatelessWidget {
  const TherapistsVerificationTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('Pending Verifications'),
            trailing: Text('0', style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        // TODO: Implement therapist verification list
      ],
    );
  }
}

class ContentApprovalTab extends StatelessWidget {
  const ContentApprovalTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Pending Approvals'),
            trailing: Text('0', style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        // TODO: Implement content approval list
      ],
    );
  }
}

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform Statistics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildStatRow('Active Users', '0'),
                _buildStatRow('Total Sessions', '0'),
                _buildStatRow('Wellness Resources', '0'),
                _buildStatRow('Verified Therapists', '0'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

