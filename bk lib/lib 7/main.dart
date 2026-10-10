import 'dart:async';
import 'dart:ui' show ImageFilter, FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/cupertino.dart'
    show CupertinoPageRoute, DefaultCupertinoLocalizations;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'api.dart';
import 'player.dart';
part 'mobile_ui.dart';
part 'design.dart';
part 'song_detail.dart';
part 'player_ui.dart';
part 'app_theme.dart';
part 'for_you_feed.dart';
part 'profile_ui.dart';

void main() {
  // Bắt buộc để TDTheme.of(context) đọc theme sáng/tối từ ThemeData.extensions.
  TDTheme.needMultiTheme();
  runApp(const MusicApp());
}

const blue = Color(0xFF0052D9);
// Màu động theo theme sáng/tối (được cập nhật trong MusicApp.build).
Color accentColor = blue;
Color mutedColor = const Color(0xFF69768C);
Color dangerColor = const Color(0xFFD54941);

class MusicApp extends StatefulWidget {
  const MusicApp({super.key});
  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) {
    accentColor = dark ? const Color(0xFF83ADFF) : blue;
    mutedColor = dark ? const Color(0xFFA5B3C7) : const Color(0xFF69768C);
    dangerColor = dark ? const Color(0xFFFF8A80) : const Color(0xFFD54941);
    return _buildApp();
  }

  Widget _buildApp() => WidgetsApp(
    color: accentColor,
    title: 'NPQ Music',
    debugShowCheckedModeBanner: false,
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultCupertinoLocalizations.delegate,
    ],
    textStyle: TextStyle(
      fontSize: 14,
      color: dark ? const Color(0xFFF1F3F9) : const Color(0xFF17243D),
    ),
    builder: (context, child) => Theme(
      data: musicTheme(dark),
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
            color: dark ? const Color(0xFFEEF3FA) : const Color(0xFF17243D),
          ),
          child: child!,
        ),
      ),
    ),
    pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondary) => builder(context),
    ),
    home: MusicHome(
      onTheme: () => setState(() => dark = !dark),
    ),
  );
}

class MusicHome extends StatefulWidget {
  final VoidCallback onTheme;
  const MusicHome({super.key, required this.onTheme});
  @override
  State<MusicHome> createState() => _MusicHomeState();
}

class _MusicHomeState extends State<MusicHome> {
  void updateUI(VoidCallback action) => setState(action);
  final api = Api();
  late final MusicPlayer player;
  // Chiều cao thanh kính mờ trên/dưới (giao diện điện thoại) để chừa khoảng đệm.
  double glassTop = 0, glassBottom = 0;
  // Feed dọc của trang Khám phá.
  PageController feedController = PageController();
  // Ghi nhớ feed khi rời tab Khám phá để quay lại đúng bài cũ.
  List<Json>? feedCache;
  int feedCacheIndex = 0;
  bool feedCacheMore = false;
  int feedIndex = 0;
  bool feedTouched = false;
  String? feedLastId;
  final search = TextEditingController();
  final favorites = <String>{};
  List<Json> songs = [], genres = [], playlists = [];
  Json? user, playlist, songDetail;
  List<Json> detailQueue = [];
  String detailBackSection = 'Khám phá';
  Json? detailBackPlaylist;
  String section = 'Khám phá', genre = '', query = '';
  bool reversePage = false;
  // Bộ nhớ đệm theo tab: quay lại tab/trang cũ hiện ngay, dữ liệu mới được
  // tải ngầm rồi cập nhật sau (không hiện loading, không nhảy nội dung).
  final snapshots = <String, Map<String, dynamic>>{};
  static const cacheable = [
    'Khám phá',
    'Yêu thích',
    'Gần đây',
    'Playlist',
    'Cá nhân',
  ];
  String? error;
  bool loading = true, more = false, loadingMore = false, refreshing = false;
  int page = 1, requestId = 0;
  Timer? debounce;
  static const destinations = [
    'Khám phá',
    'Dành cho bạn',
    'Yêu thích',
    'Gần đây',
    'Playlist',
    'Cá nhân',
  ];
  static const icons = [
    LucideIcons.compass,
    LucideIcons.sparkles,
    LucideIcons.heart,
    LucideIcons.history,
    LucideIcons.listMusic,
    LucideIcons.userRound,
  ];
  @override
  void initState() {
    super.initState();
    player = MusicPlayer(api);
    player.addListener(syncFeedWithPlayer);
    initialize();
  }

