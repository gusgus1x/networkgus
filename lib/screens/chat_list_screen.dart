import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/conversation_tile.dart';
import 'chat_screen.dart';
import 'search_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<dynamic> _filteredConversations = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_performSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      
      if (authProvider.user?.uid != null) {
        chatProvider.startListeningToConversations(authProvider.user!.uid);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final chatProvider = context.read<ChatProvider>();
    final query = _searchController.text.toLowerCase();
    
    if (query.isEmpty) {
      setState(() {
        _filteredConversations = [];
      });
      return;
    }

    setState(() {
      _filteredConversations = chatProvider.conversations.where((conversation) {
        final currentUserId = context.read<AuthProvider>().user?.uid ?? '1';
        final displayName = conversation.getDisplayName(currentUserId).toLowerCase();
        return displayName.contains(query);
      }).toList();
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _filteredConversations = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: theme.appBarTheme.backgroundColor,
          child: AppBar(
            backgroundColor: theme.appBarTheme.backgroundColor,
            elevation: 0,
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(0.0, 0.3), end: Offset.zero),
                  ),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _isSearching
                  ? Container(
                      key: const ValueKey('search'),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.inputDecorationTheme.fillColor ?? theme.cardColor,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: theme.dividerColor, width: 1),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search conversations...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                          prefixIcon: Icon(Icons.search, color: theme.hintColor, size: 22),
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : Text(
                      'Messages',
                      key: const ValueKey('title'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
            ),
            actions: [
              if (_isSearching)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor ?? theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 22),
                    onPressed: _stopSearch,
                    color: theme.colorScheme.onSurface,
                    tooltip: 'Clear search',
                  ),
                )
              else ...[
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor ?? theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.search_rounded, size: 22),
                    onPressed: _startSearch,
                    color: theme.colorScheme.onSurface,
                    tooltip: 'Search conversations',
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor ?? theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chat_bubble_rounded, size: 22),
                    onPressed: () => _showNewChatDialog(),
                    color: theme.colorScheme.onSurface,
                    tooltip: 'New conversation',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isSearching && _searchController.text.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: theme.inputDecorationTheme.fillColor ?? theme.cardColor, borderRadius: BorderRadius.circular(20)),
                    child: Icon(Icons.search_rounded, size: 16, color: theme.hintColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_filteredConversations.length} result${_filteredConversations.length != 1 ? 's' : ''} for "${_searchController.text}"',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoading && chatProvider.conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade100,
                                Colors.indigo.shade100,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Loading conversations...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final conversationsToShow = _isSearching && _searchController.text.isNotEmpty
                    ? _filteredConversations
                    : chatProvider.conversations;

                if (conversationsToShow.isEmpty) {
                  if (_isSearching && _searchController.text.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade100,
                                  Colors.red.shade100,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Colors.orange.shade600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No conversations found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade100,
                                Colors.indigo.shade100,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 56,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Start a new chat to begin messaging!',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.indigo.shade500,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade200.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            '👆 Tap the compose button above',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    final authProvider = context.read<AuthProvider>();
                    if (authProvider.user?.uid != null) {
                      chatProvider.startListeningToConversations(authProvider.user!.uid);
                    }
                  },
                  color: Colors.blue.shade400,
                  backgroundColor: Colors.grey.shade100,
                  child: ListView.builder(
                    itemCount: conversationsToShow.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemBuilder: (context, index) {
                      final conversation = conversationsToShow[index];
                      return Dismissible(
                        key: Key('conv_${conversation.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) => _confirmDeleteDialog(),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Icon(Icons.delete, color: Colors.red.shade700),
                        ),
                        onDismissed: (_) => _performDelete(conversation.id),
                        child: AnimatedContainer(
                        duration: Duration(milliseconds: 100 + (index * 50)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Theme.of(context).dividerColor, width: 1),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      conversationId: conversation.id,
                                      conversationName: conversation.getDisplayName(currentUser?.id ?? '1'),
                                    ),
                                  ),
                                );
                              },
                              onLongPress: () => _showConversationOptions(conversation),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: ConversationTile(
                                  conversation: conversation,
                                  currentUserId: currentUser?.id ?? '1',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          conversationId: conversation.id,
                                          conversationName: conversation.getDisplayName(currentUser?.id ?? '1'),
                                        ),
                                      ),
                                    );
                                  },
                                  onLongPress: () => _showConversationOptions(conversation),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Removed compose FAB per request
    );
  }

  void _showNewChatDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          isSelectionMode: true,
          onUserSelected: (selectedUser) async {
            Navigator.pop(context); // Close search screen
            
            final authProvider = context.read<AuthProvider>();
            final chatProvider = context.read<ChatProvider>();
            final currentUser = authProvider.user;
            
            if (currentUser != null) {
              try {
                // Create or get existing conversation
                final conversationId = await chatProvider.createOrGetConversation(
                  currentUser.uid,
                  selectedUser.id,
                );
                
                // Check if widget is still mounted before using context
                if (mounted) {
                  // Navigate to chat screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        conversationId: conversationId,
                        conversationName: selectedUser.displayName,
                        targetUserId: selectedUser.id,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not start chat: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
        ),
      ),
    );
  }

  void _showConversationOptions(conversation) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                conversation.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(conversation.isPinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      conversation.isPinned ? 'Conversation unpinned' : 'Conversation pinned',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                conversation.isMuted ? Icons.notifications : Icons.notifications_off,
              ),
              title: Text(conversation.isMuted ? 'Unmute' : 'Mute'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      conversation.isMuted ? 'Conversation unmuted' : 'Conversation muted',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(conversation);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = context.read<AuthProvider>();
              final chatProvider = context.read<ChatProvider>();
              final userId = authProvider.user?.uid;
              if (userId == null) return;
              try {
                await chatProvider.deleteConversation(conversation.id, userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversation deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _performDelete(String conversationId) async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final userId = authProvider.user?.uid ?? authProvider.currentUser?.id;
    if (userId == null) return;
    try {
      await chatProvider.deleteConversation(conversationId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}
