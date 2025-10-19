import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/post_model.dart';
import '../providers/auth_provider.dart';
import '../providers/posts_provider.dart';
import '../services/cloudinary_service.dart';
import '../widgets/user_avatar.dart';

class EditPostDialog extends StatefulWidget {
  final Post post;
  const EditPostDialog({super.key, required this.post});

  @override
  State<EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<EditPostDialog> {
  final TextEditingController _content = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late List<String> _imageUrls;
  String? _videoUrl; // show/remove/replace later if needed
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _content.text = widget.post.content;
    _imageUrls = List<String>.from(widget.post.imageUrls ?? const []);
    _videoUrl = widget.post.videoUrl;
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  bool get _changed {
    final original = widget.post.imageUrls ?? const [];
    if (_content.text != widget.post.content) return true;
    if (original.length != _imageUrls.length) return true;
    for (int i = 0; i < original.length; i++) {
      if (original[i] != _imageUrls[i]) return true;
    }
    if ((widget.post.videoUrl ?? '') != (_videoUrl ?? '')) return true;
    return false;
  }

  Future<void> _pickImages() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    final cloudinary = CloudinaryService();
    try {
      final newUrls = <String>[];
      if (kIsWeb) {
        final picked = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
        for (final x in picked) {
          final bytes = await x.readAsBytes();
          final url = await cloudinary.uploadImageBytes(bytes, filename: 'edit_${DateTime.now().millisecondsSinceEpoch}.jpg');
          newUrls.add(url);
        }
      } else if (Platform.isWindows || Platform.isLinux) {
        final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image);
        if (res != null) {
          for (final f in res.files) {
            if (f.path == null) continue;
            final url = await cloudinary.uploadImageFile(File(f.path!));
            newUrls.add(url);
          }
        }
      } else {
        final picked = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
        for (final x in picked) {
          final url = await cloudinary.uploadImageFile(File(x.path));
          newUrls.add(url);
        }
      }
      if (newUrls.isNotEmpty) setState(() => _imageUrls.addAll(newUrls));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add images failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickVideo() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final storage = FirebaseStorage.instance;
      if (kIsWeb) {
        final picked = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          final name = 'post_edit_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final ref = storage.ref().child('posts/videos').child(name);
          final snap = await ref.putData(bytes, SettableMetadata(contentType: 'video/mp4'));
          final url = await snap.ref.getDownloadURL();
          setState(() => _videoUrl = url);
        }
      } else {
        XFile? picked;
        if (Platform.isWindows || Platform.isLinux) {
          final res = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false);
          if (res != null && res.files.isNotEmpty && res.files.single.path != null) {
            picked = XFile(res.files.single.path!);
          }
        } else {
          picked = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
        }
        if (picked != null) {
          final name = 'post_edit_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final ref = storage.ref().child('posts/videos').child(name);
          final snap = await ref.putFile(File(picked.path), SettableMetadata(contentType: 'video/mp4'));
          final url = await snap.ref.getDownloadURL();
          setState(() => _videoUrl = url);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add video failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_changed) return;
    setState(() => _saving = true);
    try {
      await context.read<PostsProvider>().editPost(
            postId: widget.post.id,
            newContent: _content.text,
            newImageUrls: _imageUrls,
            newVideoUrl: _videoUrl,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.read<AuthProvider>().currentUser;
    final media = MediaQuery.of(context);
    final isWide = media.size.width > 520;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 760 : 560, maxHeight: media.size.height * 0.92),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Stack(children: [
                Align(
                  alignment: Alignment.center,
                  child: Text('Edit post', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
                ),
              ]),
              const SizedBox(height: 8),
              // User row
              Row(children: [
                UserAvatar(imageUrl: user?.profileImageUrl, displayName: user?.displayName ?? 'User', radius: 18),
                const SizedBox(width: 10),
                Text(user?.displayName ?? 'User', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              // Content editor
              Expanded(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: _content,
                      minLines: 3,
                      maxLines: null,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: "What's on your mind?",
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_imageUrls.isNotEmpty) _ImagesGrid(imageUrls: _imageUrls, onRemove: (i) => setState(() => _imageUrls.removeAt(i))),
                    if (_videoUrl != null && _videoUrl!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.videocam, size: 18),
                          const SizedBox(width: 6),
                          const Text('Video attached'),
                          const SizedBox(width: 6),
                          InkWell(onTap: () => setState(() => _videoUrl = null), child: const Icon(Icons.close, size: 18)),
                        ]),
                      ),
                    const SizedBox(height: 10),
                    // Add to your post bar
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade800, width: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(children: [
                        Text('Add to your post', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade400)),
                        const Spacer(),
                        IconButton(tooltip: 'Add image', icon: const Icon(Icons.image_outlined, color: Colors.green), onPressed: _pickImages),
                        IconButton(tooltip: 'Add video', icon: const Icon(Icons.videocam_outlined, color: Colors.redAccent), onPressed: _pickVideo),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving || !_changed ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagesGrid extends StatelessWidget {
  final List<String> imageUrls;
  final void Function(int index) onRemove;
  const _ImagesGrid({required this.imageUrls, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: imageUrls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (ctx, i) {
        final url = imageUrls[i];
        return Stack(children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(url, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: InkWell(
              onTap: () => onRemove(i),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          )
        ]);
      },
    );
  }
}

