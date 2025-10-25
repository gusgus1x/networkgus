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
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';
      await groupProvider.createGroup(
        Group(
          id: '',
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          ownerId: currentUserId,
          members: [currentUserId],
          postIds: [],
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(16);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.dividerColor),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Create Group',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: _submitting ? null : () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      filled: true,
                      isDense: true,
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: inputBorder.copyWith(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    maxLength: 40,
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter group name' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      filled: true,
                      isDense: true,
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: inputBorder.copyWith(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                      ),
                    ),
                    maxLines: 3,
                    minLines: 2,
                    maxLength: 140,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: _submitting ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: _submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Create'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
