import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final user = fb_auth.FirebaseAuth.instance.currentUser;
          final token = user != null ? await user.getIdToken() : null;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {}
        handler.next(options);
      },
      onError: (e, handler) {
        // Optionally log or transform errors here
        handler.next(e);
      },
    ),
  );

  return dio;
});

