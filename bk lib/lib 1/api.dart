import 'package:dio/dio.dart';
import 'network_native.dart' if (dart.library.js_interop) 'network_web.dart';

typedef Json = Map<String, dynamic>;

class Api {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  final Dio dio;
  Api({Dio? client})
    : dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ) {
    if (client == null) configureClient(dio);
  }
  String media(dynamic path) {
    if (path == null || path.toString().isEmpty) return '';
    return Uri.parse(baseUrl).resolve(path.toString()).toString();
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    dynamic data,
  }) async {
    try {
      return (await dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: method),
      )).data;
    } on DioException catch (e) {
      final body = e.response?.data;
      throw Exception(
        body is Map
            ? body['error'] ?? 'Yêu cầu thất bại'
            : 'Không kết nối được server. Kiểm tra mạng và API cổng 3000.',
      );
    }
  }

  Future<List<Json>> list(String path) async => (await request(path) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Future<Json?> me() async {
    try {
      return Map<String, dynamic>.from((await dio.get('/api/me')).data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final csrf = await request('/api/auth/csrf');
    final response = await dio.post(
      '/api/auth/callback/credentials',
      data: {
        'email': email,
        'password': password,
        'csrfToken': csrf['csrfToken'],
        'json': 'true',
        'callbackUrl': baseUrl,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (response.statusCode != 200 ||
        response.data.toString().contains('error=')) {
      throw Exception('Email hoặc mật khẩu không đúng.');
    }
    if (await me() == null) {
      throw Exception(
        'Không lưu được phiên đăng nhập. Hãy mở app bằng localhost:5000.',
      );
    }
  }

  Future<void> logout() async {
    final csrf = await request('/api/auth/csrf');
    await dio.post(
      '/api/auth/signout',
      data: {
        'csrfToken': csrf['csrfToken'],
        'json': 'true',
        'callbackUrl': baseUrl,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
  }
}
