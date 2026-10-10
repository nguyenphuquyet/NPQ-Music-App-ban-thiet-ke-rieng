import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npq_music/api.dart';

void main() {
  test('Media paths resolve against the configured backend', () {
    final api = Api(client: Dio());
    expect(
      api.media('/media/audio/song.mp3'),
      '${Api.baseUrl}/media/audio/song.mp3',
    );
    expect(
      api.media('https://cdn.example.com/song.mp3'),
      'https://cdn.example.com/song.mp3',
    );
    expect(api.media(null), '');
  });
  test(
    'Requests preserve methods and JSON bodies and surface server errors',
    () async {
      final dio = Dio(BaseOptions(baseUrl: Api.baseUrl));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/favorites') {
              expect(options.method, 'POST');
              expect(options.data, {'songId': 'song-1'});
              handler.resolve(
                Response(requestOptions: options, data: {'favorited': true}),
              );
            } else {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 401,
                    data: {'error': 'Bạn cần đăng nhập'},
                  ),
                ),
              );
            }
          },
        ),
      );
      final api = Api(client: dio);
      expect(
        await api.request(
          '/api/favorites',
          method: 'POST',
          data: {'songId': 'song-1'},
        ),
        {'favorited': true},
      );
      await expectLater(
        api.request('/private'),
        throwsA(predicate((e) => e.toString().contains('Bạn cần đăng nhập'))),
      );
    },
  );
  test(
    'Missing session is a guest; connection errors are not silently treated as logout',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) => h.reject(
            DioException(
              requestOptions: o,
              response: Response(requestOptions: o, statusCode: 401),
            ),
          ),
        ),
      );
      expect(await Api(client: dio).me(), isNull);
    },
  );
}
