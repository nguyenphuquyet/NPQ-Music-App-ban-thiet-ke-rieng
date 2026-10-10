import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

void configureClient(Dio dio) {
  dio.interceptors.add(CookieManager(CookieJar()));
}
