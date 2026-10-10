part of 'main.dart';

// Trang "Khám phá" (section 'Dành cho bạn'): feed dọc kiểu Douyin/TikTok.
// Mỗi trang = 1 bài: nền là ảnh bìa làm mờ, thẻ bìa ở giữa (chạm để phát /
// tạm dừng), cột nút bên phải (tim, thêm playlist, chia sẻ), thông tin bài
// ở dưới. Vuốt sang bài khác sẽ tự phát (sau khi người dùng đã chạm vào feed).
extension _ForYouFeed on _MusicHomeState {
  // Bài hát tự chuyển (hết bài -> bài kế) thì feed tự cuộn theo.
  void syncFeedWithPlayer() {
    if (section != 'Dành cho bạn' || !feedController.hasClients) return;
    final current = player.current;
    if (current == null) return;
    final id = current['id']?.toString();
    if (id == feedLastId) return; // chỉ phản ứng khi bài đang phát ĐỔI
    feedLastId = id;
    final i = songs.indexWhere((s) => s['id']?.toString() == id);
    if (i < 0 || i == feedIndex) return;
    feedController.animateToPage(
      i,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void onFeedPage(int i) {
    updateUI(() => feedIndex = i);
    // Nạp sớm khi còn cách cuối 3 bài để vuốt tới nơi là có bài mới sẵn.
    if (more && !loadingMore && i >= songs.length - 3) {
      load(append: true);
    }
    // Chỉ tự phát khi người dùng thật sự đã chạm vào feed (tránh tự phát
    // ngay lúc vừa mở trang).
    if (!feedTouched || i >= songs.length) return;
    final song = songs[i];
    if (player.current?['id'] != song['id']) {
      guard(() => player.play(songs, i));
    }
  }

  Widget forYouFeed(bool wide) {
    if (songs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Nghe thêm vài bài để chúng tôi hiểu gu nhạc của bạn nhé!',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedColor),
          ),
        ),
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Listener(
      onPointerDown: (_) => feedTouched = true,
      child: PageView.builder(
        controller: feedController,
        scrollDirection: Axis.vertical,
        itemCount: songs.length,
        onPageChanged: onFeedPage,
        itemBuilder: (_, i) => feedSlide(i, dark, wide),
      ),
    );
  }

  String feedCount(dynamic value) {
    final n = (value as num?)?.toInt() ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}tr';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Future<void> shareSong(Json song) async {
    await Clipboard.setData(
      ClipboardData(text: '${Api.baseUrl}/song/${song['id']}'),
    );
    message('Đã sao chép liên kết bài hát');
  }

  Widget feedAction(IconData icon, String label, VoidCallback onTap,
      {Color? color, double size = 28}) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: size, color: color ?? ink),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget feedSlide(int i, bool dark, bool wide) {
    final song = songs[i];
    final url = api.media(song['coverUrl']);
    final base = dark ? Colors.black : Colors.white;
    final cardSize = wide ? 280.0 : 232.0;

    // Phần nền (ảnh mờ + lớp phủ) tĩnh, tách khỏi ListenableBuilder để không
    // bị dựng lại mỗi lần vị trí phát thay đổi.
    final background = RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: Transform.scale(
              scale: 1.25,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: url.isEmpty
                    ? ColoredBox(color: accentColor.withValues(alpha: .35))
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) =>
                            ColoredBox(color: accentColor.withValues(alpha: .35)),
                      ),
              ),
            ),
          ),
          // Tối: làm tối ảnh + gradient đen. Sáng: làm sáng ảnh + gradient trắng.
          ColoredBox(
            color: dark
                ? Colors.black.withValues(alpha: .45)
                : Colors.white.withValues(alpha: .12),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  base.withValues(alpha: dark ? .85 : .9),
                  base.withValues(alpha: dark ? .2 : .4),
                  base.withValues(alpha: dark ? .4 : .5),
                ],
                stops: const [0, .5, 1],
              ),
            ),
          ),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        ListenableBuilder(
          listenable: player,
          builder: (ctx, _) {
            final active = player.current?['id'] == song['id'];
            final playing = active && player.audio.playing;
            final liked = favorites.contains(song['id']);
            final ink = Theme.of(ctx).colorScheme.onSurface;
            return Padding(
              // Chừa chỗ cho header / mini player + tab bar kính mờ.
              padding: EdgeInsets.only(top: glassTop, bottom: glassBottom),
              child: Stack(
                children: [
                  // Thẻ bìa ở giữa, chạm để phát / tạm dừng.
                  Align(
                    alignment: const Alignment(0, -.16),
                    child: GestureDetector(
                      onTap: () => guard(() async {
                        if (active) {
                          await player.toggle();
                        } else {
                          await player.play(songs, i);
                        }
                      }),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .35),
                                  blurRadius: 40,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: cover(song, cardSize, radius: 18),
                          ),
                          if (!playing)
                            Container(
                              width: cardSize,
                              height: cardSize,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .28),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                LucideIcons.play,
                                size: 44,
                                color: Colors.white,
                              ),
                            ),
                          if (playing)
                            Positioned(
                              bottom: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: TDTheme.of(ctx).brandNormalColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Đang phát',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Cột nút bên phải.
                  Positioned(
                    right: 8,
                    bottom: 112,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        feedAction(
                          liked ? Icons.favorite : LucideIcons.heart,
                          feedCount(song['favoritesCount']),
                          () => favorite(song),
                          color: liked ? const Color(0xFFF43F5E) : ink,
                          size: 30,
                        ),
                        const SizedBox(height: 18),
                        feedAction(
                          LucideIcons.listPlus,
                          'Playlist',
                          () => addToPlaylist(song),
                          size: 26,
                        ),
                        const SizedBox(height: 18),
                        feedAction(
                          LucideIcons.share2,
                          'Chia sẻ',
                          () => shareSong(song),
                        ),
                      ],
                    ),
                  ),
                  // Thông tin bài hát ở dưới (không nhận chạm).
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 76, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song['title']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song['artist']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: ink.withValues(alpha: .8),
                              ),
                            ),
                            if ((song['genre']?.toString() ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '#${song['genre']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ink.withValues(alpha: .6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
