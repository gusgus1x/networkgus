import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/posts_provider.dart';
import '../services/cloudinary_service.dart';
import '../providers/auth_provider.dart';

enum ComposerAction { none, image, video }

class CreatePostDialog extends StatefulWidget {
  final String? groupId;
  final ComposerAction initialAction;
  const CreatePostDialog({Key? key, this.groupId, this.initialAction = ComposerAction.none}) : super(key: key);

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final TextEditingController _contentController = TextEditingController();
  bool _isPosting = false;
  // Mobile/Desktop (non-web)
  List<File> _selectedImages = [];
  File? _selectedVideo;
  // Web
  List<Uint8List> _selectedImageBytes = [];
  Uint8List? _selectedVideoBytes;
  final ImagePicker _picker = ImagePicker();

  static const int _maxImages = 9;

  bool get _canPost {
    final hasText = _contentController.text.trim().isNotEmpty;
    final hasImages = (!kIsWeb && _selectedImages.isNotEmpty) || (kIsWeb && _selectedImageBytes.isNotEmpty);
    final hasVideo = (!kIsWeb && _selectedVideo != null) || (kIsWeb && _selectedVideoBytes != null);
    return hasText || hasImages || hasVideo;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // If the composer was opened from a quick action, trigger it after build
    if (widget.initialAction != ComposerAction.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        switch (widget.initialAction) {
          case ComposerAction.image:
            _pickImages();
            break;
          case ComposerAction.video:
            _pickVideo();
            break;
          case ComposerAction.none:
            break;
        }
      });
    }
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // On web, upload bytes here first with timeouts
      List<String>? uploadedImageUrls;
      String? uploadedVideoUrl;
      if (kIsWeb) {
        if (_selectedImageBytes.isNotEmpty) {
          uploadedImageUrls = await _uploadImagesWeb(_selectedImageBytes)
              .timeout(const Duration(seconds: 45));
        }
        if (_selectedVideoBytes != null) {
          uploadedVideoUrl = await _uploadVideoWeb(_selectedVideoBytes!)
              .timeout(const Duration(seconds: 90));
        }
      }

      // Create post (short timeout)
      await context
          .read<PostsProvider>()
          .createPost(
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
          )
          .timeout(const Duration(seconds: 20));

      // Fire-and-forget group refresh using direct query by groupId
      if (widget.groupId != null && widget.groupId!.isNotEmpty) {
        Future(() async {
          final auth = context.read<AuthProvider>();
          final uid = auth.currentUser?.id;
          await context.read<PostsProvider>().fetchGroupPosts(widget.groupId!, currentUserId: uid);
        });
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: false).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      if (kIsWeb) {
        final picked = await _picker.pickMultiImage(
          imageQuality: 75,
          maxWidth: 1600,
        );
        if (picked.isNotEmpty) {
          final bytesList = await Future.wait(picked.map((e) => e.readAsBytes()));
          setState(() => _selectedImageBytes = bytesList);
        }
      } else if (Platform.isWindows || Platform.isLinux) {
        final res = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.image,
        );
        if (res != null && res.files.isNotEmpty) {
          final files = res.files
              .where((f) => f.path != null)
              .map((f) => File(f.path!))
              .toList();
          setState(() => _selectedImages = files);
        }
      } else {
        final picked = await _picker.pickMultiImage(
          imageQuality: 75,
          maxWidth: 1600,
        );
        if (picked.isNotEmpty) {
          setState(() => _selectedImages = picked.map((e) => File(e.path)).toList());
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Select images failed: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      if (kIsWeb) {
        final picked = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 3),
        );
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          setState(() => _selectedVideoBytes = bytes);
        }
      } else if (Platform.isWindows || Platform.isLinux) {
        final res = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.video,
        );
        if (res != null && res.files.isNotEmpty && res.files.single.path != null) {
          setState(() => _selectedVideo = File(res.files.single.path!));
        }
      } else {
        final picked = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 3),
        );
        if (picked != null) {
          setState(() => _selectedVideo = File(picked.path));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Select video failed: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isWide = media.size.width > 520;

    return Dialog(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 720 : 520,
                // let it grow a bit taller for better composing
                maxHeight: media.size.height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Create Post', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Composer
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 96,
                      maxHeight: isWide ? 240 : 200,
                    ),
                    child: TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        hintText: 'Write something... (and add images below)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                      onChanged: (_) => setState(() {}),
                      minLines: 4,
                      maxLines: 10,
                      maxLength: 500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Media grid
                  if ((!kIsWeb && _selectedImages.isNotEmpty) || (kIsWeb && _selectedImageBytes.isNotEmpty))
                    _buildImagesGrid(),
                  if ((!kIsWeb && _selectedVideo != null) || (kIsWeb && _selectedVideoBytes != null))
                    _buildVideoChip(),
                  const SizedBox(height: 10),
                  // Toolbar
                  Row(
                    children: [
                      Tooltip(
                        message: 'Add images',
                        child: IconButton(
                          icon: const Icon(Icons.image),
                          onPressed: _pickImages,
                        ),
                      ),
                      Tooltip(
                        message: 'Add video',
                        child: IconButton(
                          icon: const Icon(Icons.videocam),
                          onPressed: _pickVideo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if ((!kIsWeb && _selectedImages.isNotEmpty) || (kIsWeb && _selectedImageBytes.isNotEmpty))
                        Text('${_imagesCount()}/${_maxImages}', style: theme.textTheme.bodySmall),
                      const Spacer(),
                      TextButton(
                        onPressed: ((!kIsWeb && _selectedImages.isEmpty) && (kIsWeb ? _selectedImageBytes.isEmpty : true) && _selectedVideo == null && _selectedVideoBytes == null)
                            ? null
                            : () => setState(() {
                                  _selectedImages.clear();
                                  _selectedImageBytes.clear();
                                  _selectedVideo = null;
                                  _selectedVideoBytes = null;
                                }),
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isPosting || !_canPost ? null : _createPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: _isPosting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Post'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ),
          if (_isPosting)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.04),
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _imagesCount() => kIsWeb ? _selectedImageBytes.length : _selectedImages.length;

  Widget _buildImagesGrid() {
    final items = kIsWeb ? _selectedImageBytes : _selectedImages;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 560
            ? 5
            : constraints.maxWidth > 420
                ? 4
                : 3;
        final itemSize = (constraints.maxWidth - (crossAxisCount * 8)) / crossAxisCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                return Stack(
                  children: [
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
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _imagesCount() >= _maxImages ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text('Add more (${_imagesCount()}/$_maxImages)'),
                ),
              ],
            )
          ],
        );
      },
    );
  }

  Widget _buildVideoChip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
      ),
    );
  }
}
