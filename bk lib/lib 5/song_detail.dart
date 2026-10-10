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
      detailBackSection = section;
      detailBackPlaylist = playlist;
    }
    reversePage = false;
    debounce?.cancel();
    updateUI(() {
      detailQueue = List.of(source);
      songDetail = detail;
      section = 'Chi tiết bài hát';
      playlist = null;
      loading = false;
      error = null;
    });
  }

  void closeSong() {
    reversePage = true;
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

  Widget songDetailPage(bool wide) {
    final song = songDetail!;
    final uploader = song['uploader'] as Map?;
    final date = DateTime.tryParse(song['createdAt']?.toString() ?? '');
    final lyrics = song['lyrics']?.toString().trim() ?? '';
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          song['genre']?.toString().toUpperCase() ?? 'ÂM NHẠC',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.7,
            color: TDTheme.of(context).brandNormalColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          song['title'] ?? '',
          style: TextStyle(
            fontSize: wide ? 30 : 25,
            height: 1.25,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          song['artist'] ?? '',
          style: TextStyle(fontSize: 16, color: mutedColor),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            detailStat(
              LucideIcons.headphones,
              '${song['playCount'] ?? 0} lượt nghe',
            ),
            detailStat(
              LucideIcons.clock3,
              time(Duration(seconds: (song['duration'] as num?)?.toInt() ?? 0)),
            ),
            detailStat(
              LucideIcons.heart,
              '${song['favoritesCount'] ?? 0} yêu thích',
            ),
          ],
        ),
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: player,
          builder: (_, child) {
            final active =
                player.current?['id'] == song['id'] && player.audio.playing;
            return Row(
              children: [
                Expanded(
                  child: TDButton(
                    text: active ? 'Tạm dừng' : 'Phát bài hát',
                    icon: active ? LucideIcons.pause : LucideIcons.play,
                    theme: TDButtonTheme.primary,
                    shape: TDButtonShape.rectangle,
                    onTap: playDetail,
                  ),
                ),
                const SizedBox(width: 12),
                AppIconButton(
                  tooltip: 'Yêu thích',
                  onPressed: () => favorite(song),
                  icon: Icon(
                    LucideIcons.heart,
                    color: favorites.contains(song['id'])
                        ? TDTheme.of(context).brandNormalColor
                        : mutedColor,
                  ),
                ),
                AppIconButton(
                  tooltip: 'Thêm vào playlist',
                  onPressed: () => addToPlaylist(song),
                  icon: const Icon(LucideIcons.listPlus),
                ),
              ],
            );
          },
        ),
      ],
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        wide ? 32 : 20,
        (wide ? 32 : 20) + glassTop,
        wide ? 32 : 20,
        (wide ? 32 : 20) + glassBottom,
      ),
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cover(song, 240),
              const SizedBox(width: 28),
              Expanded(child: info),
            ],
          )
        else ...[
          Center(
            child: LayoutBuilder(
              builder: (_, bounds) =>
                  cover(song, (bounds.maxWidth - 32).clamp(160, 320)),
            ),
          ),
          const SizedBox(height: 28),
          info,
        ],
        const SizedBox(height: 28),
        AppPanel(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: TDTheme.of(
                      context,
                    ).brandNormalColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.userRound,
                    color: TDTheme.of(context).brandNormalColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đăng tải bởi',
                        style: TextStyle(fontSize: 11, color: mutedColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        uploader?['name']?.toString() ?? 'Thành viên NPQ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (date != null)
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: TextStyle(fontSize: 11, color: mutedColor),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Lời bài hát',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              lyrics.isEmpty ? 'Bài hát này chưa có lời.' : lyrics,
              style: TextStyle(
                height: 1.9,
                fontSize: 14,
                color: lyrics.isEmpty
                    ? mutedColor
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        if (detailQueue.any((s) => s['id'] != song['id'])) ...[
          const SizedBox(height: 18),
          const Text(
            'Nghe tiếp',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ...() {
            final related = detailQueue
                .where((s) => s['id'] != song['id'])
                .take(5)
                .toList();
            return List.generate(
              related.length,
              (i) => songTile(related, i, wide),
            );
          }(),
        ],
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
      reversePage = false;
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
