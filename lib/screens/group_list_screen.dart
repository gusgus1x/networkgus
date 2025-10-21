import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../models/group_model.dart';
import 'group_detail_screen.dart';
import '../providers/auth_provider.dart';

class _CreateGroupDialog extends StatefulWidget {
  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Group'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Group Name'),
              validator: (value) => value == null || value.isEmpty ? 'Enter group name' : null,
              onChanged: (value) => setState(() => _name = value),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (value) => setState(() => _description = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              final groupProvider = Provider.of<GroupProvider>(context, listen: false);
              final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';
              await groupProvider.createGroup(
                Group(
                  id: '', // Firestore will generate
                  name: _name,
                  description: _description,
                  ownerId: currentUserId, // set current user id
                  members: [currentUserId],
                  postIds: [],
                  createdAt: DateTime.now(),
                ),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class GroupListScreen extends StatelessWidget {
  const GroupListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    groupProvider.fetchGroups();
    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          color: theme.appBarTheme.backgroundColor,
          child: AppBar(
            backgroundColor: theme.appBarTheme.backgroundColor,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor ?? theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.group, color: theme.colorScheme.onSurface, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Groups', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: Consumer<GroupProvider>(
          builder: (context, groupProvider, child) {
            if (groupProvider.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: theme.shadowColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Loading groups...', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }
            if (groupProvider.groups.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: theme.dividerColor, width: 1),
                      ),
                      child: Icon(Icons.group_outlined, size: 56, color: theme.hintColor),
                    ),
                    const SizedBox(height: 32),
                    Text('No groups yet', style: theme.textTheme.headlineSmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text('Create a new group to get started!', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: groupProvider.groups.length,
              itemBuilder: (context, index) {
                final group = groupProvider.groups[index];
                return AnimatedContainer(
                  duration: Duration(milliseconds: 100 + (index * 50)),
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupDetailScreen(group: group),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF2A2A2A),
                            backgroundImage: (group.imageUrl != null && group.imageUrl!.isNotEmpty)
                                ? NetworkImage(group.imageUrl!)
                                : null,
                            child: (group.imageUrl == null || group.imageUrl!.isEmpty)
                                ? const Icon(Icons.group, color: Colors.white70)
                                : null,
                          ),
                          title: Text(group.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                          subtitle: Text(group.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6), borderRadius: BorderRadius.circular(14)),
                                child: Row(
                                  children: [
                                    Icon(Icons.people, color: Theme.of(context).hintColor, size: 16),
                                    const SizedBox(width: 4),
                                    Text('${group.members.length}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios, size: 18, color: Theme.of(context).hintColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => _CreateGroupDialog(),
          );
        },
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
      ),
    );
  }
}
