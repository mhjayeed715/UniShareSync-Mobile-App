import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../communities/presentation/providers/communities_provider.dart';

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
    final nameCtrl = TextEditingController();
    final taglineCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    final paymentInstCtrl = TextEditingController();
    bool isPaid = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Community'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Community Name')),
                TextField(controller: taglineCtrl, decoration: const InputDecoration(labelText: 'Tagline')),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Requires Membership Fee?'),
                  value: isPaid,
                  onChanged: (val) {
                    setState(() {
                      isPaid = val ?? false;
                    });
                  },
                ),
                if (isPaid) ...[
                  TextField(
                    controller: feeCtrl,
                    decoration: const InputDecoration(labelText: 'Membership Fee (BDT)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: paymentInstCtrl,
                    decoration: const InputDecoration(labelText: 'Payment Instructions'),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  final payload = {
                    'name': nameCtrl.text,
                    'tagline': taglineCtrl.text,
                    'description': descCtrl.text,
                    'type': 'academic_club',
                    'join_type': isPaid ? 'request' : 'open',
                    'is_paid': isPaid,
                    'membership_fee': isPaid ? (double.tryParse(feeCtrl.text) ?? 0.0) : 0.0,
                    'payment_instructions': isPaid ? paymentInstCtrl.text : null,
                    'status': 'active',
                  };
                  await ref.read(communitiesProvider.notifier).createCommunity(payload);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Communities'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _onCreateCommunity),
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
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: comm.logoUrl != null ? NetworkImage(comm.logoUrl!) : null,
                      ),
                      title: Text(comm.name),
                      subtitle: Text(comm.tagline),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () async {
                          // Admin deletion action
                        },
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
