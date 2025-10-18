import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/user_model.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool isSelectionMode;
  final Function(User)? onUserSelected;
  
  const SearchScreen({
    Key? key, 
    this.isSelectionMode = false,
    this.onUserSelected,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _searchResults = [];
  List<User> _suggestedUsers = [];
  bool _isSearching = false;
  bool _isLoadingSuggestions = true;
  DateTime _lastSearchTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuggestedUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestedUsers() async {
    try {
      final userProvider = context.read<UserProvider>();
      final suggestions = await userProvider.getSuggestedUsers();
      if (mounted) {
        setState(() {
          _suggestedUsers = suggestions;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Debounce: wait 500ms before searching
    final searchTime = DateTime.now();
    _lastSearchTime = searchTime;
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Check if this is still the latest search
    if (_lastSearchTime != searchTime) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final results = await userProvider.searchUsers(query);
      
      if (mounted && _lastSearchTime == searchTime) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted && _lastSearchTime == searchTime) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor ?? theme.cardColor,
            borderRadius: BorderRadius.circular(22.5),
            border: Border.all(color: theme.dividerColor, width: 1),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: widget.isSelectionMode 
                ? 'Search users to chat with...'
                : 'Search by name or username...',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              prefixIcon: Icon(Icons.search, color: theme.hintColor, size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: theme.hintColor, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
            ),
            style: theme.textTheme.bodyMedium,
            onChanged: _performSearch,
          ),
        ),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (_searchController.text.isNotEmpty) {
            // Show search results
            if (_isSearching) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_searchResults.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No users found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return _buildUserTile(user);
              },
            );
          } else {
            // Show suggested users when not searching
            if (_isLoadingSuggestions) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (_suggestedUsers.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Search for people',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Find friends and discover new people.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Suggested for you',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _suggestedUsers.length,
                    itemBuilder: (context, index) {
                      final user = _suggestedUsers[index];
                      return _buildUserTile(user);
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildUserTile(User user) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: UserAvatar(
          imageUrl: user.profileImageUrl,
          displayName: user.displayName,
          radius: 25,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(user.displayName, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: Color(0xFF6C5CE7), size: 16),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${user.username}', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
            if (user.bio != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(user.bio!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              ),
            const SizedBox(height: 4),
            Text('${user.followersCount} followers', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          ],
        ),
        trailing: widget.isSelectionMode 
          ? Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chat button
                IconButton(
                  icon: Icon(Icons.chat_bubble_outline, color: theme.hintColor),
                  onPressed: () => _startChat(user),
                  tooltip: 'Chat',
                  iconSize: 20,
                ),
                // Profile button
                IconButton(
                  icon: Icon(Icons.person_outline, color: theme.hintColor),
                  onPressed: () => _viewProfile(user),
                  tooltip: 'View Profile',
                  iconSize: 20,
                ),
              ],
            ),
        onTap: () {
          if (widget.isSelectionMode && widget.onUserSelected != null) {
            widget.onUserSelected!(user);
          } else {
            _viewProfile(user);
          }
        },
      ),
    );
  }

  Future<void> _startChat(User user) async {
    try {
      final currentUser = context.read<AuthProvider>().currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to start chatting')),
        );
        return;
      }

      if (currentUser.id == user.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot chat with yourself')),
        );
        return;
      }

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
        user.id,
      );

      Navigator.of(context).pop(); // Close loading dialog

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            conversationName: user.displayName,
            targetUserId: user.id,
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

  void _viewProfile(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: user.id),
      ),
    );
  }
}