  Future<void> initialize() async {
    await load();
    try {
      final result = await Future.wait<dynamic>([
        api.me(),
        api.list('/api/genres'),
      ]);
      if (!mounted) return;
      setState(() {
        user = result[0] as Json?;
        genres = result[1] as List<Json>;
      });
      if (user != null) await refreshFavorites();
    } catch (e) {
      message(e);
    }
  }

  Future<void> refreshFavorites() async {
    final result = await api.list('/api/favorites');
    if (mounted) {
      setState(() {
        favorites
          ..clear()
          ..addAll(result.map((e) => e['id'] as String));
      });
    }
  }

  void message(Object text) {
    if (!mounted) return;
    TDToast.showText(
      text.toString().replaceFirst('Exception: ', ''),
      context: context,
    );
  }

  Future<void> guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      message(e);
    }
  }

  Future<void> load({
    bool append = false,
    bool soft = false,
    bool silent = false,
  }) async {
    final ticket = ++requestId;
    final nextPage = append ? page + 1 : 1;
    setState(() {
      if (silent) {
        // Tải ngầm: giữ nguyên giao diện hiện tại.
      } else if (append) {
        loadingMore = true;
      } else if (soft) {
        // Lọc/đổi thể loại: giữ nguyên nội dung cũ, chỉ làm mờ + thanh tiến trình.
        refreshing = true;
      } else {
        loading = true;
      }
      error = null;
    });
    try {
      if (section == 'Chi tiết bài hát' && songDetail != null) {
        final detail = await api.request(
          Uri(
            pathSegments: ['api', 'songs', songDetail!['id'] as String],
          ).toString().replaceFirst('api/', '/api/'),
        );
        if (mounted && ticket == requestId) {
          setState(() {
            songDetail = Map<String, dynamic>.from(detail);
            loading = false;
            loadingMore = false;
            refreshing = false;
          });
        }
        return;
      }
      List<Json> result = [];
      if (playlist != null) {
        final detail = await api.request('/api/playlists/${playlist!['id']}');
        if (ticket != requestId) return;
        playlist = Map<String, dynamic>.from(detail);
        result = (detail['songs'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (section == 'Playlist') {
        final result = await api.list('/api/playlists');
        if (ticket != requestId) return;
        playlists = result;
      } else if (section == 'Cá nhân') {
        if (user != null) {
          final profile = await api.request('/api/users/${user!['id']}');
          result = (profile['songs'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } else if (section == 'Dành cho bạn') {
        final data = await api.request(
          '/api/for-you',
          method: 'POST',
          data: {
            'excludeIds': append
                ? songs.skip(songs.length > 60 ? songs.length - 60 : 0).map((e) => e['id']).toList()
                : [],
          },
        );
        result = (data['songs'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (section == 'Yêu thích' || section == 'Gần đây') {
        result = await api.list(
          section == 'Yêu thích' ? '/api/favorites' : '/api/history',
        );
      } else if (section == 'Tìm kiếm' && query.isEmpty && genre.isEmpty) {
        result = [];
      } else {
        result = await api.list(
          '/api/songs?${Uri(queryParameters: {'take': '30', 'page': '$nextPage', if (query.isNotEmpty) 'q': query, if (genre.isNotEmpty) 'genre': genre}).query}',
        );
      }
      if (!mounted || ticket != requestId) return;
      setState(() {
        if (append) {
          final ids = songs.map((e) => e['id']).toSet();
          songs = [...songs, ...result.where((e) => !ids.contains(e['id']))];
        } else {
          songs = result;
        }
        page = nextPage;
        more =
            playlist == null &&
            (['Khám phá', 'Tìm kiếm'].contains(section) &&
                    result.length == 30 ||
                section == 'Dành cho bạn' && result.isNotEmpty);
        loading = false;
        loadingMore = false;
            refreshing = false;
      });
    } catch (e) {
      if (silent) {
        if (mounted && ticket == requestId) {
          setState(() {
            loading = false;
            loadingMore = false;
            refreshing = false;
          });
        }
      } else if (mounted && ticket == requestId) {
        setState(() {
          error = e.toString();
          loading = false;
          loadingMore = false;
            refreshing = false;
        });
      }
    }
  }

  void navigate(String value) {
    // Lưu trạng thái tab hiện tại trước khi rời đi.
    if (cacheable.contains(section) && !loading) {
      snapshots[section] = {
        'songs': playlist == null ? List<Json>.of(songs) : <Json>[],
        'playlists': List<Json>.of(playlists),
        'page': playlist == null ? page : 1,
        'more': playlist == null && more,
      };
    }
    final snap = cacheable.contains(value) ? snapshots[value] : null;
    reversePage =
        (['Tìm kiếm', 'Chi tiết bài hát'].contains(section) &&
            !['Tìm kiếm', 'Chi tiết bài hát'].contains(value)) ||
        // Quay lại từ chi tiết playlist về thư viện playlist.
        (playlist != null && value == 'Playlist');
    debounce?.cancel();
    const feedSection = 'Dành cho bạn';
    // Rời feed: lưu danh sách + vị trí hiện tại.
    if (section == feedSection && value != feedSection && songs.isNotEmpty) {
      feedCache = List<Json>.from(songs);
      feedCacheIndex = feedIndex;
      feedCacheMore = more;
    }
    // Vào lại feed từ tab khác: khôi phục đúng vị trí, không nạp lại.
    final restore =
        value == feedSection && section != feedSection && feedCache != null;
    if (value == feedSection) {
      final old = feedController;
      feedController = PageController(
        initialPage: restore ? feedCacheIndex : 0,
      );
      Future.delayed(const Duration(seconds: 1), old.dispose);
    }
    setState(() {
      section = value;
      playlist = null;
      query = '';
      genre = '';
      search.clear();
      feedTouched = false;
      // Không tự nhảy theo bài đang phát ở mini player khi vừa vào lại.
      feedLastId = player.current?['id']?.toString();
      if (restore) {
        songs = List<Json>.from(feedCache!);
        feedIndex = feedCacheIndex;
        more = feedCacheMore;
        loading = false;
        loadingMore = false;
        refreshing = false;
        error = null;
      } else {
        feedIndex = 0;
        if (value == feedSection) feedCache = null;
        if (snap != null) {
          songs = List<Json>.of(snap['songs'] as List<Json>);
          playlists = List<Json>.of(snap['playlists'] as List<Json>);
          page = snap['page'] as int;
          more = snap['more'] as bool;
          loading = false;
          loadingMore = false;
          refreshing = false;
          error = null;
        }
      }
    });
    if (restore) {
      requestId++; // huỷ mọi request đang chạy dở của tab trước
      return;
    }
    // Có bộ nhớ đệm: hiện ngay, cập nhật ngầm phía sau.
    if (snap != null) {
      load(silent: true);
      return;
    }
    load();
  }

  Future<void> requireUser(Future<void> Function() action) async {
    if (user == null) await auth();
    if (user != null) await guard(action);
  }

  Future<void> favorite(Json song) => requireUser(() async {
    final result = await api.request(
      '/api/favorites',
      method: 'POST',
      data: {'songId': song['id']},
    );
    if (!mounted) return;
    setState(() {
      final n = (song['favoritesCount'] as num?)?.toInt() ?? 0;
      if (result['favorited'] == true) {
        favorites.add(song['id']);
        song['favoritesCount'] = n + 1;
      } else {
        favorites.remove(song['id']);
        song['favoritesCount'] = n > 0 ? n - 1 : 0;
      }
    });
    if (section == 'Yêu thích') await load();
  });
  Widget button(String text, VoidCallback onTap, {bool primary = false}) =>
      TDButton(
        text: text,
        onTap: onTap,
        theme: primary ? TDButtonTheme.primary : TDButtonTheme.defaultTheme,
        type: TDButtonType.fill,
        shape: TDButtonShape.rectangle,
        size: TDButtonSize.medium,
      );
  Widget field(
    TextEditingController controller,
    String hint, {
    bool secret = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? const Color(0xFF222F40) : const Color(0xFFEEF1F6);
    final line = dark ? const Color(0xFF3A4A5F) : const Color(0xFFCBD3DF);
    return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: TDInput(
      showBottomDivider: false,
      textStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
        decoration: TextDecoration.none,
      ),
      hintTextStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 14,
      ),
      controller: controller,
      hintText: hint,
      obscureText: secret,
      backgroundColor: fill,
    ),
    ),
  );
  }
  Future<void> auth() async {
    final email = TextEditingController(),
        password = TextEditingController(),
        name = TextEditingController();
    bool register = false, busy = false;
    String? failure;
    await appDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, update) => AppDialog(
          title: Text(register ? 'Tạo tài khoản NPQ' : 'Chào mừng trở lại'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (register) field(name, 'Tên của bạn'),
                field(email, 'Email'),
                field(password, 'Mật khẩu', secret: true),
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      failure!,
                      style: TextStyle(color: dangerColor, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: button(
                  busy
                      ? 'Đang xử lý…'
                      : register
                      ? 'Đăng ký'
                      : 'Đăng nhập',
                  () async {
                    if (busy) return;
                    if (!email.text.contains('@') ||
                        password.text.length < 6 ||
                        register && name.text.trim().isEmpty) {
                      update(
                        () => failure =
                            'Nhập email, mật khẩu ít nhất 6 ký tự và tên nếu đăng ký.',
                      );
                      return;
                    }
                    update(() {
                      busy = true;
                      failure = null;
                    });
                    try {
                      if (register) {
                        await api.request(
                          '/api/auth/register',
                          method: 'POST',
                          data: {
                            'name': name.text.trim(),
                            'email': email.text.trim(),
                            'password': password.text,
                          },
                        );
                      }
                      await api.login(email.text.trim(), password.text);
                      final me = await api.me();
                      if (!mounted) return;
                      snapshots.clear(); // đổi tài khoản: bỏ cache cũ
                      setState(() => user = me);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        update(() {
                          failure = e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                          busy = false;
                        });
                      }
                    }
                  },
                  primary: true,
                  ),
                ),
                const SizedBox(height: 14),
                AppTextButton(
                  onPressed: busy
                      ? null
                      : () => update(() {
                          register = !register;
                          failure = null;
                        }),
                  child: Text(
                    register
                        ? 'Đã có tài khoản? Đăng nhập'
                        : 'Chưa có tài khoản? Đăng ký',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Controllers stay alive through the dialog closing animation.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      email.dispose();
      password.dispose();
      name.dispose();
    });
    if (user != null) {
      await guard(() async {
        await refreshFavorites();
        await load();
      });
    }
  }

  Future<String?> askName(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await appDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: Text(title),
        content: field(controller, 'Nhập tên'),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          button('Lưu', () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(ctx, controller.text.trim());
            }
          }, primary: true),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose);
    return result;
  }

  Future<bool> confirm(String title) async =>
      await appDialog<bool>(
        context: context,
        builder: (ctx) => AppDialog(
          title: Text(title),
          content: const Text('Thao tác này không thể hoàn tác.'),
          actions: [
            AppTextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            AppTextButton(
              danger: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> createPlaylist() => requireUser(() async {
    final name = await askName('Tạo playlist');
    if (name == null) return;
    await api.request('/api/playlists', method: 'POST', data: {'name': name});
    navigate('Playlist');
  });
  Future<void> addToPlaylist(Json song) => requireUser(() async {
    final items = (await api.list(
      '/api/playlists',
    )).where((e) => e['isOwner'] == true).toList();
    if (!mounted) return;
    final id = await appDialog<String>(
      context: context,
      builder: (ctx) => AppOptionsDialog(
        title: const Text('Thêm vào playlist'),
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Tạo playlist trong thư viện trước.'),
            ),
          ...items.map(
            (p) => AppDialogOption(
              icon: LucideIcons.listMusic,
              onPressed: () => Navigator.pop(ctx, p['id']),
              child: Text(p['name']),
            ),
          ),
        ],
      ),
    );
    if (id != null) {
      await api.request(
        '/api/playlists/$id/songs',
        method: 'POST',
        data: {'songId': song['id']},
      );
      message('Đã thêm vào playlist');
    }
  });
  Widget cover(Json song, double size, {double radius = 12}) {
    final url = api.media(song['coverUrl']);
    final fallback = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(LucideIcons.music2, color: accentColor, size: size * .45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => fallback,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => mobileScaffold();

  Widget pageBody(bool wide) {
    final routeKey = ValueKey(
      section == 'Chi tiết bài hát'
          ? 'song:${songDetail?['id']}'
          : playlist != null
          ? 'playlist:${playlist!['id']}'
          : section == 'Tìm kiếm'
          ? 'search'
          : 'tabs',
    );
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        reverseDuration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          final incoming = child.key == routeKey;
          final begin = incoming
              ? (reversePage ? const Offset(-.25, 0) : const Offset(1, 0))
              : (reversePage ? const Offset(1, 0) : const Offset(-.25, 0));
          return SlideTransition(
            position: Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        child: KeyedSubtree(
          key: routeKey,
          // Nền đặc để trang cũ/mới không nhìn xuyên qua nhau khi đang trượt.
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                if (section == 'Tìm kiếm')
                  Padding(
                    padding: EdgeInsets.only(top: glassTop),
                    child: searchPanel(),
                  ),
                Expanded(child: content(wide)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget content(bool wide) {
    if (loading) {
      return const Center(child: TDLoading(size: TDLoadingSize.medium));
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.wifiOff, size: 44),
              const SizedBox(height: 16),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              button('Thử lại', load),
            ],
          ),
        ),
      );
    }
    if (section == 'Chi tiết bài hát' && songDetail != null) {
      return songDetailPage(wide);
    }
    if (section == 'Dành cho bạn') return forYouFeed(wide);
    return SizedBox(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          wide ? 32 : 16,
          12 + (section == 'Tìm kiếm' ? 0 : glassTop),
          wide ? 32 : 16,
          28 + glassBottom,
        ),
        children: [
          if (section == 'Khám phá') ...[
            // Thanh thể loại cố định ở đầu trang: đổi thể loại chỉ lọc danh sách
            // bên dưới, không chuyển/nhảy trang.
            genreBar(),
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (query.isEmpty && genre.isEmpty) mobileHero(),
                  if (query.isEmpty && genre.isEmpty && songs.isNotEmpty)
                    featuredSongs(),
                ],
              ),
            ),
          ],
          if (playlist != null)
            Align(
              alignment: Alignment.centerLeft,
              child: AppBackButton(
                tooltip: 'Thư viện playlist',
                onPressed: () => navigate('Playlist'),
              ),
            ),
          if (!(section == 'Cá nhân' && user != null)) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  playlist?['name'] ??
                      (query.isNotEmpty
                          ? 'Kết quả cho “$query”'
                          : genre.isNotEmpty
                          ? genre
                          : section == 'Khám phá'
                          ? 'Mới phát hành'
                          : section),
                  style: TextStyle(
                    fontSize: wide ? 26 : 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (section == 'Playlist' && playlist == null)
                AppIconButton(
                  tooltip: 'Tạo playlist',
                  onPressed: createPlaylist,
                  icon: const Icon(LucideIcons.circlePlus),
                ),
              AppIconButton(
                tooltip: 'Làm mới',
                onPressed: load,
                icon: const Icon(LucideIcons.refreshCw),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            playlist != null
                ? '${songs.length} bài hát • ${playlist!['isPublic'] == true ? 'Công khai' : 'Riêng tư'}'
                : section == 'Khám phá' && genre.isNotEmpty
                ? '${songs.length} bài hát thể loại $genre'
                : section == 'Khám phá'
                ? 'Những giai điệu mới cho ngày của bạn'
                : section == 'Tìm kiếm'
                ? 'Tìm giai điệu bạn đang muốn nghe'
                : 'Bộ sưu tập âm nhạc của bạn',
            style: TextStyle(color: mutedColor),
          ),
          const SizedBox(height: 20),
          ],
          if (section == 'Cá nhân') profile(),
          if (playlist != null) playlistActions(),
          if (user == null &&
              ['Yêu thích', 'Gần đây', 'Playlist', 'Cá nhân'].contains(section))
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('Đăng nhập để đồng bộ thư viện của bạn.'),
                  const SizedBox(height: 16),
                  button('Đăng nhập / Đăng ký', auth, primary: true),
                ],
              ),
            )
          else if (section == 'Playlist' && playlist == null) ...[
            if (playlists.isEmpty)
              empty('Chưa có playlist. Tạo bộ sưu tập đầu tiên của bạn.'),
            ...playlists.map(
              (p) => AppPanel(
                child: musicTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: cover(p, 56),
                  title: Text(p['name']),
                  subtitle: Text(
                    '${p['songCount']} bài hát • ${p['isPublic'] == true ? 'Công khai' : 'Riêng tư'}',
                  ),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () {
                    openPlaylist(p);
                  },
                ),
              ),
            ),
          ] else ...[
            if (songs.isEmpty)
              empty(
                section == 'Tìm kiếm'
                    ? (query.isEmpty
                          ? 'Nhập tên bài hát hoặc nghệ sĩ để tìm kiếm.'
                          : 'Không tìm thấy bài hát phù hợp.')
                    : 'Chưa có bài hát nào ở đây.',
              ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: refreshing ? .4 : 1,
              child: IgnorePointer(
                ignoring: refreshing,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (songs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: button(
                            'Phát tất cả',
                            () => player.play(songs, 0),
                            primary: true,
                          ),
                        ),
                      ),
                    ...List.generate(
                      songs.length,
                      (i) => songTile(songs, i, wide),
                    ),
                  ],
                ),
              ),
            ),
            if (more)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: button(loadingMore ? 'Đang tải…' : 'Xem thêm', () {
                    if (!loadingMore) load(append: true);
                  }),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget genreBar() {
    final names = ['', ...genres.map((g) => g['name'] as String)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ScrollHintRow(
            height: 48,
            itemCount: names.length,
            itemBuilder: (_, i) => AppChip(
              label: Text(i == 0 ? 'Tất cả' : names[i]),
              selected: genre == names[i],
              onSelected: (_) {
                if (genre == names[i]) return;
                setState(() => genre = names[i]);
                load(soft: true);
              },
            ),
          ),
          SizedBox(
            height: 2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: refreshing ? 1 : 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: accentColor,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 44),
    child: Column(
      children: [
        Icon(LucideIcons.library, color: mutedColor, size: 48),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
  Widget songTile(List<Json> list, int i, bool wide, [bool queueMode = false]) {
    final song = list[i];
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final active = player.current?['id'] == song['id'];
        return Container(
          // Trong popup danh sách phát: dòng phẳng, không bo góc, ngăn cách
          // bằng đường kẻ mảnh (không dùng thẻ bo tròn lồng trong thẻ bo tròn).
          margin: EdgeInsets.only(bottom: queueMode ? 0 : 6),
          decoration: queueMode
              ? BoxDecoration(
                  color: active ? accentColor.withValues(alpha: .1) : null,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: .6),
                    ),
                  ),
                )
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: active
                      ? accentColor.withValues(alpha: .08)
                      : Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: .65),
                ),
          child: musicTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: wide ? 16 : 8,
              vertical: 5,
            ),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (wide)
                  SizedBox(
                    width: 34,
                    child: Text(
                      active ? '♫' : '${i + 1}'.padLeft(2, '0'),
                      style: TextStyle(color: active ? accentColor : mutedColor),
                    ),
                  ),
                cover(song, 48),
              ],
            ),
            title: Text(
              song['title'] ?? '',
              // Danh sách phát: cho tên bài xuống tối đa 2 dòng để đọc đủ.
              maxLines: queueMode ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            subtitle: Text(
              song['artist'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: mutedColor),
            ),
            onTap: () => queueMode ? player.play(list, i) : openSong(list, i),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (wide)
                  SizedBox(
                    width: 60,
                    child: Text(
                      time(
                        Duration(
                          seconds: (song['duration'] as num?)?.toInt() ?? 0,
                        ),
                      ),
                      style: TextStyle(fontSize: 12, color: mutedColor),
                    ),
                  ),
                AppIconButton(
                  tooltip: active && player.audio.playing
                      ? 'Tạm dừng'
                      : 'Phát',
                  onPressed: () => guard(() async {
                    if (active) {
                      await player.toggle();
                    } else {
                      await player.play(list, i);
                    }
                  }),
                  icon: Icon(
                    active && player.audio.playing
                        ? LucideIcons.pause
                        : LucideIcons.play,
                    size: 20,
                    color: active ? accentColor : mutedColor,
                  ),
                ),
                AppMenuButton<String>(
                  tooltip: 'Thao tác bài hát',
                  onSelected: (value) {
                    if (value == 'detail') openSong(list, i);
                    if (value == 'play') player.play(list, i);
                    if (value == 'favorite') favorite(song);
                    if (value == 'add') addToPlaylist(song);
                    if (value == 'remove') {
                      guard(() async {
                        await api.request(
                          '/api/playlists/${playlist!['id']}/songs',
                          method: 'DELETE',
                          data: {'songId': song['id']},
                        );
                        await load();
                      });
                    }
                    if (value == 'delete') {
                      guard(() async {
                        if (await confirm('Xóa bài hát này?')) {
                          await api.request(
                            '/api/songs/${song['id']}',
                            method: 'DELETE',
                          );
                          await load();
                        }
                      });
                    }
                  },
                  itemBuilder: (_) => [
                    const AppMenuItem(
                      value: 'detail',
                      icon: LucideIcons.info,
                      child: Text('Chi tiết bài hát'),
                    ),
                    const AppMenuItem(
                      value: 'play',
                      icon: LucideIcons.play,
                      child: Text('Phát ngay'),
                    ),
                    AppMenuItem(
                      value: 'favorite',
                      icon: LucideIcons.heart,
                      child: Text(
                        favorites.contains(song['id'])
                            ? 'Bỏ yêu thích'
                            : 'Yêu thích',
                      ),
                    ),
                    const AppMenuItem(
                      value: 'add',
                      icon: LucideIcons.listPlus,
                      child: Text('Thêm vào playlist'),
                    ),
                    if (playlist?['isOwner'] == true)
                      const AppMenuItem(
                        value: 'remove',
                        icon: LucideIcons.listMinus,
                        child: Text('Gỡ khỏi playlist'),
                      ),
                    if (section == 'Cá nhân' &&
                        song['uploaderId'] == user?['id'])
                      const AppMenuItem(
                        value: 'delete',
                        icon: LucideIcons.trash2,
                        danger: true,
                        child: Text('Xóa bài hát'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget playlistActions() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (playlist!['isOwner'] == true) ...[
          button(
            'Đổi tên',
            () => guard(() async {
              final name = await askName(
                'Đổi tên playlist',
                initial: playlist!['name'],
              );
              if (name != null) {
                await api.request(
                  '/api/playlists/${playlist!['id']}',
                  method: 'PATCH',
                  data: {'name': name},
                );
                await load();
              }
            }),
          ),
          button(
            playlist!['isPublic'] == true
                ? 'Chuyển riêng tư'
                : 'Chuyển công khai',
            () => guard(() async {
              await api.request(
                '/api/playlists/${playlist!['id']}',
                method: 'PATCH',
                data: {'isPublic': playlist!['isPublic'] != true},
              );
              await load();
            }),
          ),
          button(
            'Xóa playlist',
            () => guard(() async {
              if (await confirm('Xóa playlist này?')) {
                await api.request(
                  '/api/playlists/${playlist!['id']}',
                  method: 'DELETE',
                );
                navigate('Playlist');
              }
            }),
          ),
        ],
      ],
    ),
  );
  String time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  void queueSheet() => appSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      // Không cao quá phần màn hình nhìn thấy được (trừ thanh trạng thái,
      // thanh điều hướng, tay nắm và lề dưới của thẻ) để thẻ luôn hiện đủ
      // đáy bo tròn và cuộn được tới bài cuối.
      height: () {
        final mq = MediaQuery.of(ctx);
        final usable = mq.size.height - mq.padding.top - mq.padding.bottom;
        return (mq.size.height * .7).clamp(0.0, usable - 56);
      }(),
      child: ListenableBuilder(
        listenable: player,
        builder: (_, child) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Danh sách phát',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AppIconButton(
                    tooltip: 'Ngẫu nhiên',
                    onPressed: player.toggleShuffle,
                    icon: Icon(
                      LucideIcons.shuffle,
                      color: player.shuffle ? accentColor : null,
                    ),
                  ),
                  AppIconButton(
                    tooltip:
                        'Lặp: ${['Tắt', 'Tất cả', 'Một bài'][player.repeat]}',
                    onPressed: player.cycleRepeat,
                    icon: Icon(
                      player.repeat == 2
                          ? LucideIcons.repeat1
                          : LucideIcons.repeat,
                      color: player.repeat > 0 ? accentColor : null,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: player.queue.length,
                itemBuilder: (_, i) => songTile(player.queue, i, false, true),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> upload() => requireUser(() async {
    final title = TextEditingController(), artist = TextEditingController();
    PlatformFile? audio, image;
    String selectedGenre = genres.isEmpty ? '' : genres.first['name'];
    bool busy = false;
    String? failure;
    if (!mounted) return;
    await appDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AppDialog(
          title: const Text('Chia sẻ âm nhạc'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  field(title, 'Tên bài hát'),
                  field(artist, 'Nghệ sĩ'),
                  if (genres.isNotEmpty)
                    AppSelect<String>(
                      initialValue: selectedGenre,
                      isExpanded: true,
                      items: genres
                          .map(
                            (g) => AppSelectItem<String>(
                              value: g['name'],
                              child: Text(g['name']),
                            ),
                          )
                          .toList(),
                      onChanged: busy ? null : (v) => selectedGenre = v!,
                    ),
                  const SizedBox(height: 16),
                  button(audio?.name ?? 'Chọn audio (tối đa 100 MB)', () async {
                    if (busy) return;
                    try {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg', 'flac'],
                        withData: true,
                      );
                      if (ctx.mounted && result != null) {
                        update(() => audio = result.files.single);
                      }
                    } catch (e) {
                      if (ctx.mounted) update(() => failure = '$e');
                    }
                  }),
                  const SizedBox(height: 12),
                  button(
                    image?.name ?? 'Chọn ảnh bìa (tối đa 10 MB)',
                    () async {
                      if (busy) return;
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                          withData: true,
                        );
                        if (ctx.mounted && result != null) {
                          update(() => image = result.files.single);
                        }
                      } catch (e) {
                        if (ctx.mounted) update(() => failure = '$e');
                      }
                    },
                  ),
                  if (failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        failure!,
                        style: TextStyle(color: dangerColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            AppTextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            button(busy ? 'Đang tải lên…' : 'Đăng bài hát', () async {
              if (busy) return;
              if (title.text.trim().isEmpty ||
                  artist.text.trim().isEmpty ||
                  audio?.bytes == null) {
                update(
                  () =>
                      failure = 'Nhập tên bài hát, nghệ sĩ và chọn file audio.',
                );
                return;
              }
              if (audio!.size > 100 * 1024 * 1024 ||
                  (image?.size ?? 0) > 10 * 1024 * 1024) {
                update(() => failure = 'File vượt quá dung lượng cho phép.');
                return;
              }
              update(() {
                busy = true;
                failure = null;
              });
              try {
                await api.request(
                  '/api/songs',
                  method: 'POST',
                  data: FormData.fromMap({
                    'title': title.text.trim(),
                    'artist': artist.text.trim(),
                    'genre': selectedGenre,
                    'audio': MultipartFile.fromBytes(
                      audio!.bytes!,
                      filename: audio!.name,
                    ),
                    if (image?.bytes != null)
                      'cover': MultipartFile.fromBytes(
                        image!.bytes!,
                        filename: image!.name,
                      ),
                  }),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                message('Đã đăng bài hát');
                navigate('Cá nhân');
              } catch (e) {
                if (ctx.mounted) {
                  update(() {
                    busy = false;
                    failure = '$e';
                  });
                }
              }
            }, primary: true),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      title.dispose();
      artist.dispose();
    });
  });
  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    player.removeListener(syncFeedWithPlayer);
    feedController.dispose();
    player.dispose();
    api.dio.close();
    super.dispose();
  }
}

Widget musicTile({
  EdgeInsetsGeometry? contentPadding,
  Widget? leading,
  Widget? title,
  Widget? subtitle,
  Widget? trailing,
  VoidCallback? onTap,
  ShapeBorder? shape,
  bool selected = false,
  Color? selectedTileColor,
  Color? selectedColor,
}) => Semantics(
  button: onTap != null,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: contentPadding ?? const EdgeInsets.all(12),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ?title,
                if (subtitle != null) ...[const SizedBox(height: 5), subtitle],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  ),
);

