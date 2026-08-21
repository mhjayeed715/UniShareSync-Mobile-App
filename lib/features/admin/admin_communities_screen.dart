import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../communities/presentation/providers/communities_provider.dart';
import '../communities/presentation/screens/community_detail_screen.dart';
import '../communities/presentation/screens/community_create_edit_screen.dart';

class AdminCommunitiesScreen extends ConsumerStatefulWidget {
  const AdminCommunitiesScreen({super.key});

  @override
  ConsumerState<AdminCommunitiesScreen> createState() => _AdminCommunitiesScreenState();
}

class _AdminCommunitiesScreenState extends ConsumerState<AdminCommunitiesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communitiesProvider.notifier).fetchCommunities();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCreateCommunity() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CommunityCreateEditScreen()),
    ).then((_) {
      ref.read(communitiesProvider.notifier).fetchCommunities(search: _searchController.text);
    });
  }

  Future<void> _deleteCommunity(String communityId, String communityName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Community', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete "$communityName"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(communitiesProvider.notifier).deleteCommunity(communityId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Community deleted.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Communities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _onCreateCommunity,
            tooltip: 'Create Community',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(communitiesProvider.notifier).fetchCommunities(search: val);
              },
              decoration: const InputDecoration(
                labelText: 'Search communities...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No communities found.'));
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, idx) {
                    final comm = list[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CommunityDetailScreen(communityId: comm.id),
                            ),
                          ).then((_) {
                            ref.read(communitiesProvider.notifier).fetchCommunities(search: _searchController.text);
                          });
                        },
                        leading: CircleAvatar(
                          backgroundImage: comm.logoUrl != null ? NetworkImage(comm.logoUrl!) : null,
                          child: comm.logoUrl == null ? const Icon(Icons.groups_rounded) : null,
                        ),
                        title: Text(comm.name),
                        subtitle: Text(comm.tagline),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Color(0xFF4F9EFF)),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CommunityCreateEditScreen(existingCommunity: comm),
                                  ),
                                ).then((_) {
                                  ref.read(communitiesProvider.notifier).fetchCommunities(search: _searchController.text);
                                });
                              },
                              tooltip: 'Edit Community',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              onPressed: () => _deleteCommunity(comm.id, comm.name),
                              tooltip: 'Delete Community',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
