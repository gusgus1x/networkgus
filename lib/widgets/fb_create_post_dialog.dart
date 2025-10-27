import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/posts_provider.dart';
import '../services/cloudinary_service.dart';

enum ComposerAction { none, image, video }

class FBCreatePostDialog extends StatefulWidget {
  final String? groupId;
  final ComposerAction initialAction;
  const FBCreatePostDialog({Key? key, this.groupId, this.initialAction = ComposerAction.none}) : super(key: key);

  @override
  State<FBCreatePostDialog> createState() => _FBCreatePostDialogState();
}

class _FBCreatePostDialogState extends State<FBCreatePostDialog> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isPosting = false;

  // Non‑web
  List<File> _selectedImages = [];
  File? _selectedVideo;
  // Web
  List<Uint8List> _selectedImageBytes = [];
  Uint8List? _selectedVideoBytes;

  static const int _maxImages = 9;

  bool get _canPost {
    final hasText = _contentController.text.trim().isNotEmpty;
    final hasImages = (!kIsWeb && _selectedImages.isNotEmpty) || (kIsWeb && _selectedImageBytes.isNotEmpty);
    final hasVideo = (!kIsWeb && _selectedVideo != null) || (kIsWeb && _selectedVideoBytes != null);
    return hasText || hasImages || hasVideo;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialAction != ComposerAction.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.initialAction == ComposerAction.image) _pickImages();
        if (widget.initialAction == ComposerAction.video) _pickVideo();
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();
    final hasMedia = ((!kIsWeb && _selectedImages.isNotEmpty) || (kIsWeb && _selectedImageBytes.isNotEmpty)) ||
        ((!kIsWeb && _selectedVideo != null) || (kIsWeb && _selectedVideoBytes != null));
    if (content.isEmpty && !hasMedia) return;

    setState(() => _isPosting = true);

    try {
      final auth = context.read<AuthProvider>();
      final currentUser = auth.currentUser;
      if (currentUser == null) throw Exception('No user logged in');

      List<String>? uploadedImageUrls;
      String? uploadedVideoUrl;
      if (kIsWeb) {
        if (_selectedImageBytes.isNotEmpty) {
          uploadedImageUrls = await _uploadImagesWeb(_selectedImageBytes).timeout(const Duration(seconds: 45));
        }
        if (_selectedVideoBytes != null) {
          uploadedVideoUrl = await _uploadVideoWeb(_selectedVideoBytes!).timeout(const Duration(seconds: 90));
        }
      }

      await context.read<PostsProvider>().createPost(
            content: content,
            userId: currentUser.id,
            userDisplayName: currentUser.displayName,
            username: currentUser.username,
            userProfileImageUrl: currentUser.profileImageUrl,
            isUserVerified: currentUser.isVerified,
            groupId: widget.groupId,
            imageFiles: !kIsWeb && _selectedImages.isNotEmpty ? _selectedImages : null,
            imageUrls: kIsWeb ? uploadedImageUrls : null,
            videoFile: !kIsWeb ? _selectedVideo : null,
            videoUrl: kIsWeb ? uploadedVideoUrl : null,
            refreshAfterCreate: false,
          ).timeout(const Duration(seconds: 20));

      if (widget.groupId != null && widget.groupId!.isNotEmpty) {
        Future(() async {
          final uid = context.read<AuthProvider>().currentUser?.id;
          await context.read<PostsProvider>().fetchGroupPosts(widget.groupId!, currentUserId: uid);
        });
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: false).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      if (kIsWeb) {
        final picked = await _picker.pickMultiImage(imageQuality: 75, maxWidth: 1600);
        if (picked.isNotEmpty) {
          final bytesList = await Future.wait(picked.map((e) => e.readAsBytes()));
          setState(() => _selectedImageBytes = bytesList);
        }
      } else if (Platform.isWindows || Platform.isLinux) {
        final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image);
        if (res != null && res.files.isNotEmpty) {
          final files = res.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
          setState(() => _selectedImages = files);
        }
      } else {
        final picked = await _picker.pickMultiImage(imageQuality: 75, maxWidth: 1600);
        if (picked.isNotEmpty) {
          setState(() => _selectedImages = picked.map((e) => File(e.path)).toList());
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select images failed: $e')));
    }
  }

  Future<void> _pickVideo() async {
    try {
      if (kIsWeb) {
        final picked = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          setState(() => _selectedVideoBytes = bytes);
        }
      } else if (Platform.isWindows || Platform.isLinux) {
        final res = await FilePicker.platform.pickFiles(allowMultiple: false, type: FileType.video);
        if (res != null && res.files.isNotEmpty && res.files.single.path != null) {
          setState(() => _selectedVideo = File(res.files.single.path!));
        }
      } else {
        final picked = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
        if (picked != null) {
          setState(() => _selectedVideo = File(picked.path));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select video failed: $e')));
    }
  }

  Future<List<String>> _uploadImagesWeb(List<Uint8List> bytesList) async {
    final cloudinary = CloudinaryService();
    final uploads = <Future<String>>[];
    for (int i = 0; i < bytesList.length; i++) {
      final name = 'image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      uploads.add(cloudinary.uploadImageBytes(bytesList[i], filename: name));
    }
    return await Future.wait(uploads);
  }

  Future<String> _uploadVideoWeb(Uint8List bytes) async {
    final cloudinary = CloudinaryService();
    final name = '${DateTime.now().millisecondsSinceEpoch}_video.mp4';
    return await cloudinary.uploadVideoBytes(bytes, filename: name);
  }

  int _imagesCount() => kIsWeb ? _selectedImageBytes.length : _selectedImages.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isWide = media.size.width > 520;

    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    final displayName = currentUser?.displayName ?? 'User';
    final firstName = displayName.split(' ').first;

    return Dialog(
      backgroundColor: theme.cardColor,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 720 : 520,
                maxHeight: media.size.height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // header
                    Stack(
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text('Create post', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // user row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: (currentUser?.profileImageUrl != null && currentUser!.profileImageUrl!.isNotEmpty)
                              ? NetworkImage(currentUser.profileImageUrl!)
                              : null,
                          child: (currentUser?.profileImageUrl == null || currentUser!.profileImageUrl!.isEmpty)
                              ? Text(firstName.substring(0, 1).toUpperCase())
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // composer
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 96, maxHeight: isWide ? 240 : 200),
                      child: TextField(
                        controller: _contentController,
                        decoration: InputDecoration(
                          hintText: "What's on your mind, $firstName?",
                          hintStyle: theme.textTheme.titleMedium?.copyWith(color: theme.hintColor),
                          isCollapsed: false,
                          filled: true,
                          // Respect theme input surface per theme
                          fillColor: theme.inputDecorationTheme.fillColor ?? theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (_) => setState(() {}),
                        style: theme.textTheme.titleMedium?.copyWith(height: 1.4),
                        minLines: 4,
                        maxLines: 10,
                        maxLength: 500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((!kIsWeb && _selectedImages.isNotEmpty) || (kIsWeb && _selectedImageBytes.isNotEmpty)) _buildImagesGrid(),
                    if ((!kIsWeb && _selectedVideo != null) || (kIsWeb && _selectedVideoBytes != null)) _buildVideoChip(),
                    const SizedBox(height: 8),
                    // toolbar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8A2BE2), Color(0xFF00D4FF)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Aa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black54, width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Add image',
                                icon: const Icon(Icons.image_outlined, color: Colors.green),
                                onPressed: _pickImages,
                              ),
                              IconButton(
                                tooltip: 'Add video',
                                icon: const Icon(Icons.videocam_outlined, color: Colors.redAccent),
                                onPressed: _pickVideo,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isPosting || !_canPost ? null : _createPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: _isPosting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Post'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isPosting)
            Positioned.fill(
              child: IgnorePointer(child: Container(color: Colors.black.withOpacity(0.04))),
            ),
        ],
      ),
    );
  }

  Widget _buildImagesGrid() {
    final items = kIsWeb ? _selectedImageBytes : _selectedImages;
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 560
          ? 5
          : constraints.maxWidth > 420
              ? 4
              : 3;
      final itemSize = (constraints.maxWidth - (crossAxisCount * 8)) / crossAxisCount;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _imagesCount(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            return Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: kIsWeb
                    ? Image.memory(items[index] as Uint8List, width: itemSize, height: itemSize, fit: BoxFit.cover)
                    : Image.file(items[index] as File, width: itemSize, height: itemSize, fit: BoxFit.cover),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () => setState(() {
                    if (kIsWeb) {
                      _selectedImageBytes.removeAt(index);
                    } else {
                      _selectedImages.removeAt(index);
                    }
                  }),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ]);
          },
        ),
        const SizedBox(height: 6),
        Row(children: [
          OutlinedButton.icon(
            onPressed: _imagesCount() >= _maxImages ? null : _pickImages,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text('Add more (${_imagesCount()}/$_maxImages)'),
          ),
        ])
      ]);
    });
  }

  Widget _buildVideoChip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.videocam, size: 18),
        const SizedBox(width: 6),
        const Text('Video selected'),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => setState(() {
            _selectedVideo = null;
            _selectedVideoBytes = null;
          }),
          child: const Icon(Icons.close, size: 18),
        ),
      ]),
    );
  }
}
