import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'api.dart';

class MusicPlayer extends ChangeNotifier {
  final Api api;
  final AudioPlayer audio = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<Json> queue = [];
  int index = -1;
  bool shuffle = false;
  int repeat = 0;
  String? error;
  int _generation = 0;
  Json? get current => index >= 0 && index < queue.length ? queue[index] : null;
  MusicPlayer(this.api) {
    _subscriptions.add(
      audio.playerStateStream.listen((state) {
        notifyListeners();
        if (state.processingState == ProcessingState.completed) {
          unawaited(next(automatic: true));
        }
      }),
    );
    _subscriptions.add(audio.positionStream.listen((_) => notifyListeners()));
    _subscriptions.add(audio.durationStream.listen((_) => notifyListeners()));
    _subscriptions.add(
      audio.errorStream.listen((e) {
        error = 'Không phát được bài hát này. $e';
        notifyListeners();
      }),
    );
  }
  Future<void> play(List<Json> songs, int selected) async {
    if (songs.isEmpty) return;
    final generation = ++_generation;
    queue = List.of(songs);
    index = selected;
    error = null;
    notifyListeners();
    final song = current!;
    final url = api.media(song['audioUrl']);
    debugPrint('PLAY -> ${song['title']} | $url');
    try {
      await audio.stop(); // dừng bài cũ trước khi nạp bài mới
      if (generation != _generation) return;
      if (url.isEmpty) throw Exception('Bài hát không có audioUrl');
      await audio.setAudioSource(AudioSource.uri(Uri.parse(url)));
      if (generation != _generation) return;
      unawaited(
        audio.play().catchError((Object e) {
          error = 'Không phát được âm thanh: $e';
          notifyListeners();
        }),
      );
      unawaited(
        api
            .request(
              '/api/songs/${song['id']}',
              method: 'PATCH',
              data: {'action': 'increment-play'},
            )
            .catchError((Object _) => null),
      );
    } catch (e) {
      if (generation == _generation) {
        error = 'Không tải được bài hát: $e';
        debugPrint('PLAY ERROR: $e');
        notifyListeners();
      }
    }
  }

  Future<void> toggle() async {
    if (audio.playing) {
      await audio.pause();
    } else {
      if (audio.processingState == ProcessingState.completed) {
        await audio.seek(Duration.zero);
      }
      unawaited(
        audio.play().catchError((Object e) {
          error = '$e';
          notifyListeners();
        }),
      );
    }
  }

  Future<void> next({bool automatic = false}) async {
    if (queue.isEmpty) return;
    if (automatic && repeat == 2) {
      await play(queue, index);
      return;
    }
    if (automatic && index == queue.length - 1 && repeat == 0 && !shuffle) {
      await audio.pause();
      return;
    }
    var target = (index + 1) % queue.length;
    if (shuffle && queue.length > 1) {
      target = (index + 1 + Random().nextInt(queue.length - 1)) % queue.length;
    }
    await play(queue, target);
  }

  Future<void> previous() async {
    if (audio.position.inSeconds > 3) {
      await audio.seek(Duration.zero);
      return;
    }
    if (queue.isNotEmpty) {
      await play(queue, (index - 1 + queue.length) % queue.length);
    }
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = (repeat + 1) % 3;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    audio.dispose();
    super.dispose();
  }
}
