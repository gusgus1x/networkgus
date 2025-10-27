import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Note: Avoid dart:io to keep web compatibility
import 'dart:typed_data';
import '../services/chat_service.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../widgets/message_bubble.dart';
import 'group_settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String conversationName;
  final String? targetUserId;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.conversationName,
    this.targetUserId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  // Pending media to send with optional caption
  Uint8List? _pendingImageBytes;
  String? _pendingImageName;
  Uint8List? _pendingVideoBytes;
  String? _pendingVideoName;
  // Cache sender info for avatars/names
  final Map<String, String?> _userAvatarCache = {};
  final Map<String, String> _userNameCache = {};
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>().user;
      final chatProv = context.read<ChatProvider>();
      if (auth?.uid != null && chatProv.conversations.isEmpty) {
        chatProv.startListeningToConversations(auth!.uid);
      }
      context.read<ChatProvider>().setActiveConversation(widget.conversationId);
      // Preload latest messages so the list isn't empty on first open
      context.read<ChatProvider>().preloadMessages(widget.conversationId);
      if (auth?.uid != null) {
        context.read<ChatProvider>().markAsRead(widget.conversationId, auth!.uid);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    context.read<ChatProvider>().setActiveConversation(null);
    super.dispose();
  }



  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    if (currentUser == null) return;

    _messageController.clear();
    
    try {
      String? targetUserId = widget.targetUserId;
      
      // If no targetUserId provided, try to get it from conversation
      if (targetUserId == null) {
        final conversation = context.read<ChatProvider>().getConversationById(widget.conversationId);
        if (conversation != null) {
          targetUserId = conversation.getTargetUserId(currentUser.uid);
        }
      }
      
      if (targetUserId == null) {
        throw Exception('Unable to determine target user');
      }

      await context.read<ChatProvider>().sendMessage(
        widget.conversationId,
        content,
        currentUser.uid,
        targetUserId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent'), duration: Duration(milliseconds: 800)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    
    final chatProvider = context.watch<ChatProvider>();
    final conversation = chatProvider.getConversationById(widget.conversationId);
    final resolvedTitle = () {
      if (conversation == null) return widget.conversationName;
      final uid = currentUser?.uid ?? 'unknown';
      return conversation.getDisplayName(uid);
    }();

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(resolvedTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        actions: [
          PopupMenuButton(
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showChatInfo();
                  break;
                case 'clear':
                  _showClearChatDialog();
                  break;
                case 'edit_group':
                  _openGroupSettings();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info),
                    SizedBox(width: 8),
                    Text('Chat Info'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
              if (conversation?.type == ConversationType.group)
                const PopupMenuItem(
                  value: 'edit_group',
                  child: Row(
                    children: [
                      Icon(Icons.group),
                      SizedBox(width: 8),
                      Text('Edit Group'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final messages = chatProvider.getMessages(widget.conversationId);
                // Auto-scroll when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (messages.length != _lastMessageCount) {
                    _lastMessageCount = messages.length;
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  }
                });
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Send the first message!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == (currentUser?.uid ?? 'unknown');
                    final showDateSeparator = _shouldShowDateSeparator(index, messages);
                    
                    return Column(
                      children: [
                        if (showDateSeparator)
                          _buildDateSeparator(messages[index].timestamp),
                        MessageBubble(
                          message: message,
                          isMe: isMe,
                          showAvatar: !isMe && _shouldShowAvatar(index, messages),
                          showSenderName: (conversation?.type == ConversationType.group),
                          senderName: _getSenderName(message.senderId),
                          senderImageUrl: _getSenderAvatar(message.senderId),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).cardColor
                : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black54
                  : Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? (Theme.of(context).appBarTheme.backgroundColor ?? Colors.white)
            : const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.6)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pendingImageBytes != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(_pendingImageBytes!, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 160,
                    child: Text(
                      _pendingImageName ?? 'Photo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _pendingImageBytes = null;
                      _pendingImageName = null;
                    }),
                  ),
                ],
              ),
            ),
          ],
          if (_pendingVideoBytes != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.videocam, color: Colors.redAccent),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 160,
                    child: Text(
                      _pendingVideoName ?? 'video.mp4',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _pendingVideoBytes = null;
                      _pendingVideoName = null;
                    }),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.add,
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black87
                      : Colors.white70,
                ),
                onPressed: () {
                  _showAttachmentOptions();
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    // If either image or video is pending, show caption hint
                    hintText: (_pendingImageBytes != null || _pendingVideoBytes != null)
                        ? 'Add a caption...'
                        : 'Type a message...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).hintColor
                          : Colors.white54,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.light
                        ? Theme.of(context).cardColor
                        : const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black54
                            : const Color(0xFF333333),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black54
                            : const Color(0xFF333333),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : const Color(0xFF6C5CE7),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendPendingOrText(),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Theme.of(context).colorScheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sendPendingOrText,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator(int index, List<Message> messages) {
    if (index == 0) return true;
    
    final currentMessage = messages[index];
    final previousMessage = messages[index - 1];
    
    final currentDate = DateTime(
      currentMessage.timestamp.year,
      currentMessage.timestamp.month,
      currentMessage.timestamp.day,
    );
    
    final previousDate = DateTime(
      previousMessage.timestamp.year,
      previousMessage.timestamp.month,
      previousMessage.timestamp.day,
    );
    
    return currentDate != previousDate;
  }

  bool _shouldShowAvatar(int index, List<Message> messages) {
    if (index == messages.length - 1) return true;
    
    final currentMessage = messages[index];
    final nextMessage = messages[index + 1];
    
    return currentMessage.senderId != nextMessage.senderId;
  }

  String _getSenderName(String senderId) {
    // 1) Try from active conversation participant names
    final conversation = context.read<ChatProvider>().getConversationById(widget.conversationId);
    final name = conversation?.participantNames[senderId];
    if (name != null && name.isNotEmpty) {
      _userNameCache[senderId] = name;
      return name;
    }
    // 2) Cached value from previous fetch
    final cached = _userNameCache[senderId];
    if (cached != null) return cached;
    // 3) Kick off async fetch from UserProvider; return fallback for now
    Future(() async {
      try {
        final user = await context.read<UserProvider>().getUserById(senderId);
        if (user != null && mounted) {
          setState(() {
            _userNameCache[senderId] = user.displayName;
            _userAvatarCache[senderId] = user.profileImageUrl;
          });
        }
      } catch (_) {}
    });
    return 'User';
  }

  String? _getSenderAvatar(String senderId) {
    // 1) From conversation participant avatars
    final conversation = context.read<ChatProvider>().getConversationById(widget.conversationId);
    final avatar = conversation?.participantAvatars[senderId];
    if (avatar != null) {
      _userAvatarCache[senderId] = avatar;
      return avatar;
    }
    // 2) Cached
    if (_userAvatarCache.containsKey(senderId)) return _userAvatarCache[senderId];
    // 3) Trigger fetch; return null for initials fallback
    Future(() async {
      try {
        final user = await context.read<UserProvider>().getUserById(senderId);
        if (user != null && mounted) {
          setState(() {
            _userNameCache[senderId] = user.displayName;
            _userAvatarCache[senderId] = user.profileImageUrl;
          });
        }
      } catch (_) {}
    });
    return null;
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('Photo Library'),
              onTap: () {
                Navigator.pop(context);
                _pickImageForMessage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.redAccent),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideoForMessage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImageForMessage(fromCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.green),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document picker not implemented yet')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageForMessage({bool fromCamera = false}) async {
    try {
      XFile? pickedXFile;

      if (kIsWeb) {
        pickedXFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
        if (pickedXFile == null) return;
        final bytes = await pickedXFile.readAsBytes();
        setState(() {
          _pendingImageBytes = bytes;
          _pendingImageName = pickedXFile!.name;
        });
      } else if (/* desktop */ true) {
        final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
        if (res == null) return;
        final file = res.files.single;
        if (file.bytes == null) return;
        setState(() {
          _pendingImageBytes = file.bytes!;
          _pendingImageName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    } finally {
      // Nothing to clean up besides pending image state.
    }
  }

  Future<void> _pickVideoForMessage() async {
    try {
      Uint8List? videoBytes;
      if (kIsWeb) {
        final x = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
        if (x == null) return;
        videoBytes = await x.readAsBytes();
        setState(() {
          _pendingVideoBytes = videoBytes;
          _pendingVideoName = x.name;
        });
      } else {
        final res = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false, withData: true);
        if (res == null || res.files.single.bytes == null) return;
        videoBytes = res.files.single.bytes!;
        setState(() {
          _pendingVideoBytes = videoBytes;
          _pendingVideoName = res.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send video: $e')));
      }
    }
  }

  Future<void> _sendPendingOrText() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.user;
      if (currentUser == null) return;

      String? targetUserId = widget.targetUserId;
      if (targetUserId == null) {
        final conversation = context.read<ChatProvider>().getConversationById(widget.conversationId);
        if (conversation != null) {
          targetUserId = conversation.getTargetUserId(currentUser.uid);
        }
      }
      if (targetUserId == null) throw Exception('Unable to determine target user');

      // If there is a pending image, upload and send image message with optional caption
      if (_pendingImageBytes != null) {
        final chatService = ChatService();
        final imageUrl = await chatService.uploadChatImage(
          conversationId: widget.conversationId,
          bytes: _pendingImageBytes,
        );

        final caption = _messageController.text.trim();
        _messageController.clear();

        await context.read<ChatProvider>().sendMessage(
              widget.conversationId,
              caption,
              currentUser.uid,
              targetUserId,
              type: MessageType.image,
              imageUrl: imageUrl,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message sent'), duration: Duration(milliseconds: 800)),
          );
        }

        setState(() {
          _pendingImageBytes = null;
          _pendingImageName = null;
        });
      } else if (_pendingVideoBytes != null) {
        final chatService = ChatService();
        final videoUrl = await chatService.uploadChatVideo(
          conversationId: widget.conversationId,
          bytes: _pendingVideoBytes!,
        );

        final caption = _messageController.text.trim();
        _messageController.clear();

        await context.read<ChatProvider>().sendMessage(
              widget.conversationId,
              caption,
              currentUser.uid,
              targetUserId,
              type: MessageType.video,
              videoUrl: videoUrl,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video sent'), duration: Duration(milliseconds: 800)),
          );
        }

        setState(() {
          _pendingVideoBytes = null;
          _pendingVideoName = null;
        });
      } else {
        // Text message
        await _sendMessage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.conversationName),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat Information:'),
            SizedBox(height: 8),
            Text('เน€เธโฌเน€เธยเธขยเน€เธยเธขยเน€เธยเน€เธโฌเน€เธยเธขย Messages are end-to-end encrypted'),
            Text('เน€เธโฌเน€เธยเธขยเน€เธยเธขยเน€เธยเน€เธโฌเน€เธยเธขย Media is automatically downloaded'),
            Text('เน€เธโฌเน€เธยเธขยเน€เธยเธขยเน€เธยเน€เธโฌเน€เธยเธขย Chat backup is enabled'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages in this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement clear chat functionality if needed
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clear chat not implemented yet')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _openGroupSettings() async {
    final chatProv = context.read<ChatProvider>();
    final convo = chatProv.getConversationById(widget.conversationId);
    if (convo == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupSettingsScreen(
          conversationId: convo.id,
          initialName: convo.name.isNotEmpty ? convo.name : 'Group Chat',
          initialImageUrl: convo.imageUrl,
        ),
      ),
    );
    // Title will auto-refresh via provider
  }
}
