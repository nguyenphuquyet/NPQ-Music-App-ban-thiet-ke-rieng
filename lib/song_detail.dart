part of 'main.dart';

extension _SongDetails on _MusicHomeState {
  Future<void> openSong(List<Json> source, int index) async {
    final ticket = ++requestId;
    Json detail;
    try {
      detail = Map<String, dynamic>.from(
        await api.request('/api/songs/${source[index]['id']}'),
      );
    } catch (e) {
      message(e);
      return;
    }
    if (!mounted || ticket != requestId) return;
    if (section != 'Chi tiết bài hát') {
      detailHistory.clear();
      detailBackSection = section;
      detailBackPlaylist = playlist;
    }
    debounce?.cancel();
    updateUI(() {
      final nested = section == 'Chi tiết bài hát' && songDetail != null;
      if (nested) {
        detailHistory.add((
          song: songDetail!,
          queue: List.of(detailQueue),
          routeId: detailRouteId,
        ));
      }
      // Related rows exclude the current song; retain the complete queue
      // when drilling into another detail page.
      detailQueue = nested
          ? {
              for (final song in [...detailQueue, ...source]) song['id']: song,
            }.values.toList()
          : List.of(source);
      detailRouteId = ++nextDetailRouteId;
      songDetail = detail;
      section = 'Chi tiết bài hát';
      playlist = null;
      loading = false;
      error = null;
    });
  }

  void closeSong() {
    if (detailHistory.isNotEmpty) {
      updateUI(() {
        final previous = detailHistory.removeLast();
        songDetail = previous.song;
        detailQueue = previous.queue;
        detailRouteId = previous.routeId;
      });
      return;
    }
    updateUI(() {
      section = detailBackSection;
      playlist = detailBackPlaylist;
      songDetail = null;
    });
    // Danh sách phía sau vẫn còn nguyên: chỉ cập nhật ngầm, không hiện loading.
    load(silent: songs.isNotEmpty);
  }

  Future<void> playDetail() async {
    final song = songDetail!;
    if (player.current?['id'] == song['id']) {
      await guard(player.toggle);
      return;
    }
    final index = detailQueue.indexWhere((s) => s['id'] == song['id']);
    await player.play(index < 0 ? [song] : detailQueue, index < 0 ? 0 : index);
  }

