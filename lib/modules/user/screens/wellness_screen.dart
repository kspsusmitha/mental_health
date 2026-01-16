import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/realtime_database_service.dart';
import '../../../models/wellness_resource_model.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<WellnessResourceModel> _allResources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadResources();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final resourcesData = await dbService.readList('wellness_resources');
      
      setState(() {
        _allResources = resourcesData
            .map((data) => WellnessResourceModel.fromMap(data))
            .where((r) => r.isApproved)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<WellnessResourceModel> _getFilteredResources(ResourceType? type) {
    if (type == null) return _allResources;
    return _allResources.where((r) => r.type == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellness Resources'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.all_inclusive), text: 'All'),
            Tab(icon: Icon(Icons.self_improvement), text: 'Meditation'),
            Tab(icon: Icon(Icons.video_library), text: 'Videos'),
            Tab(icon: Icon(Icons.audiotrack), text: 'Audio'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _WellnessResourceList(resources: _getFilteredResources(null)),
                _WellnessResourceList(resources: _getFilteredResources(ResourceType.meditation)),
                _WellnessResourceList(resources: _getFilteredResources(ResourceType.video)),
                _WellnessResourceList(resources: _getFilteredResources(ResourceType.audio)),
              ],
            ),
    );
  }
}

class _WellnessResourceList extends StatelessWidget {
  final List<WellnessResourceModel> resources;

  const _WellnessResourceList({required this.resources});

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.spa_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No wellness resources available', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: resources.length,
        itemBuilder: (context, index) => _WellnessResourceCard(resource: resources[index]),
      ),
    );
  }
}

class _WellnessResourceCard extends StatelessWidget {
  final WellnessResourceModel resource;

  const _WellnessResourceCard({required this.resource});

  @override
  Widget build(BuildContext context) {
    final icons = {
      ResourceType.meditation: Icons.self_improvement,
      ResourceType.video: Icons.video_library,
      ResourceType.audio: Icons.audiotrack,
      ResourceType.article: Icons.article,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening ${resource.title}...')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icons[resource.type] ?? Icons.spa,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resource.description,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (resource.duration > 0) ...[
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('${resource.duration} min', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          const SizedBox(width: 16),
                        ],
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(resource.rating.toStringAsFixed(1), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

