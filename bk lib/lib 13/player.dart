import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'api.dart';

/// Cầu nối giữa hệ điều hành (Control Center / màn hình khoá / tai nghe /
/// Android notification) và [MusicPlayer]. Các lệnh phát, tạm dừng, bài
/// trước/sau, tua từ hệ thống đều được chuyển vào MusicPlayer.
class NpqAudioHandler extends BaseAudioHandler with SeekHandler {
  MusicPlayer? player;

  @override
  Future<void> play() async {
    final p = player;
    if (p != null && !p.audio.playing) await p.toggle();
  }

  @override
  Future<void> pause() async => player?.audio.pause();

  @override
  Future<void> stop() async => player?.audio.pause();

  @override
  Future<void> seek(Duration position) async => player?.audio.seek(position);

  @override
  Future<void> skipToNext() async => player?.next();

  @override
  Future<void> skipToPrevious() async => player?.previous();
}

NpqAudioHandler? audioHandler;

/// Gọi một lần trong main() trước runApp.
Future<void> initAudioService() async {
  if (kIsWeb) return;
  try {
    audioHandler = await AudioService.init(
      builder: NpqAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'online.nguyenphuquyet.music.audio',
        androidNotificationChannelName: 'NPQ Music',
        androidNotificationOngoing: true,
      ),
    );
  } catch (e) {
    // Không có audio_service (nền tảng chưa cấu hình) thì vẫn phát nhạc bình thường.
    debugPrint('AudioService init failed: $e');
  }
}

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
    audioHandler?.player = this;
    _subscriptions.add(
      audio.playerStateStream.listen((state) {
        notifyListeners();
        _publishState();
        if (state.processingState == ProcessingState.completed) {
          unawaited(next(automatic: true));
        }
      }),
    );
    _subscriptions.add(audio.positionStream.listen((_) => notifyListeners()));
    _subscriptions.add(
      audio.durationStream.listen((_) {
        notifyListeners();
        _publishItem();
      }),
    );
    // Tua / nhảy vị trí: cập nhật lại thanh tiến trình ở Control Center.
    _subscriptions.add(
      audio.positionDiscontinuityStream.listen((_) => _publishState()),
    );
    _subscriptions.add(
      audio.errorStream.listen((e) {
        error = 'Không phát được bài hát này. $e';
        notifyListeners();
      }),
    );
  }
  // ---- Đồng bộ với Control Center / màn hình khoá ----
  void _publishItem() {
    final h = audioHandler;
    final song = current;
    if (h == null || song == null) return;
    final cover = api.media(song['coverUrl']);
    final seconds = (song['duration'] as num?)?.toInt();
    h.mediaItem.add(
      MediaItem(
        id: song['id'].toString(),
        title: song['title']?.toString() ?? '',
        artist: song['artist']?.toString() ?? '',
        album: 'NPQ Music',
        artUri: cover.isEmpty ? null : Uri.parse(cover),
        duration:
            audio.duration ?? (seconds == null ? null : Duration(seconds: seconds)),
      ),
    );
  }

  void _publishState() {
    final h = audioHandler;
    if (h == null) return;
    final playing = audio.playing;
    h.playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (audio.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: audio.position,
        bufferedPosition: audio.bufferedPosition,
        speed: audio.speed,
        queueIndex: index < 0 ? null : index,
      ),
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
    _publishItem();
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
    if (audioHandler?.player == this) audioHandler?.player = null;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    audio.dispose();
    super.dispose();
  }
}
