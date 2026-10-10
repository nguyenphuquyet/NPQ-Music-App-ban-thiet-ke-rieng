import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

void configureClient(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
