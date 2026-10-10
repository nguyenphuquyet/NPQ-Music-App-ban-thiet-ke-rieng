import 'package:flutter/cupertino.dart';

/// Keeps the previous page mounted so Cupertino owns push, pop and edge drags.
class CupertinoNavigation extends StatefulWidget {
  const CupertinoNavigation({
    super.key,
    required this.routeKey,
    required this.onBack,
    required this.child,
  });

  final LocalKey routeKey;
  final VoidCallback onBack;
  final Widget child;

  @override
  State<CupertinoNavigation> createState() => _CupertinoNavigationState();
}

class _CupertinoNavigationState extends State<CupertinoNavigation> {
  final _pages = <CupertinoPage<void>>[];

  @override
  void initState() {
    super.initState();
    _syncPage();
  }

  @override
  void didUpdateWidget(CupertinoNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPage();
  }

  void _syncPage() {
    final index = _pages.indexWhere((page) => page.key == widget.routeKey);
    if (index >= 0) {
      _pages.removeRange(index, _pages.length);
    }
    _pages.add(CupertinoPage<void>(key: widget.routeKey, child: widget.child));
  }

  @override
  Widget build(BuildContext context) => Navigator(
    pages: List.of(_pages),
    onDidRemovePage: (page) {
      // Declarative back already updated the app state. Only a native pop
      // (including a completed edge swipe) needs to notify the owner.
      if (_pages.length > 1 && identical(_pages.last, page)) {
        setState(() => _pages.removeLast());
        widget.onBack();
      }
    },
  );
}
