import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

CookieJar _jar = CookieJar();

/// Lưu cookie (phiên đăng nhập) xuống ổ đĩa để mở lại app vẫn còn đăng nhập.
Future<void> initNetwork() async {
  try {
    final dir = await getApplicationSupportDirectory();
    _jar = PersistCookieJar(storage: FileStorage('${dir.path}/.cookies/'));
  } catch (_) {
    // Không ghi được thì dùng cookie trong bộ nhớ.
  }
}

void configureClient(Dio dio) {
  dio.interceptors.add(CookieManager(_jar));
  // Đóng kết nối nhàn rỗi sớm (3s) để không tái sử dụng kết nối keep-alive đã bị
  // server/proxy đóng — nguyên nhân gây lỗi "không kết nối được" ở request đầu.
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()
      ..idleTimeout = const Duration(seconds: 3)
      ..connectionTimeout = const Duration(seconds: 20),
  );
}

/// Lưu / đọc chế độ sáng-tối bằng một file nhỏ (không cần plugin thêm).
Future<File> _darkFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/dark_mode.txt');
}

Future<bool?> readDarkPref() async {
  try {
    final f = await _darkFile();
    if (!await f.exists()) return null;
    return (await f.readAsString()).trim() == '1';
  } catch (_) {
    return null;
  }
}

Future<void> writeDarkPref(bool dark) async {
  try {
    await (await _darkFile()).writeAsString(dark ? '1' : '0');
  } catch (_) {}
}
