import 'dart:typed_data';
import 'dart:io' as io;
import 'dart:convert';
import 'package:dio/dio.dart' as dio;

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

  String get _uploadUrl => 'https://api.cloudinary.com/v1_1/$cloudName/auto/upload';
  String get _videoUploadUrl => 'https://api.cloudinary.com/v1_1/$cloudName/video/upload';
  // Audio uses video endpoint in Cloudinary as well
  String get _audioUploadUrl => _videoUploadUrl;

  dio.Dio _client() => dio.Dio(
        dio.BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

  Future<String> uploadImageFile(io.File file) async {
    _validateConfig();
    final form = dio.FormData.fromMap({
      'upload_preset': uploadPreset,
      'folder': folder,
      'file': await dio.MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
    });
    final resp = await _client().post(_uploadUrl, data: form);
    if (resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300) {
      final data = resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : jsonDecode(resp.data.toString()) as Map<String, dynamic>;
      final url = (data['secure_url'] ?? data['url']) as String?;
      if (url == null) throw Exception('Cloudinary: secure_url missing');
      return url;
    }
    throw Exception('Cloudinary upload failed (${resp.statusCode}): ${resp.data}');
  }

  Future<String> uploadImageBytes(Uint8List bytes, {String filename = 'image.jpg'}) async {
    _validateConfig();
    final form = dio.FormData.fromMap({
      'upload_preset': uploadPreset,
      'folder': folder,
      'file': dio.MultipartFile.fromBytes(bytes, filename: filename),
    });
    final resp = await _client().post(_uploadUrl, data: form);
    if (resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300) {
      final data = resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : jsonDecode(resp.data.toString()) as Map<String, dynamic>;
      final url = (data['secure_url'] ?? data['url']) as String?;
      if (url == null) throw Exception('Cloudinary: secure_url missing');
      return url;
    }
    throw Exception('Cloudinary upload failed (${resp.statusCode}): ${resp.data}');
  }

  // Video uploads
  Future<String> uploadVideoFile(io.File file) async {
    _validateConfig();
    final form = dio.FormData.fromMap({
      'upload_preset': uploadPreset,
      'folder': folder,
      'file': await dio.MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
    });
    final resp = await _client().post(_videoUploadUrl, data: form);
    if (resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300) {
      final data = resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : jsonDecode(resp.data.toString()) as Map<String, dynamic>;
      final url = (data['secure_url'] ?? data['url']) as String?;
      if (url == null) throw Exception('Cloudinary: secure_url missing');
      return url;
    }
    throw Exception('Cloudinary video upload failed (${resp.statusCode}): ${resp.data}');
  }

  Future<String> uploadVideoBytes(Uint8List bytes, {String filename = 'video.mp4'}) async {
    _validateConfig();
    final form = dio.FormData.fromMap({
      'upload_preset': uploadPreset,
      'folder': folder,
      'file': dio.MultipartFile.fromBytes(bytes, filename: filename),
    });
    final resp = await _client().post(_videoUploadUrl, data: form);
    if (resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300) {
      final data = resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : jsonDecode(resp.data.toString()) as Map<String, dynamic>;
      final url = (data['secure_url'] ?? data['url']) as String?;
      if (url == null) throw Exception('Cloudinary: secure_url missing');
      return url;
    }
    throw Exception('Cloudinary video upload failed (${resp.statusCode}): ${resp.data}');
  }

  // Audio uploads (mp3)
  Future<String> uploadAudioFile(io.File file) async {
    _validateConfig();
    final form = dio.FormData.fromMap({
      'upload_preset': uploadPreset,
      'folder': folder,
      'file': await dio.MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
    });
    final resp = await _client().post(_audioUploadUrl, data: form);
    if (resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300) {
      final data = resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : jsonDecode(resp.data.toString()) as Map<String, dynamic>;
      final url = (data['secure_url'] ?? data['url']) as String?;
      if (url == null) throw Exception('Cloudinary: secure_url missing');
      return url;
    }
    throw Exception('Cloudinary audio upload failed (${resp.statusCode}): ${resp.data}');
  }

  Future<String> uploadAudioBytes(Uint8List bytes, {String filename = 'audio.mp3'}) async {
    _validateConfig();
    final form = dio.FormData.fromMap({
      'upload_preset': uploadPreset,
      'folder': folder,
      'file': dio.MultipartFile.fromBytes(bytes, filename: filename),
    });
    final resp = await _client().post(_audioUploadUrl, data: form);
    if (resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300) {
      final data = resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : jsonDecode(resp.data.toString()) as Map<String, dynamic>;
      final url = (data['secure_url'] ?? data['url']) as String?;
      if (url == null) throw Exception('Cloudinary: secure_url missing');
      return url;
    }
    throw Exception('Cloudinary audio upload failed (${resp.statusCode}): ${resp.data}');
  }

  void _validateConfig() {
    if (cloudName.contains('<') || uploadPreset.contains('<')) {
      throw Exception('Cloudinary config missing. Set cloud_name and upload_preset in lib/services/cloudinary_config.dart');
    }
  }
}
