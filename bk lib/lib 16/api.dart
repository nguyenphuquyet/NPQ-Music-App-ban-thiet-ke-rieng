import 'package:dio/dio.dart';
import 'network_native.dart' if (dart.library.js_interop) 'network_web.dart';

typedef Json = Map<String, dynamic>;

/// Khởi tạo nơi lưu cookie (gọi một lần trong main trước khi tạo Api).
Future<void> initApiStorage() => initNetwork();

/// Chế độ sáng/tối đã lưu (null nếu chưa lưu).
Future<bool?> loadDarkPref() => readDarkPref();
Future<void> saveDarkPref(bool dark) => writeDarkPref(dark);

class Api {
  static const baseUrl = 'https://music.nguyenphuquyet.online';
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
  // Lỗi do kết nối (chưa nhận được phản hồi nào): thường là do kết nối keep-alive
  // cũ đã bị server đóng, hoặc mạng chập chờn lúc vừa mở app. Thử lại là qua.
  bool _retryable(DioException e) =>
      e.response == null &&
      (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown);

  Future<T> _retry<T>(Future<T> Function() run, {int attempts = 3}) async {
    for (var i = 1; ; i++) {
      try {
        return await run();
      } on DioException catch (e) {
        if (i >= attempts || !_retryable(e)) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * i));
      }
    }
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
      Future<Response<dynamic>> send() =>
          dio.request<dynamic>(path, data: data, options: Options(method: method));
      // Chỉ tự thử lại với GET (an toàn, không tạo thêm dữ liệu).
      return (await (method == 'GET' ? _retry(send) : send())).data;
    } on DioException catch (e) {
      final body = e.response?.data;
      throw Exception(
        body is Map
            ? body['error'] ?? 'Yêu cầu thất bại'
            : 'Không kết nối được server (${e.response?.statusCode ?? e.type.name} $path). '
                  'Vui lòng kiểm tra kết nối mạng.',
      );
    }
  }

  Future<List<Json>> list(String path) async => (await request(path) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Future<Json?> me() async {
    try {
      return Map<String, dynamic>.from(
        (await _retry(() => dio.get('/api/me'))).data,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final csrf = await request('/api/auth/csrf');
    final response = await _retry(
      () => dio.post(
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
      ),
    );
    if (response.statusCode != 200 ||
        response.data.toString().contains('error=')) {
      throw Exception('Email hoặc mật khẩu không đúng.');
    }
    if (await me() == null) {
      throw Exception(
        'Không lưu được phiên đăng nhập. Vui lòng thử lại.',
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
