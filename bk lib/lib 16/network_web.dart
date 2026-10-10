import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

// Web: trình duyệt tự quản lý cookie.
Future<void> initNetwork() async {}

void configureClient(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}

// Web: chưa lưu chế độ sáng/tối.
Future<bool?> readDarkPref() async => null;
Future<void> writeDarkPref(bool dark) async {}
