import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/posts_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/fb_create_post_dialog.dart';
import '../widgets/post_composer.dart';
import 'user_profile_screen.dart';
import 'search_screen.dart';
import 'chat_list_screen.dart';
import 'group_list_screen.dart';
// Removed theme toggle from AppBar actions

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUser?.id;
      print('HomeScreen: Current user ID: $currentUserId'); // Debug
      print('HomeScreen: Is logged in: ${authProvider.isLoggedIn}'); // Debug
      
      if (currentUserId != null) {
        // Start listening to real-time posts stream
        context.read<PostsProvider>().startListeningToPosts(currentUserId);
      }
    });

    // Add scroll listener for infinite scroll (but prevent duplicates)
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        final authProvider = context.read<AuthProvider>();
        final currentUserId = authProvider.currentUser?.id;
        if (currentUserId != null) {
          context.read<PostsProvider>().fetchPosts(currentUserId: currentUserId);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Stop listening to posts stream when leaving home screen
    context.read<PostsProvider>().stopListeningToPosts();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildFeedTab() {
    return RefreshIndicator(
      onRefresh: () async {
        final authProvider = context.read<AuthProvider>();
        final currentUserId = authProvider.currentUser?.id;
        if (currentUserId != null) {
          // Restart the posts stream for refresh
          context.read<PostsProvider>().stopListeningToPosts();
          context.read<PostsProvider>().startListeningToPosts(currentUserId);
        }
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Inline composer at top like Facebook
          SliverToBoxAdapter(
            child: const PostComposer(),
          ),
          // Posts Feed
          Consumer<PostsProvider>(
            builder: (context, postsProvider, child) {
              if (postsProvider.posts.isEmpty && postsProvider.isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (postsProvider.posts.isEmpty && !postsProvider.isLoading) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.photo_camera_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Welcome to Social Network!',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start by creating your first post or follow some people.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const FBCreatePostDialog(),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Post'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == postsProvider.posts.length) {
                      // Loading indicator at the bottom for infinite scroll
                      return postsProvider.hasMore
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : const SizedBox.shrink();
                    }

                    final post = postsProvider.posts[index];
                    // ไม่แสดงโพสต์กลุ่มในหน้า home
                    if (post.groupId != null && post.groupId!.isNotEmpty) {
                      return const SizedBox.shrink();
                    }
                    return PostCard(post: post);
                  },
                  childCount: postsProvider.posts.length + (postsProvider.hasMore ? 1 : 0),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return ChatListScreen();
  }

  Widget _buildSearchTab() {
    return const SearchScreen();
  }

  Widget _buildProfileTab() {
    return const UserProfileScreen(); // null userId means current user's profile
  }

  Widget _buildGroupTab() {
  return GroupListScreen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.camera_alt_outlined, color: theme.colorScheme.onPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Text('SocialNetwork', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ],
        ),
        // Remove actions to avoid overflow on compact screens
        actions: const [],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildFeedTab(),
          _buildSearchTab(),
          _buildGroupTab(),
          _buildChatTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final unreadCount = chatProvider.totalUnreadCount;
          
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black.withOpacity(0.05)
                      : Colors.black.withOpacity(0.3),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor ?? const Color(0xFF6C5CE7),
              unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor ?? Colors.grey.shade600,
              elevation: 0,
            items: <BottomNavigationBarItem>[
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Search',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: 'Group',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.chat_bubble_outline),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Chat',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            ),
          );
        },
      ),
    );
  }
}
