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

/// Thanh tua + thời gian (tương đương <input type="range"> trong web).
class SeekBar extends StatefulWidget {
  final MusicPlayer player;
  final Color timeColor;
  const SeekBar({super.key, required this.player, required this.timeColor});
  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? drag; // giữ giá trị khi đang kéo để thanh không bị giật ngược
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.player,
    builder: (ctx, _) {
      final a = widget.player.audio;
      final fallback =
          ((widget.player.current?['duration'] as num?) ?? 0) * 1000.0;
      final total = (a.duration?.inMilliseconds ?? 0) > 0
          ? a.duration!.inMilliseconds.toDouble()
          : fallback.toDouble();
      final max = total > 0 ? total : 1.0;
      final value = (drag ?? a.position.inMilliseconds.toDouble()).clamp(
        0.0,
        max,
      );
      final style = TextStyle(fontSize: 11, color: widget.timeColor);
      return Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(_fmt(value), textAlign: TextAlign.right, style: style),
          ),
          Expanded(
            child: SizedBox(
              height: 24,
              child: SliderTheme(
                data: _sliderTheme(ctx),
                child: Slider(
                  value: value,
                  min: 0,
                  max: max,
                  onChangeStart: (v) => setState(() => drag = v),
                  onChanged: total <= 0 ? null : (v) => setState(() => drag = v),
                  onChangeEnd: (v) {
                    widget.player.audio.seek(
                      Duration(milliseconds: v.toInt()),
                    );
                    setState(() => drag = null);
                  },
                ),
              ),
            ),
          ),
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
        height: 24,
        child: SliderTheme(
          data: _sliderTheme(context),
          child: Slider(value: v, onChanged: set),
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

  BoxDecoration _barDecoration(ColorScheme cs) => BoxDecoration(
    color: cs.surface.withValues(alpha: .95),
    border: Border(
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
      final total = player.audio.duration?.inMilliseconds ?? 0;
      final progress = total <= 0
          ? 0.0
          : (player.audio.position.inMilliseconds / total).clamp(0.0, 1.0);
      final enabled = song != null;
      void open() {
        if (enabled) nowPlaying();
      }

      return Container(
        decoration: _barDecoration(cs),
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

  Widget _nowPlayingView(BuildContext ctx, Animation<double> anim) =>
      StatefulBuilder(
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
            final cover = Container(
              width: wide ? 288 : 224,
              height: wide ? 288 : 224,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: chip,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 50,
                    offset: const Offset(0, 25),
                  ),
                ],
              ),
              child: url.isEmpty
                  ? Icon(LucideIcons.music2, size: 48, color: soft)
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Icon(LucideIcons.music2, size: 48, color: soft),
                    ),
            );
            Widget circle(IconData i, double s, VoidCallback t) =>
                GestureDetector(
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
            final info = Column(
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
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: box,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      lyrics.isEmpty
                          ? 'Lời bài hát sẽ sớm được cập nhật...'
                          : lyrics,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: soft),
                    ),
                  ),
                ),
              ],
            );
            Widget ctl(IconData i, double s, Color c, VoidCallback t) =>
                _ctl(i, s, c, t, pad: 8);
            final controls = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 672),
              child: Column(
                children: [
                  SeekBar(player: player, timeColor: tertiary),
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
                      ctl(
                        Icons.skip_previous_rounded,
                        34,
                        fg,
                        player.previous,
                      ),
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
                    // Nền kính mờ: ảnh bìa + lớp blur + lớp phủ theo theme.
                    if (url.isEmpty)
                      gradient
                    else
                      Transform.scale(
                        scale: 1.1,
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => gradient,
                        ),
                      ),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: ColoredBox(
                        color: dark
                            ? Colors.black.withValues(alpha: .45)
                            : Colors.white.withValues(alpha: .55),
                      ),
                    ),
                    SafeArea(
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, .03),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(parent: anim, curve: Curves.easeOut),
                        ),
                        child: LayoutBuilder(
                          builder: (_, bounds) => SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: wide ? 40 : 20,
                              vertical: wide ? 32 : 20,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight:
                                    bounds.maxHeight - (wide ? 64 : 40),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: wide
                                            ? MainAxisAlignment.end
                                            : MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (!wide)
                                            circle(
                                              LucideIcons.listMusic,
                                              18,
                                              queueSheet,
                                            ),
                                          circle(
                                            LucideIcons.chevronDown,
                                            20,
                                            () => Navigator.pop(ctx),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: wide ? 40 : 16),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 1024,
                                        ),
                                        child: wide
                                            ? Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  cover,
                                                  const SizedBox(width: 56),
                                                  Expanded(child: info),
                                                ],
                                              )
                                            : Column(
                                                children: [
                                                  cover,
                                                  const SizedBox(height: 32),
                                                  info,
                                                ],
                                              ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: wide ? 40 : 32,
                                    ),
                                    child: controls,
                                  ),
                                ],
                              ),
                            ),
                          ),
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
