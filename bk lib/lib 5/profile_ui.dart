part of 'main.dart';

// Trang "Cá nhân": thẻ hồ sơ có avatar, thống kê và các nút thao tác.
extension _ProfileUI on _MusicHomeState {
  // Backend có thể trả avatar ở nhiều khoá khác nhau (NextAuth dùng 'image').
  String get avatarUrl {
    for (final key in const ['avatarUrl', 'avatar', 'image', 'imageUrl']) {
      final value = user?[key]?.toString() ?? '';
      if (value.isNotEmpty) return api.media(value);
    }
    return '';
  }

  Future<void> changeAvatar() => guard(() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null) return;
    if (file!.size > 5 * 1024 * 1024) {
      message('Ảnh đại diện tối đa 5 MB');
      return;
    }
    await api.request(
      '/api/profile',
      method: 'PATCH',
      data: FormData.fromMap({
        'name': user!['name'] ?? '',
        'avatar': MultipartFile.fromBytes(file.bytes!, filename: file.name),
      }),
    );
    final me = await api.me();
    updateUI(() => user = me);
    message('Đã cập nhật ảnh đại diện');
  });

  Future<void> renameUser() => guard(() async {
    final name = await askName('Tên hiển thị', initial: user!['name'] ?? '');
    if (name == null) return;
    await api.request(
      '/api/profile',
      method: 'PATCH',
      data: FormData.fromMap({'name': name}),
    );
    final me = await api.me();
    updateUI(() => user = me);
  });

  Future<void> signOut() => guard(() async {
    await api.logout();
    snapshots.clear();
    updateUI(() {
      user = null;
      favorites.clear();
    });
    navigate('Khám phá');
  });

  Widget avatarView(double size) {
    final brand = TDTheme.of(context).brandNormalColor;
    final fallback = Container(
      color: brand.withValues(alpha: .15),
      alignment: Alignment.center,
      child: Icon(LucideIcons.userRound, size: size * .45, color: brand),
    );
    final url = avatarUrl;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => fallback,
              ),
      ),
    );
  }

  Widget profileStat(IconData icon, String value, String label) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 18, color: TDTheme.of(context).brandNormalColor),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: mutedColor)),
      ],
    ),
  );

  Widget profileRow(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
    bool last = false,
  }) {
    final color = danger
        ? dangerColor
        : Theme.of(context).colorScheme.onSurface;
    return AppTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: danger ? color : mutedColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (!danger)
              Icon(LucideIcons.chevronRight, size: 18, color: mutedColor),
          ],
        ),
      ),
    );
  }

  Widget profile() {
    if (user == null) return const SizedBox.shrink();
    final brand = TDTheme.of(context).brandNormalColor;
    final surface = Theme.of(context).colorScheme.surface;
    final plays = songs.fold<int>(
      0,
      (sum, s) => sum + ((s['playCount'] as num?)?.toInt() ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thẻ hồ sơ: dải màu thương hiệu phía trên + avatar đè lên mép.
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [brand, brand.withValues(alpha: .45)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -44,
                    child: GestureDetector(
                      onTap: changeAvatar,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: surface,
                              shape: BoxShape.circle,
                            ),
                            child: avatarView(88),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: brand,
                                shape: BoxShape.circle,
                                border: Border.all(color: surface, width: 2),
                              ),
                              child: const Icon(
                                LucideIcons.camera,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 54),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      user!['name']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user!['email']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: mutedColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    profileStat(LucideIcons.music2, '${songs.length}', 'Bài đã đăng'),
                    profileStat(LucideIcons.heart, '${favorites.length}', 'Yêu thích'),
                    profileStat(LucideIcons.headphones, '$plays', 'Lượt nghe'),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: TDButton(
            text: 'Tải nhạc lên',
            icon: LucideIcons.upload,
            isBlock: true,
            theme: TDButtonTheme.primary,
            shape: TDButtonShape.rectangle,
            onTap: upload,
          ),
        ),
        const SizedBox(height: 12),
        AppPanel(
          child: Column(
            children: [
              profileRow(LucideIcons.imagePlus, 'Đổi ảnh đại diện', changeAvatar),
              profileRow(LucideIcons.pencil, 'Sửa tên hiển thị', renameUser),
              profileRow(
                LucideIcons.logOut,
                'Đăng xuất',
                signOut,
                danger: true,
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(LucideIcons.listMusic, size: 20, color: mutedColor),
            const SizedBox(width: 8),
            const Text(
              'Bài hát của tôi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
