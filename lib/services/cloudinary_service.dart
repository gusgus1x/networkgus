import 'dart:typed_data';
import 'dart:io' as io;
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'cloudinary_config.dart';

class CloudinaryService {
  final String cloudName;
  final String uploadPreset;
  final String folder;

  CloudinaryService({
    String? cloudName,
    String? uploadPreset,
    String? folder,
  })  : cloudName = cloudName ?? CloudinaryConfig.cloudName,
        uploadPreset = uploadPreset ?? CloudinaryConfig.uploadPreset,
        folder = folder ?? CloudinaryConfig.folder;

  Uri get _uploadUri => Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');

  Future<String> uploadImageFile(io.File file) async {
    _validateConfig();
    final request = http.MultipartRequest('POST', _uploadUri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final url = (data['secure_url'] ?? data['url']) as String?;
      if (url == null) throw Exception('Cloudinary: secure_url missing');
      return url;
    }
    throw Exception('Cloudinary upload failed (${response.statusCode}): $body');
  }

  Future<String> uploadImageBytes(Uint8List bytes, {String filename = 'image.jpg'}) async {
    _validateConfig();
    final request = http.MultipartRequest('POST', _uploadUri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final url = (data['secure_url'] ?? data['url']) as String?;
      if (url == null) throw Exception('Cloudinary: secure_url missing');
      return url;
    }
    throw Exception('Cloudinary upload failed (${response.statusCode}): $body');
  }

  void _validateConfig() {
    if (cloudName.contains('<') || uploadPreset.contains('<')) {
      throw Exception('Cloudinary config missing. Set cloud_name and upload_preset in lib/services/cloudinary_config.dart');
    }
  }
}
