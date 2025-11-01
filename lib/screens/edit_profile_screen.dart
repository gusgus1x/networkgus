import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/user_avatar.dart';
import '../services/cloudinary_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  bool _saving = false;
  bool _uploading = false;
  String? _localAvatarUrl; // reflect immediate avatar update

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      setState(() => _uploading = true);

      late final Uint8List bytes;
      String filename = 'avatar.jpg';

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

      final cloudinary = CloudinaryService(folder: 'networkgus/avatars');
      final url = await cloudinary.uploadImageBytes(bytes, filename: filename);

      await context.read<AuthProvider>().updateProfile(profileImageUrl: url);
      if (mounted) {
        setState(() => _localAvatarUrl = url);
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
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().updateProfile(
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: const Center(child: Text('Please login to edit profile')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    child: UserAvatar(
                      imageUrl: _localAvatarUrl ?? user.profileImageUrl,
                      displayName: user.displayName,
                      radius: 42,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _uploading ? null : _pickAndUploadAvatar,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  child: _uploading
                      ? const Text('Uploading...')
                      : const Text('Edit pictures or avatar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card with fields
          Form(
            key: _formKey,
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (theme.brightness == Brightness.light)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                ],
                border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Name
                  _LabeledField(
                    label: 'Name',
                    child: TextFormField(
                      controller: _nameController,
                      maxLength: 50,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        counterText: '',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                        ),
                        filled: true,
                        fillColor: theme.inputDecorationTheme.fillColor,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter your name';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Username (read-only)
                  _LabeledField(
                    label: 'Username',
                    child: TextFormField(
                      controller: _usernameController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Username cannot be changed',
                        prefixIcon: const Icon(Icons.alternate_email),
                        suffixIcon: const Icon(Icons.lock_outline, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        filled: true,
                        fillColor: theme.inputDecorationTheme.fillColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bio
                  _LabeledField(
                    label: 'Bio',
                    child: TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      maxLength: 200,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        counterText: '',
                        prefixIcon: const Icon(Icons.info_outline),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                        ),
                        filled: true,
                        fillColor: theme.inputDecorationTheme.fillColor,
                      ),
                    ),
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

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
