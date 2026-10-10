part of 'main.dart';

extension _MobileInterface on _MusicHomeState {
  int get mobileTab =>
      ['Khám phá', 'Tìm kiếm', 'Chi tiết bài hát'].contains(section)
      ? 0
      : section == 'Dành cho bạn'
      ? 1
      : section == 'Cá nhân'
      ? 3
      : 2;

  Widget phoneScaffold() => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ColoredBox(
          color: TDTheme.of(context).bgColorPage,
          child: SafeArea(
            child: GlassScaffold(
              top: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  mobileHeader(),
                  if (mobileTab == 2) libraryTabs(),
                ],
              ),
              body: (t, b) {
                glassTop = t;
                glassBottom = b;
                return pageBody(false);
              },
              bottom: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                miniPlayer(),
                TDBottomTabBar(
                  TDBottomTabBarBasicType.iconText,
                  componentType: TDBottomTabBarComponentType.normal,
                  backgroundColor: Colors.transparent,
                  currentIndex: mobileTab,
                  showTopBorder: false,
                  barHeight: 62,
                  useSafeArea: false,
                  navigationTabs: List.generate(
                    4,
                    (i) => TDBottomTabBarTabConfig(
                      selectTabTextStyle: TextStyle(
                        fontSize: 10,
                        color: TDTheme.of(context).brandNormalColor,
                      ),
                      unselectTabTextStyle: TextStyle(
                        fontSize: 10,
                        color: TDTheme.of(context).textColorSecondary,
                      ),
                      tabText: [
                        'Trang chủ',
                        'Khám phá',
                        'Thư viện',
                        'Cá nhân',
                      ][i],
                      selectedIcon: Icon(
                        [
                          LucideIcons.house,
                          LucideIcons.compass,
                          LucideIcons.library,
                          LucideIcons.userRound,
                        ][i],
                        color: TDTheme.of(context).brandNormalColor,
                        size: 22,
                      ),
                      unselectedIcon: Icon(
                        [
                          LucideIcons.house,
                          LucideIcons.compass,
                          LucideIcons.library,
                          LucideIcons.userRound,
                        ][i],
                        color: const Color(0xFF8791A6),
                        size: 22,
                      ),
                      onTap: () => navigate(
                        ['Khám phá', 'Dành cho bạn', 'Yêu thích', 'Cá nhân'][i],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget mobileScaffold() => LayoutBuilder(
    builder: (context, bounds) {
      if (bounds.maxWidth >= 760) {
        glassTop = 0;
        glassBottom = 0;
        return tabletScaffold();
      }
      return phoneScaffold();
    },
  );

  Widget tabletScaffold() => ColoredBox(
    color: TDTheme.of(context).bgColorPage,
    child: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 224,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      right: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.audioLines,
                            color: TDTheme.of(context).brandNormalColor,
                            size: 28,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'NPQ Music',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'THƯ VIỆN ÂM NHẠC',
                        style: TextStyle(
                          fontSize: 10,
                          color: mutedColor,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(
                        _MusicHomeState.destinations.length,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TDButton(
                            isBlock: true,
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            margin: EdgeInsets.zero,
                            theme: section == _MusicHomeState.destinations[i]
                                ? TDButtonTheme.primary
                                : TDButtonTheme.defaultTheme,
                            type: section == _MusicHomeState.destinations[i]
                                ? TDButtonType.fill
                                : TDButtonType.text,
                            onTap: () =>
                                navigate(_MusicHomeState.destinations[i]),
                            child: Row(
                              children: [
                                Icon(
                                  _MusicHomeState.icons[i],
                                  size: 20,
                                  color:
                                      section == _MusicHomeState.destinations[i]
                                      ? Colors.white
                                      : mutedColor,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _MusicHomeState.destinations[i],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        section ==
                                            _MusicHomeState.destinations[i]
                                        ? Colors.white
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TDButton(
                        text: 'Tải nhạc lên',
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        margin: EdgeInsets.zero,
                        icon: LucideIcons.cloudUpload,
                        isBlock: true,
                        type: TDButtonType.fill,
                        onTap: upload,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      mobileHeader(),

                      Expanded(child: pageBody(true)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          tabletPlayer(),
        ],
      ),
    ),
  );

  Widget mobileHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
    child: Row(
      children: [
        if (section == 'Tìm kiếm' || section == 'Chi tiết bài hát')
          AppIconButton(
            tooltip: 'Quay lại trang chủ',
            onPressed: section == 'Chi tiết bài hát'
                ? closeSong
                : () => navigate('Khám phá'),
            icon: const Icon(LucideIcons.arrowLeft, size: 21),
          )
        else
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: TDTheme.of(context).brandNormalColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              LucideIcons.audioLines,
              size: 19,
              color: Colors.white,
            ),
          ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            section == 'Chi tiết bài hát'
                ? 'Chi tiết bài hát'
                : section == 'Tìm kiếm'
                ? 'Tìm kiếm'
                : 'NPQ Music',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
        ),
        if (section != 'Tìm kiếm')
          AppIconButton(
            tooltip: 'Tìm kiếm',
            onPressed: () => navigate('Tìm kiếm'),
            icon: const Icon(LucideIcons.search, size: 21),
          ),
        Builder(
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AppIconButton(
              tooltip: isDark ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối',
              onPressed: widget.onTheme,
              icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon, size: 20),
            );
          },
        ),
      ],
    ),
  );

  Widget searchPanel() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: TDInput(
        showBottomDivider: false,
        hintTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        controller: search,
        autofocus: true,
        inputAction: TextInputAction.search,
        hintText: 'Tìm bài hát, nghệ sĩ',
        leftIcon: Icon(LucideIcons.search, size: 19, color: mutedColor),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        textStyle: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onChanged: (value) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 350), () {
            if (!mounted) return;
            updateUI(() => query = value.trim());
            load();
          });
        },
      ),
    ),
  );

