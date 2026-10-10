part of 'main.dart';

// Giao diện trình phát dựa theo bản Next.js (Player.tsx + NowPlayingOverlay.tsx).
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _rose500 = Color(0xFFF43F5E);

String _fmt(num ms) {
  final s = (ms / 1000).floor();
  if (s < 0) return '0:00';
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

SliderThemeData _sliderTheme(BuildContext c) {
  final cs = Theme.of(c).colorScheme;
  final dark = Theme.of(c).brightness == Brightness.dark;
  return SliderTheme.of(c).copyWith(
    trackHeight: 4,
    activeTrackColor: cs.primary,
    inactiveTrackColor: dark
        ? Colors.white.withValues(alpha: .2)
        : Colors.black.withValues(alpha: .1),
    thumbColor: cs.primary,
    overlayShape: SliderComponentShape.noOverlay,
    thumbShape: const RoundSliderThumbShape(
      enabledThumbRadius: 6,
      elevation: 0,
      pressedElevation: 0,
    ),
    trackShape: const RoundedRectSliderTrackShape(),
  );
}

/// Thanh kéo tuỳ biến (dùng cho tua nhạc và âm lượng): track mảnh bo tròn,
/// chạm hoặc kéo đều được; khi kéo track dày lên và nút tròn phóng to.
class _ScrubBar extends StatefulWidget {
  final double progress; // 0..1
  final bool enabled;
  final ValueChanged<double> onStart, onUpdate, onEnd;
  const _ScrubBar({
    required this.progress,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    this.enabled = true,
  });
  @override
  State<_ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends State<_ScrubBar> {
  bool dragging = false;
  static const pad = 8.0; // chừa chỗ cho nút tròn không bị cắt ở hai đầu

  double fraction(double dx, double width) =>
      ((dx - pad) / (width - pad * 2)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = cs.primary;
    final inactive = dark
        ? Colors.white.withValues(alpha: .2)
        : Colors.black.withValues(alpha: .1);
    return LayoutBuilder(
      builder: (_, area) {
        final width = area.maxWidth;
        final inner = (width - pad * 2).clamp(0.0, double.infinity);
        final progress = widget.progress.clamp(0.0, 1.0);
        final trackH = dragging ? 6.0 : 4.0;
        final thumb = dragging ? 16.0 : 12.0;
        final fillW = inner * progress;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.enabled
              ? (d) {
                  final f = fraction(d.localPosition.dx, width);
                  widget.onStart(f);
                  widget.onEnd(f);
                }
              : null,
          onHorizontalDragStart: widget.enabled
              ? (d) {
                  setState(() => dragging = true);
                  widget.onStart(fraction(d.localPosition.dx, width));
                }
              : null,
          onHorizontalDragUpdate: widget.enabled
              ? (d) => widget.onUpdate(fraction(d.localPosition.dx, width))
              : null,
          onHorizontalDragEnd: widget.enabled
              ? (_) {
                  setState(() => dragging = false);
                  widget.onEnd(progress);
                }
              : null,
          onHorizontalDragCancel: () => setState(() => dragging = false),
          child: SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: pad,
                  right: pad,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: trackH,
                    decoration: BoxDecoration(
                      color: inactive,
                      borderRadius: BorderRadius.circular(trackH),
                    ),
                  ),
                ),
                Positioned(
                  left: pad,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: trackH,
                    width: fillW,
                    decoration: BoxDecoration(
                      color: widget.enabled ? active : inactive,
                      borderRadius: BorderRadius.circular(trackH),
                    ),
                  ),
                ),
                if (widget.enabled)
                  Positioned(
                    left: pad + fillW - thumb / 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: active, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .25),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Thanh tua + thời gian. [stacked] = true: thời gian nằm dưới hai đầu thanh
/// (màn hình đang phát); false: thời gian nằm hai bên (thanh dưới màn hình rộng).
class SeekBar extends StatefulWidget {
  final MusicPlayer player;
  final Color timeColor;
  final bool stacked;
  const SeekBar({
    super.key,
    required this.player,
    required this.timeColor,
    this.stacked = false,
  });
  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? drag; // ms; giữ giá trị khi đang kéo để thanh không bị giật ngược
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.player,
    builder: (ctx, _) {
      final a = widget.player.audio;
      final fallback =
          ((widget.player.current?['duration'] as num?) ?? 0) * 1000.0;
      // Ưu tiên thời lượng từ API: file MP3 VBR thiếu header khiến
      // audio.duration bị ước lượng sai (hay gấp đôi) sau khi tải xong.
      final total = fallback > 0
          ? fallback.toDouble()
          : (a.duration?.inMilliseconds ?? 0).toDouble();
      final max = total > 0 ? total : 1.0;
      final value = (drag ?? a.position.inMilliseconds.toDouble()).clamp(
        0.0,
        max,
      );
      final style = TextStyle(
        fontSize: widget.stacked ? 12 : 11,
        color: widget.timeColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      final bar = _ScrubBar(
        progress: value / max,
        enabled: total > 0,
        onStart: (f) => setState(() => drag = f * max),
        onUpdate: (f) => setState(() => drag = f * max),
        onEnd: (f) {
          widget.player.audio.seek(Duration(milliseconds: (f * max).toInt()));
          setState(() => drag = null);
        },
      );
      if (widget.stacked) {
        return Column(
          children: [
            bar,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(value), style: style),
                  Text(_fmt(total), style: style),
                ],
              ),
            ),
          ],
        );
      }
      return Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(_fmt(value), textAlign: TextAlign.right, style: style),
          ),
          Expanded(child: bar),
          SizedBox(width: 36, child: Text(_fmt(total), style: style)),
        ],
      );
    },
  );
}

