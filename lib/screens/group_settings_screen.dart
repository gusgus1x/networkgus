import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../providers/chat_provider.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String conversationId;
  final String initialName;
  final String? initialImageUrl;

  const GroupSettingsScreen({
    Key? key,
    required this.conversationId,
    required this.initialName,
    this.initialImageUrl,
  }) : super(key: key);

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _newImageBytes;
  String? _newImageName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickGroupImage() async {
    try {
      XFile? pickedXFile;
      if (kIsWeb) {
        pickedXFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
        if (pickedXFile == null) return;
        final bytes = await pickedXFile.readAsBytes();
        setState(() {
          _newImageBytes = bytes;
          _newImageName = pickedXFile!.name;
        });
      } else {
        final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
        if (res == null) return;
        final file = res.files.single;
        if (file.bytes == null) return;
        setState(() {
          _newImageBytes = file.bytes!;
          _newImageName = file.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เลือกรูปภาพไม่สำเร็จ: $e')),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาใส่ชื่อกลุ่ม')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Update name
      await context.read<ChatProvider>().updateGroupName(widget.conversationId, name);

      // Update image if picked
      if (_newImageBytes != null) {
        await context.read<ChatProvider>().updateGroupImage(widget.conversationId, _newImageBytes!);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่ากลุ่ม'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('บันทึก', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: _newImageBytes != null
                      ? MemoryImage(_newImageBytes!)
                      : (widget.initialImageUrl != null
                          ? NetworkImage(widget.initialImageUrl!) as ImageProvider
                          : null),
                  child: (widget.initialImageUrl == null && _newImageBytes == null)
                      ? const Icon(Icons.group, size: 40)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: Colors.blue,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _pickGroupImage,
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'ชื่อกลุ่ม',
              border: OutlineInputBorder(),
            ),
          ),
          if (_newImageName != null) ...[
            const SizedBox(height: 8),
            Text('รูปที่เลือก: ${_newImageName!}'),
          ],
        ],
      ),
    );
  }
}