  Widget libraryTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(
      children: [
        for (final item in ['Yêu thích', 'Gần đây', 'Playlist'])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AppChip(
                showCheckmark: false,
                label: Center(child: Text(item)),
                selected: section == item,
                onSelected: (_) => navigate(item),
              ),
            ),
          ),
      ],
    ),
  );

  Widget mobileHero() => Container(
    margin: const EdgeInsets.only(bottom: 22),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF073A9C), Color(0xFF356DF0)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.sparkles, color: Color(0xFFC0D4FF), size: 15),
            SizedBox(width: 7),
            Text(
              'YOUR DAILY SOUNDTRACK',
              style: TextStyle(
                color: Color(0xFFC0D4FF),
                fontSize: 10,
                letterSpacing: 1.7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: Text(
                'Một ngày mới.\nMột giai điệu mới.',
                style: TextStyle(
                  fontSize: 29,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -.8,
                ),
              ),
            ),
            Icon(LucideIcons.disc3, color: Colors.white38, size: 62),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Tìm chút cảm hứng trong từng bài hát.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 20),
        TDButton(
          text: 'Nghe nhạc dành cho bạn',
          style: TDButtonStyle(
            backgroundColor: const Color(0xFF194896),
            textColor: Colors.white,
            frameColor: Colors.transparent,
            frameWidth: 0,
          ),
          icon: LucideIcons.play,
          theme: TDButtonTheme.defaultTheme,
          size: TDButtonSize.medium,
          onTap: () => navigate('Dành cho bạn'),
        ),
      ],
    ),
  );

  Widget featuredSongs() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Chạm để nghe',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ),
          Icon(LucideIcons.headphones, size: 20, color: accentColor),
        ],
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 203,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: songs.take(8).length,
          separatorBuilder: (_, i) => const SizedBox(width: 14),
          itemBuilder: (_, i) => Semantics(
            button: true,
            label: 'Nghe ${songs[i]['title']}',
            child: GestureDetector(
              onTap: () => openSong(songs, i),
              child: SizedBox(
                width: 146,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        cover(songs[i], 146),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: ListenableBuilder(
                            listenable: player,
                            builder: (_, child) {
                              final isCurrent =
                                  player.current?['id'] == songs[i]['id'];
                              final playing = isCurrent && player.audio.playing;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => guard(() async {
                                  if (isCurrent) {
                                    await player.toggle();
                                  } else {
                                    await player.play(List.of(songs), i);
                                  }
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    playing
                                        ? LucideIcons.pause
                                        : LucideIcons.play,
                                    size: 16,
                                    color: blue,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      songs[i]['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      songs[i]['artist'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: mutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );
}
