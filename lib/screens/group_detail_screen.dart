import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/group_model.dart';
import '../providers/posts_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_dialog.dart';
import '../services/cloudinary_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late Group _group;
  bool _updatingImage = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      final refreshed = await groupProvider.getGroupById(_group.id);
      if (refreshed != null) {
        setState(() => _group = refreshed);
        await postsProvider.fetchGroupPostsByPostIds(refreshed.postIds);
      } else {
        await postsProvider.fetchGroupPostsByPostIds(_group.postIds);
      }
    });
  }

  Future<void> _pickAndUploadGroupImage() async {
    try {
      setState(() => _updatingImage = true);
      Uint8List? bytes;
      String filename = 'group.jpg';
      if (kIsWeb) {
        final picker = ImagePicker();
        final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
        if (x == null) return;
        bytes = await x.readAsBytes();
        filename = x.name;
      } else {
        final platform = Theme.of(context).platform;
        final isDesktop = platform == TargetPlatform.windows || platform == TargetPlatform.linux || platform == TargetPlatform.macOS;
        if (isDesktop) {
          final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
          if (res == null) return;
          final file = res.files.single;
          if (file.bytes == null) return;
          bytes = file.bytes!;
          filename = file.name;
        } else {
          final picker = ImagePicker();
          final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
          if (x == null) return;
          bytes = await x.readAsBytes();
          filename = x.name;
        }
      }
      if (bytes == null) return;

      final cloudinary = CloudinaryService(folder: 'networkgus/groups');
      final url = await cloudinary.uploadImageBytes(bytes, filename: filename);
      await Provider.of<GroupProvider>(context, listen: false).updateGroupImageUrl(_group.id, url);
      if (mounted) setState(() => _group = Group(
        id: _group.id,
        name: _group.name,
        description: _group.description,
        ownerId: _group.ownerId,
        members: _group.members,
        postIds: _group.postIds,
        createdAt: _group.createdAt,
        imageUrl: url,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group photo updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update group photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _updatingImage = false);
    }
  }

  Future<void> _editGroupName() async {
    final controller = TextEditingController(text: _group.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Group name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      final newName = controller.text.trim();
      if (newName.isEmpty) return;
      await Provider.of<GroupProvider>(context, listen: false).updateGroupName(_group.id, newName);
      if (mounted) setState(() => _group = Group(
        id: _group.id,
        name: newName,
        description: _group.description,
        ownerId: _group.ownerId,
        members: _group.members,
        postIds: _group.postIds,
        createdAt: _group.createdAt,
        imageUrl: _group.imageUrl,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    final isOwner = currentUserId == _group.ownerId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
            ),
            actions: isOwner
                ? [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      tooltip: 'Edit Group Name',
                      onPressed: _editGroupName,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      tooltip: 'Delete Group',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Group'),
                            content: const Text('Are you sure you want to delete this group? This action cannot be undone.'),
                            actions: [
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () => Navigator.of(ctx).pop(false),
                              ),
                              ElevatedButton(
                                child: const Text('Delete'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.of(ctx).pop(true),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await Provider.of<GroupProvider>(context, listen: false).deleteGroup(_group.id);
                          if (mounted) Navigator.of(context).pop();
                        }
                      },
                    )
                  ]
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image if available, fallback to gradient
                  if (_group.imageUrl != null && _group.imageUrl!.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        _group.imageUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  // Dark overlay for readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.35),
                          Colors.black.withOpacity(0.25),
                          Colors.black.withOpacity(0.45),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.white,
                                backgroundImage: _group.imageUrl != null && _group.imageUrl!.isNotEmpty
                                    ? NetworkImage(_group.imageUrl!)
                                    : null,
                                child: (_group.imageUrl == null || _group.imageUrl!.isEmpty)
                                    ? const Icon(Icons.group, color: Color(0xFF6C5CE7), size: 40)
                                    : null,
                              ),
                              if (isOwner)
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Material(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: _updatingImage ? null : _pickAndUploadGroupImage,
                                      child: Padding(
                                        padding: const EdgeInsets.all(6.0),
                                        child: _updatingImage
                                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                            : const Icon(Icons.camera_alt, color: Color(0xFF6C5CE7), size: 16),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _group.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 26,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (_group.description.isNotEmpty)
                                  Text(
                                    _group.description,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, color: Colors.indigo.shade600, size: 18),
                        const SizedBox(width: 6),
                        Text('${_group.members.length} members', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo.shade700)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _group.members.contains(currentUserId) ? Colors.redAccent : Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: Icon(_group.members.contains(currentUserId) ? Icons.logout : Icons.add),
                    label: Text(_group.members.contains(currentUserId) ? 'Leave Group' : 'Join Group'),
                    onPressed: () async {
                      if (currentUserId == null) return;
                      final gp = Provider.of<GroupProvider>(context, listen: false);
                      if (_group.members.contains(currentUserId)) {
                        await gp.leaveGroup(_group.id, currentUserId);
                      } else {
                        await gp.joinGroup(_group.id, currentUserId);
                      }
                      final refreshed = await gp.getGroupById(_group.id);
                      if (refreshed != null && mounted) setState(() => _group = refreshed);
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('Posts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Create Post'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => CreatePostDialog(groupId: _group.id),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Consumer<PostsProvider>(
            builder: (context, postsProvider, child) {
              final groupPosts = postsProvider.groupPosts;
              if (groupPosts.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: const Center(child: Text('No posts in this group yet', style: TextStyle(color: Colors.grey))),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = groupPosts[index];
                    return PostCard(post: post);
                  },
                  childCount: groupPosts.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