  Widget detailHeading(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, size: 20, color: mutedColor),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget detailStatItem(IconData icon, String value, String label) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 18, color: TDTheme.of(context).brandNormalColor),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: mutedColor)),
      ],
    ),
  );

  Widget detailCircleButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    Color? color,
    Color? background,
  }) => Tooltip(
    message: tooltip,
    child: AppTap(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              background ??
              Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 21,
          color: color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );

  Widget songDetailPage(bool wide) {
    final song = songDetail!;
    final brand = TDTheme.of(context).brandNormalColor;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final pageColor = theme.scaffoldBackgroundColor;
    final uploader = song['uploader'] as Map?;
    final date = DateTime.tryParse(song['createdAt']?.toString() ?? '');
    final lyrics = song['lyrics']?.toString().trim() ?? '';
    final genreText = song['genre']?.toString() ?? '';
    final coverUrl = api.media(song['coverUrl']);
    final side = wide ? 32.0 : 20.0;
    final align = wide ? CrossAxisAlignment.start : CrossAxisAlignment.center;

    // Nền: ảnh bìa làm mờ, mờ dần vào màu nền trang ở phía dưới.
    final backdrop = Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Ảnh mờ dừng cách đáy 8px: ClipRect cắt cứng theo pixel nguyên còn
              // lớp phủ gradient lại khử răng cưa theo nửa pixel, nên nếu ảnh
              // chạm sát đáy thì hàng pixel cuối lộ ra thành một vạch ngang.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 8,
                child: ClipRect(
                  child: Transform.scale(
                    scale: 1.3,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                      child: coverUrl.isEmpty
                          ? ColoredBox(color: brand.withValues(alpha: .3))
                          : Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, e, s) => ColoredBox(
                                color: brand.withValues(alpha: .3),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              ColoredBox(color: pageColor.withValues(alpha: dark ? .45 : .3)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [pageColor.withValues(alpha: 0), pageColor],
                    stops: const [.35, .98],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final coverCard = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .3),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: wide
          ? cover(song, 260, radius: 20)
          : LayoutBuilder(
              builder: (_, bounds) => cover(
                song,
                (bounds.maxWidth - 56).clamp(160, 300),
                radius: 20,
              ),
            ),
    );

    final titleBlock = Column(
      crossAxisAlignment: align,
      children: [
        if (genreText.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: brand.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              genreText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: brand,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          song['title']?.toString() ?? '',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            fontSize: wide ? 32 : 26,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          song['artist']?.toString() ?? '',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: TextStyle(fontSize: 16, color: mutedColor),
        ),
      ],
    );

    final actions = ListenableBuilder(
      listenable: player,
      builder: (_, child) {
        final active =
            player.current?['id'] == song['id'] && player.audio.playing;
        final liked = favorites.contains(song['id']);
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: TDButton(
                  text: active ? 'Tạm dừng' : 'Phát bài hát',
                  icon: active ? LucideIcons.pause : LucideIcons.play,
                  isBlock: true,
                  theme: TDButtonTheme.primary,
                  shape: TDButtonShape.round,
                  onTap: playDetail,
                ),
              ),
            ),
            const SizedBox(width: 12),
            detailCircleButton(
              LucideIcons.heart,
              'Yêu thích',
              () => favorite(song),
              color: liked ? const Color(0xFFF43F5E) : null,
              background: liked
                  ? const Color(0xFFF43F5E).withValues(alpha: .14)
                  : null,
            ),
            const SizedBox(width: 10),
            detailCircleButton(
              LucideIcons.listPlus,
              'Thêm vào playlist',
              () => addToPlaylist(song),
            ),
          ],
        );
      },
    );

    final stats = AppPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            detailStatItem(
              LucideIcons.headphones,
              '${song['playCount'] ?? 0}',
              'Lượt nghe',
            ),
            Container(width: 1, height: 36, color: theme.dividerColor),
            detailStatItem(
              LucideIcons.heart,
              '${song['favoritesCount'] ?? 0}',
              'Yêu thích',
            ),
            Container(width: 1, height: 36, color: theme.dividerColor),
            detailStatItem(
              LucideIcons.clock3,
              time(Duration(seconds: (song['duration'] as num?)?.toInt() ?? 0)),
              'Thời lượng',
            ),
          ],
        ),
      ),
    );

    final header = Stack(
      children: [
        backdrop,
        Padding(
          padding: EdgeInsets.fromLTRB(side, glassTop + 24, side, 8),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    coverCard,
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleBlock,
                          const SizedBox(height: 24),
                          actions,
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Center(child: coverCard),
                    const SizedBox(height: 28),
                    titleBlock,
                  ],
                ),
        ),
      ],
    );

    final related = detailQueue
        .where((s) => s['id'] != song['id'])
        .take(5)
        .toList();

    return ListView(
      padding: EdgeInsets.only(bottom: 28 + glassBottom),
      children: [
        header,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!wide) ...[
                actions,
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 16),
              stats,
              AppPanel(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: brand.withValues(alpha: .12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.userRound,
                          color: brand,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đăng tải bởi',
                              style: TextStyle(fontSize: 12, color: mutedColor),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              uploader?['name']?.toString() ?? 'Thành viên NPQ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (date != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.calendar,
                              size: 14,
                              color: mutedColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${date.day}/${date.month}/${date.year}',
                              style: TextStyle(fontSize: 12, color: mutedColor),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              detailHeading(LucideIcons.alignLeft, 'Lời bài hát'),
              AppPanel(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Text(
                    lyrics.isEmpty ? 'Bài hát này chưa có lời.' : lyrics,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 2,
                      fontSize: 15,
                      color: lyrics.isEmpty
                          ? mutedColor
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              if (related.isNotEmpty) ...[
                const SizedBox(height: 12),
                detailHeading(LucideIcons.listMusic, 'Nghe tiếp'),
                ...List.generate(
                  related.length,
                  (i) => songTile(related, i, wide),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget detailStat(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: mutedColor),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(fontSize: 11, color: mutedColor)),
    ],
  );
}

extension _PlaylistNavigation on _MusicHomeState {
  Future<void> openPlaylist(Json selected) async {
    final ticket = ++requestId;
    try {
      final detail = Map<String, dynamic>.from(
        await api.request('/api/playlists/${selected['id']}'),
      );
      if (!mounted || ticket != requestId) return;
      updateUI(() {
        playlist = detail;
        songs = (detail['songs'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        loading = false;
        error = null;
        more = false;
      });
    } catch (e) {
      message(e);
    }
  }
}
