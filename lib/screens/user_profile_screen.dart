import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/posts_provider.dart';
import 'settings_screen.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../widgets/user_avatar.dart';
import '../widgets/post_card.dart';
import 'chat_screen.dart';
import '../services/post_service.dart';
import '../services/cloudinary_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String? userId; // Made optional - null means current user's profile

  const UserProfileScreen({
    Key? key,
    this.userId,
  }) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  User? _user;
  bool _isLoading = true;
  bool _isLoadingPosts = true;
  bool _isFollowing = false;
  bool _isFollowingLoading = false;
  String? _actualUserId; // Will be set in initState
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _initializeUserId();
  }

  void _initializeUserId() {
    final currentUser = context.read<AuthProvider>().currentUser;
    _actualUserId = widget.userId ?? currentUser?.id;
    
    if (_actualUserId != null) {
      _loadUserProfile();
      _loadUserPosts();
    } else {
      setState(() {
        _isLoading = false;
        _isLoadingPosts = false;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    if (_actualUserId == null) return;
    
    try {
      final currentUser = context.read<AuthProvider>().currentUser;
      
      // If viewing own profile, use current user data
      if (widget.userId == null && currentUser != null) {
        setState(() {
          _user = currentUser;
          _isLoading = false;
        });
        return;
      }
      
      // Otherwise, fetch user data
      final userProvider = context.read<UserProvider>();
      final user = await userProvider.getUserById(_actualUserId!);
      
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
        
        // Check if current user is following this user (only for other users)
        if (widget.userId != null) {
          _checkFollowStatus();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _loadUserPosts() async {
    if (_actualUserId == null) return;

    if (mounted) {
      setState(() => _isLoadingPosts = true);
    }

    try {
      await context.read<PostsProvider>().getUserPosts(_actualUserId!);
    } finally {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  Future<void> _checkFollowStatus() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null || _actualUserId == null) return;

    try {
      final userProvider = context.read<UserProvider>();
      final isFollowing = await userProvider.isFollowing(currentUser.id, _actualUserId!);
      
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error checking follow status: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null || _user == null) return;

    setState(() {
      _isFollowingLoading = true;
    });

    try {
      final userProvider = context.read<UserProvider>();
      
      if (_isFollowing) {
        await userProvider.unfollowUser(currentUser.id, _user!.id);
      } else {
        await userProvider.followUser(currentUser.id, _user!.id);
      }

      setState(() {
        _isFollowing = !_isFollowing;
        if (_user != null) {
          _user = _user!.copyWith(
            followersCount: _isFollowing 
                ? _user!.followersCount + 1
                : _user!.followersCount - 1,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFollowing ? 'Following ${_user!.displayName}' : 'Unfollowed ${_user!.displayName}'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to ${_isFollowing ? 'unfollow' : 'follow'}: $e')),
      );
    } finally {
      setState(() {
        _isFollowingLoading = false;
      });
    }
  }

  Future<void> _startChat() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null || _user == null) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Create or get existing conversation
      final conversationId = await context.read<ChatProvider>().createOrGetConversation(
        currentUser.id,
        _user!.id,
      );

      Navigator.of(context).pop(); // Close loading dialog

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            conversationName: _user!.displayName,
            targetUserId: _user!.id,
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final isOwnProfile = widget.userId == null || currentUser?.id == widget.userId;

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Text(
              _user?.username ?? 'Profile',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (_user?.isVerified == true) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.verified,
                color: theme.colorScheme.primary,
                size: 18,
              ),
            ],
          ],
        ),
        iconTheme: theme.iconTheme,
        actions: isOwnProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'User not found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadUserProfile();
                    await _loadUserPosts();
                  },
                  child: Column(
                    children: [
                      // Profile Header
                      _buildProfileHeader(isOwnProfile),
                      
                      // Posts Section
                      Expanded(
                        child: _actualUserId == null
                            ? const SizedBox.shrink()
                            : StreamBuilder<List<Post>>(
                                stream: PostService().getUserPostsStream(
                                  _actualUserId!,
                                  context.read<AuthProvider>().currentUser?.id ?? '',
                                  limit: 50,
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting && _isLoadingPosts) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  final posts = snapshot.data ?? [];
                                  if (posts.isEmpty) {
                                    return const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.photo_camera_outlined,
                                            size: 64,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'No posts yet',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'No posts to show.',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    itemCount: posts.length,
                                    itemBuilder: (context, index) {
                                      return PostCard(post: posts[index]);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader(bool isOwnProfile) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile picture and stats
          Row(
            children: [
              // Profile picture with Instagram-like border
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _user!.isVerified 
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF833AB4),
                            Color(0xFFE1306C),
                            Color(0xFFFA7E1E),
                          ],
                        )
                      : null,
                  color: _user!.isVerified ? null : Colors.grey.shade600,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF121212),
                  ),
                  child: UserAvatar(
                    imageUrl: _user!.profileImageUrl,
                    displayName: _user!.displayName,
                    radius: 40,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn('Posts', _user!.postsCount.toString()),
                    _buildStatColumn('Followers', _formatNumber(_user!.followersCount)),
                    _buildStatColumn('Following', _user!.followingCount.toString()),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Name and bio
          Text(
            _user!.displayName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (_user!.bio != null && _user!.bio!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _user!.bio!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons
          if (isOwnProfile) ...[
            // Edit Profile button for own profile (share button removed)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/edit-profile');
                      if (mounted) _loadUserProfile();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Follow and Message buttons for other users
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isFollowingLoading ? null : _toggleFollow,
                    icon: _isFollowingLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isFollowing ? Icons.person_remove : Icons.person_add),
                    label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFollowing ? Theme.of(context).colorScheme.surfaceVariant : Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startChat,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Posts grid tab bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_on, color: Theme.of(context).iconTheme.color, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Posts',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 14, color: theme.hintColor),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '${(number / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
  }

  void _showEditProfileDialog(BuildContext context) {
    if (_user == null) return;
    
    final displayNameController = TextEditingController(text: _user!.displayName);
    final bioController = TextEditingController(text: _user!.bio ?? '');

    final theme = Theme.of(context);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.dividerColor),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Edit Profile', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    UserAvatar(imageUrl: _user!.profileImageUrl, displayName: _user!.displayName, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploadingAvatar ? null : () => _changeProfilePhoto(dialogContext),
                        icon: _isUploadingAvatar
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.image_outlined, size: 18),
                        label: Text(_isUploadingAvatar ? 'Uploading...' : 'Change photo'),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                          foregroundColor: theme.colorScheme.onSurface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Display Name', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 6),
                TextField(
                  controller: displayNameController,
                  maxLength: 50,
                  decoration: InputDecoration(
                    hintText: 'Display Name',
                    counterText: '',
                    filled: true,
                    isDense: true,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: inputBorder.copyWith(
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Bio', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 6),
                TextField(
                  controller: bioController,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'Tell people about you',
                    counterText: '',
                    filled: true,
                    isDense: true,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: inputBorder.copyWith(
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (_isUploadingAvatar) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please wait until photo upload finishes')),
                          );
                          return;
                        }
                        try {
                          await context.read<AuthProvider>().updateProfile(
                            displayName: displayNameController.text.trim(),
                            bio: bioController.text.trim(),
                          );
                          Navigator.pop(dialogContext);
                          _loadUserProfile();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update profile: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeProfilePhoto(BuildContext dialogContext) async {
    try {
      setState(() => _isUploadingAvatar = true);

      late final Uint8List bytes;
      String filename = 'avatar.jpg';

      if (kIsWeb) {
        final picker = ImagePicker();
        final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
        if (x == null) return;
        bytes = await x.readAsBytes();
        filename = x.name;
      } else {
        // Use desktop file picker on desktop platforms; image_picker on mobile
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

      final cloudinary = CloudinaryService(folder: 'networkgus/avatars');
  final url = await cloudinary.uploadImageBytes(bytes, filename: filename);

      await context.read<AuthProvider>().updateProfile(profileImageUrl: url);
      if (mounted) {
        setState(() {
          _user = _user?.copyWith(profileImageUrl: url);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }
}