class VolumeControl extends StatefulWidget {
  final MusicPlayer player;
  final Color color;
  const VolumeControl({super.key, required this.player, required this.color});
  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  late double v = widget.player.audio.volume;
  void set(double x) {
    setState(() => v = x);
    widget.player.audio.setVolume(x);
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => set(v == 0 ? 1 : 0),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            v == 0
                ? LucideIcons.volume
                : v < .5
                ? LucideIcons.volume1
                : LucideIcons.volume2,
            size: 18,
            color: widget.color,
          ),
        ),
      ),
      SizedBox(
        width: 96,
        child: _ScrubBar(
          progress: v,
          onStart: set,
          onUpdate: set,
          onEnd: (_) {},
        ),
      ),
    ],
  );
}

extension _PlayerUI on _MusicHomeState {
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _brand => _dark ? const Color(0xFF407EEB) : blue;

  Widget _ctl(
    IconData icon,
    double size,
    Color color,
    VoidCallback? onTap, {
    double pad = 6,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? .4 : 1,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Icon(icon, size: size, color: color),
      ),
    ),
  );

  Widget _playCircle(double size, double icon, bool playing, bool enabled) =>
      GestureDetector(
        onTap: enabled ? () => guard(player.toggle) : null,
        child: Opacity(
          opacity: enabled ? 1 : .4,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _brand,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _brand.withValues(alpha: .35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: icon,
              color: Colors.white,
            ),
          ),
        ),
      );

  Widget _barCover(Json? song, double size) {
    final url = song == null ? '' : api.media(song['coverUrl']);
    final icon = Icon(LucideIcons.music2, size: 20, color: _brand);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: _dark ? const Color(0xFF0B1F4D) : const Color(0xFFDCE7FF),
        child: url.isEmpty
            ? icon
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => icon,
              ),
      ),
    );
  }

  BoxDecoration _barDecoration(ColorScheme cs, {bool glass = false}) =>
      BoxDecoration(
        color: glass ? Colors.transparent : cs.surface.withValues(alpha: .95),
        border: glass
            ? null
            : Border(
                top: BorderSide(
                  color: _dark
                      ? Colors.white.withValues(alpha: .05)
                      : Colors.black.withValues(alpha: .05),
                ),
              ),
      );

  Widget _songTexts(Json? song, Color ink, {double titleSize = 14}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        song?['title'] ?? 'Chưa có bài hát nào',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: titleSize,
          fontWeight: FontWeight.w600,
          color: song == null ? _slate400 : ink,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        player.error != null
            ? 'Không phát được • chạm để xem'
            : (song?['artist'] ?? 'Chọn một bài hát để bắt đầu'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: player.error != null
              ? dangerColor
              : (_dark ? _slate400 : _slate500),
        ),
      ),
    ],
  );

  // ---------------- Thanh phát (điện thoại) ----------------
  Widget miniPlayer() => ListenableBuilder(
    listenable: player,
    builder: (ctx, _) {
      final song = player.current;
      final cs = Theme.of(ctx).colorScheme;
      final apiSeconds = (song?['duration'] as num?)?.toInt() ?? 0;
      final total = apiSeconds > 0
          ? apiSeconds * 1000
          : (player.audio.duration?.inMilliseconds ?? 0);
      final progress = total <= 0
          ? 0.0
          : (player.audio.position.inMilliseconds / total).clamp(0.0, 1.0);
      final enabled = song != null;
      void open() {
        if (enabled) nowPlaying();
      }

      return Container(
        decoration: _barDecoration(cs, glass: true),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 2,
              child: ColoredBox(
                color: _dark
                    ? Colors.white.withValues(alpha: .1)
                    : Colors.black.withValues(alpha: .05),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: ColoredBox(color: _brand),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: LayoutBuilder(
                builder: (_, box) => Row(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: box.maxWidth * .5),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: open,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _barCover(song, 44),
                            const SizedBox(width: 12),
                            Flexible(child: _songTexts(song, cs.onSurface)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(16, 0),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ctl(
                                Icons.skip_previous_rounded,
                                26,
                                _slate500,
                                enabled ? player.previous : null,
                              ),
                              const SizedBox(width: 10),
                              _playCircle(
                                36,
                                22,
                                player.audio.playing,
                                enabled,
                              ),
                              const SizedBox(width: 10),
                              _ctl(
                                Icons.skip_next_rounded,
                                26,
                                _slate500,
                                enabled ? player.next : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  // ---------------- Thanh phát (máy tính bảng / rộng) ----------------
  Widget tabletPlayer() => ListenableBuilder(
    listenable: player,
    builder: (ctx, _) {
      final song = player.current;
      final cs = Theme.of(ctx).colorScheme;
      final enabled = song != null;
      final fav = enabled && favorites.contains(song!['id']);
      const idle = _slate400;
      final active = _brand;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: _barDecoration(cs),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: enabled ? nowPlaying : null,
                    child: _barCover(song, 56),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: enabled
                          ? () => openSong(List.of(player.queue), player.index)
                          : null,
                      child: _songTexts(song, cs.onSurface),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ctl(
                    fav ? Icons.favorite : LucideIcons.heart,
                    18,
                    fav ? _rose500 : idle,
                    enabled ? () => favorite(song!) : null,
                  ),
                  if (enabled)
                    _ctl(
                      LucideIcons.listPlus,
                      18,
                      idle,
                      () => addToPlaylist(song!),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ctl(
                        LucideIcons.shuffle,
                        18,
                        player.shuffle ? active : idle,
                        enabled ? player.toggleShuffle : null,
                      ),
                      const SizedBox(width: 8),
                      _ctl(
                        Icons.skip_previous_rounded,
                        26,
                        _slate500,
                        enabled ? player.previous : null,
                      ),
                      const SizedBox(width: 8),
                      _playCircle(40, 24, player.audio.playing, enabled),
                      const SizedBox(width: 8),
                      _ctl(
                        Icons.skip_next_rounded,
                        26,
                        _slate500,
                        enabled ? player.next : null,
                      ),
                      const SizedBox(width: 8),
                      _ctl(
                        player.repeat == 2
                            ? LucideIcons.repeat1
                            : LucideIcons.repeat,
                        18,
                        player.repeat > 0 ? active : idle,
                        enabled ? player.cycleRepeat : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: SeekBar(player: player, timeColor: _slate400),
                  ),
                ],
              ),
            ),
            VolumeControl(player: player, color: idle),
            const SizedBox(width: 4),
            _ctl(LucideIcons.listMusic, 18, idle, queueSheet, pad: 9),
          ],
        ),
      );
    },
  );

  // ---------------- Toàn màn hình (NowPlayingOverlay) ----------------
  Future<void> nowPlaying() async {
    if (player.current == null) return;
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, a, b) => _nowPlayingView(ctx, a),
        transitionsBuilder: (ctx, a, b, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  Widget _nowPlayingView(
    BuildContext ctx,
    Animation<double> anim,
  ) => StatefulBuilder(
    builder: (ctx, refresh) => ListenableBuilder(
      listenable: player,
      builder: (ctx, _) {
        final song = player.current;
        if (song == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted && Navigator.canPop(ctx)) Navigator.pop(ctx);
          });
          return const SizedBox.shrink();
        }
        final theme = Theme.of(ctx);
        final dark = theme.brightness == Brightness.dark;
        final cs = theme.colorScheme;
        final wide = MediaQuery.sizeOf(ctx).width >= 768;
        final fg = dark ? Colors.white : const Color(0xFF171717);
        final secondary = dark
            ? Colors.white.withValues(alpha: .7)
            : const Color(0xFF525252);
        final tertiary = dark
            ? Colors.white.withValues(alpha: .5)
            : const Color(0xFF737373);
        final soft = dark
            ? Colors.white.withValues(alpha: .6)
            : const Color(0xFF737373);
        final chip = dark
            ? Colors.white.withValues(alpha: .1)
            : Colors.black.withValues(alpha: .05);
        final box = dark
            ? Colors.white.withValues(alpha: .05)
            : Colors.black.withValues(alpha: .05);
        final fav = favorites.contains(song['id']);
        final url = api.media(song['coverUrl']);
        final lyrics = song['lyrics']?.toString().trim() ?? '';
        final gradient = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF0B1F4D), Colors.black]
                  : const [Color(0xFFDCE7FF), Colors.white],
            ),
          ),
        );
        // Bàn xoay: đế bo góc + đĩa xoay (ảnh bìa làm nhãn) + cần gạt.
        Widget cover(double size) => _Turntable(
          size: size,
          coverUrl: url,
          playing: player.audio.playing,
          dark: dark,
          accent: cs.primary,
        );
        Widget circle(IconData i, double s, VoidCallback t) => GestureDetector(
          onTap: t,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: chip, shape: BoxShape.circle),
            child: Icon(i, size: s, color: fg),
          ),
        );
        final align = wide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center;
        final infoHeader = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: align,
          children: [
            Text(
              'BÀI HÁT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: tertiary,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                final list = List<Json>.of(player.queue);
                final i = player.index;
                Navigator.pop(ctx);
                openSong(list, i);
              },
              child: Text(
                song['title'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: wide ? TextAlign.left : TextAlign.center,
                style: TextStyle(
                  fontSize: wide ? 30 : 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song['artist'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, color: secondary),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ctl(
                  fav ? Icons.favorite : LucideIcons.heart,
                  22,
                  fav ? _rose500 : secondary,
                  () async {
                    await favorite(song);
                    if (ctx.mounted) refresh(() {});
                  },
                  pad: 8,
                ),
                _ctl(LucideIcons.share2, 20, secondary, () {
                  Clipboard.setData(
                    ClipboardData(text: '${Api.baseUrl}/song/${song['id']}'),
                  );
                  message('Đã sao chép liên kết bài hát');
                }, pad: 8),
                _ctl(
                  LucideIcons.listPlus,
                  20,
                  secondary,
                  () => addToPlaylist(song),
                  pad: 8,
                ),
              ],
            ),
          ],
        );
        // Hộp lời bài hát: phần DUY NHẤT của màn hình này có thể cuộn.
        final lyricsBox = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: box,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                lyrics.isEmpty
                    ? 'Lời bài hát sẽ sớm được cập nhật...'
                    : lyrics,
                style: TextStyle(fontSize: 14, color: soft),
              ),
            ),
          ),
        );
        Widget ctl(IconData i, double s, Color c, VoidCallback t) =>
            _ctl(i, s, c, t, pad: 8);
        final controls = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: Column(
            children: [
              SeekBar(player: player, timeColor: tertiary, stacked: true),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ctl(
                    LucideIcons.shuffle,
                    20,
                    player.shuffle ? cs.primary : soft,
                    player.toggleShuffle,
                  ),
                  SizedBox(width: wide ? 20 : 12),
                  ctl(Icons.skip_previous_rounded, 34, fg, player.previous),
                  SizedBox(width: wide ? 20 : 12),
                  GestureDetector(
                    onTap: () => guard(player.toggle),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        player.audio.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 34,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(width: wide ? 20 : 12),
                  ctl(Icons.skip_next_rounded, 34, fg, player.next),
                  SizedBox(width: wide ? 20 : 12),
                  ctl(
                    player.repeat == 2
                        ? LucideIcons.repeat1
                        : LucideIcons.repeat,
                    20,
                    player.repeat > 0 ? cs.primary : soft,
                    player.cycleRepeat,
                  ),
                ],
              ),
              if (wide) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: dark
                              ? Colors.white.withValues(alpha: .2)
                              : Colors.black.withValues(alpha: .15),
                        ),
                      ),
                      child: Text(
                        '128 kbps',
                        style: TextStyle(fontSize: 12, color: soft),
                      ),
                    ),
                    const SizedBox(width: 16),
                    VolumeControl(player: player, color: soft),
                    const SizedBox(width: 16),
                    _ctl(LucideIcons.listMusic, 18, soft, queueSheet),
                  ],
                ),
              ],
            ],
          ),
        );

        final inset = MediaQuery.paddingOf(ctx);
        final edge = wide ? 40.0 : 20.0;
        final topBar = Row(
          mainAxisAlignment: wide
              ? MainAxisAlignment.end
              : MainAxisAlignment.spaceBetween,
          children: [
            if (!wide) circle(LucideIcons.listMusic, 18, queueSheet),
            circle(LucideIcons.chevronDown, 20, () => Navigator.pop(ctx)),
          ],
        );

        return DefaultTextStyle(
          style: TextStyle(
            fontSize: 14,
            color: fg,
            decoration: TextDecoration.none,
          ),
          child: Focus(
            autofocus: true,
            onKeyEvent: (_, e) {
              if (e is KeyDownEvent &&
                  e.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.pop(ctx);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Nền đặc để không lộ trang phía sau (route opaque: false).
                ColoredBox(color: dark ? Colors.black : Colors.white),
                // Nền kính mờ: ảnh bìa làm mờ trực tiếp (không dùng
                // BackdropFilter nên mép màn hình không bị nhạt / xám).
                ClipRect(
                  child: Transform.scale(
                    scale: 1.25,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: url.isEmpty
                          ? gradient
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => gradient,
                            ),
                    ),
                  ),
                ),
                ColoredBox(
                  color: dark
                      ? Colors.black.withValues(alpha: .45)
                      : Colors.white.withValues(alpha: .55),
                ),
                // Không SafeArea, không SingleChildScrollView: inset được
                // cộng vào padding nên nền phủ kín tới mép màn hình.
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .03),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      edge,
                      inset.top + 16,
                      edge,
                      inset.bottom + 16,
                    ),
                    child: LayoutBuilder(
                      builder: (_, area) {
                        // Ảnh bìa co theo chiều cao còn lại để cả màn vừa khít.
                        final coverSize = wide
                            ? 288.0
                            : (area.maxHeight * .26).clamp(120.0, 224.0).toDouble();
                        return Column(
                          children: [
                            topBar,
                            SizedBox(height: wide ? 24 : 12),
                            Expanded(
                              child: wide
                                  ? Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 1024,
                                        ),
                                        child: Row(
                                          children: [
                                            cover(coverSize),
                                            const SizedBox(width: 56),
                                            Expanded(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  infoHeader,
                                                  const SizedBox(height: 20),
                                                  Flexible(child: lyricsBox),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        cover(coverSize),
                                        const SizedBox(height: 20),
                                        infoHeader,
                                        const SizedBox(height: 16),
                                        Flexible(child: lyricsBox),
                                      ],
                                    ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: wide ? 24 : 12),
                              child: controls,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ---------------- Bàn xoay (turntable) cho màn hình đang phát ----------------
// Bản Flutter của khối "đĩa than" ở NowPlayingOverlay.tsx: đế bo góc, đĩa xoay
// có ảnh bìa làm nhãn, cần gạt hạ xuống khi phát / nhấc ra khi tạm dừng.

const double _deg = 0.017453292519943295; // 1 độ -> radian

class _TurntableColors {
  final Color baseA, baseB, ring, discA, discB, discEdge, sheen;
  final Color metalEdge, metalMid, head, headStroke;
  final Color pivot, pivotIn, pivotStroke, labelRing;
  const _TurntableColors({
    required this.baseA,
    required this.baseB,
    required this.ring,
    required this.discA,
    required this.discB,
    required this.discEdge,
    required this.sheen,
    required this.metalEdge,
    required this.metalMid,
    required this.head,
    required this.headStroke,
    required this.pivot,
    required this.pivotIn,
    required this.pivotStroke,
    required this.labelRing,
  });

  static const light = _TurntableColors(
    baseA: Color(0xFFFFFFFF),
    baseB: Color(0xFFF3F4F6),
    ring: Color(0xFFF1F2F4),
    discA: Color(0xFFFFFFFF),
    discB: Color(0xFFF1F1F2),
    discEdge: Color(0x0A000000),
    sheen: Color(0x0D000000),
    metalEdge: Color(0xFF8D9096),
    metalMid: Color(0xFFE9EAEC),
    head: Color(0xFFFAFAFA),
    headStroke: Color(0xFFD4D6DA),
    pivot: Color(0xFFF4F5F6),
    pivotIn: Color(0xFFFFFFFF),
    pivotStroke: Color(0xFFD9DBDF),
    labelRing: Color(0xE6CBD5E1),
  );

  static const dark = _TurntableColors(
    baseA: Color(0xFF2B2E34),
    baseB: Color(0xFF1B1D21),
    ring: Color(0xFF15171A),
    discA: Color(0xFF121214),
    discB: Color(0xFF222226),
    discEdge: Color(0x14FFFFFF),
    sheen: Color(0x17FFFFFF),
    metalEdge: Color(0xFF5B5F67),
    metalMid: Color(0xFFC8CBD1),
    head: Color(0xFF3A3D44),
    headStroke: Color(0xFF50535B),
    pivot: Color(0xFF34373D),
    pivotIn: Color(0xFF43464D),
    pivotStroke: Color(0xFF55585F),
    labelRing: Color(0x40FFFFFF),
  );
}

class _Turntable extends StatefulWidget {
  final double size;
  final String coverUrl;
  final bool playing, dark;
  final Color accent;
  const _Turntable({
    required this.size,
    required this.coverUrl,
    required this.playing,
    required this.dark,
    required this.accent,
  });
  @override
  State<_Turntable> createState() => _TurntableState();
}

class _TurntableState extends State<_Turntable>
    with SingleTickerProviderStateMixin {
  // 1 vòng / 8 giây. stop() giữ nguyên góc hiện tại, repeat() xoay tiếp từ đó
  // nên tạm dừng / phát lại đĩa không bị giật về góc 0.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Turntable old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    // Tôn trọng cài đặt "giảm chuyển động" của hệ điều hành.
    final spin = widget.playing && !MediaQuery.disableAnimationsOf(context);
    if (spin && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!spin && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.dark ? _TurntableColors.dark : _TurntableColors.light;
    final s = widget.size;
    final discSize = s * .75;
    final icon = Icon(LucideIcons.music2, size: s * .14, color: widget.accent);

    final label = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.accent.withValues(alpha: .15),
        border: Border.all(color: c.labelRing, width: 3),
      ),
      child: widget.coverUrl.isEmpty
          ? Center(child: icon)
          : Image.network(
              widget.coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(child: icon),
            ),
    );

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Đế
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(s * .1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.baseA, c.baseB],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .35),
                    blurRadius: 50,
                    spreadRadius: -12,
                    offset: const Offset(0, 25),
                  ),
                ],
              ),
            ),
          ),
          // Vòng đệm quanh đĩa
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(s * .1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.ring,
                  border: Border.all(color: c.discEdge),
                ),
              ),
            ),
          ),
          // Đĩa xoay
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(s * .125),
              child: RepaintBoundary(
                child: RotationTransition(
                  turns: _spin,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .3),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _DiscPainter(c),
                      child: Padding(
                        padding: EdgeInsets.all(discSize * .19),
                        child: label,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Cần gạt: xoay quanh trục ở (90%, 10%) của đế.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedRotation(
                turns: widget.playing ? 0 : -26 / 360,
                alignment: const Alignment(.8, -.8),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                child: CustomPaint(painter: _ArmPainter(c)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mặt đĩa: rãnh đồng tâm + vệt phản chiếu (để thấy rõ đĩa đang quay).
class _DiscPainter extends CustomPainter {
  final _TurntableColors c;
  const _DiscPainter(this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(center, r, Paint()..color = c.discA);

    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = c.discB;
    for (var rad = r * .3; rad < r; rad += 5) {
      canvas.drawCircle(center, rad, groove);
    }

    final clear = c.sheen.withValues(alpha: 0);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [clear, c.sheen, clear, clear, c.sheen, clear, clear],
          stops: const [0, 50 / 360, 100 / 360, 180 / 360, 230 / 360, 280 / 360, 1],
        ).createShader(Offset.zero & size),
    );

    canvas.drawCircle(
      center,
      r - .5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.discEdge,
    );
  }

  @override
  bool shouldRepaint(_DiscPainter old) => old.c != c;
}

/// Cần gạt vẽ trong hệ toạ độ 0..100 (khớp bản SVG ở bản web).
class _ArmPainter extends CustomPainter {
  final _TurntableColors c;
  const _ArmPainter(this.c);

  static const _pivot = Offset(90, 10);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final arm = Path()
      ..moveTo(90, 10)
      ..lineTo(80.6, 60)
      ..quadraticBezierTo(78.6, 68, 72.4, 74);
    final headRect = RRect.fromLTRBR(66.6, 72.6, 73.6, 77.6, const Radius.circular(2.2));

    void withHeadTransform(void Function() draw) {
      canvas.save();
      canvas.translate(70, 75);
      canvas.rotate(35 * _deg);
      canvas.translate(-70, -75);
      draw();
      canvas.restore();
    }

    // Bóng đổ
    final shadow = Paint()
      ..color = const Color(0x47000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .9);
    canvas.save();
    canvas.translate(.6, 1.2);
    canvas.drawPath(
      arm,
      shadow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
    shadow.style = PaintingStyle.fill;
    canvas.drawCircle(_pivot, 6.2, shadow);
    withHeadTransform(() => canvas.drawRRect(headRect, shadow));
    canvas.restore();

    // Đối trọng
    LinearGradient metal(Rect r) => LinearGradient(colors: [c.metalEdge, c.metalMid, c.metalEdge]);
    final cwRect = const Rect.fromLTWH(88.4, -2, 3.6, 8);
    canvas.save();
    canvas.translate(90, 10);
    canvas.rotate(8 * _deg);
    canvas.translate(-90, -10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cwRect, const Radius.circular(.6)),
      Paint()..shader = metal(cwRect).createShader(cwRect),
    );
    canvas.restore();

    // Thân cần
    final armBounds = const Rect.fromLTRB(72, 10, 90.7, 74);
    canvas.drawPath(
      arm,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..shader = metal(armBounds).createShader(armBounds),
    );

    // Đầu kim
    withHeadTransform(() {
      canvas.drawRRect(headRect, Paint()..color = c.head);
      canvas.drawRRect(
        headRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .3
          ..color = c.headStroke,
      );
      canvas.drawCircle(const Offset(68.6, 75.1), .9, Paint()..color = c.pivotIn);
      canvas.drawCircle(
        const Offset(68.6, 75.1),
        .9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .3
          ..color = c.headStroke,
      );
    });

    // Chân trục
    final ringLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .3
      ..color = c.pivotStroke;
    canvas.drawCircle(_pivot, 6.2, Paint()..color = c.pivot);
    canvas.drawCircle(_pivot, 6.2, ringLine);
    canvas.drawCircle(_pivot, 3.8, Paint()..color = c.pivotIn);
    canvas.drawCircle(_pivot, 3.8, ringLine);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArmPainter old) => old.c != c;
}
