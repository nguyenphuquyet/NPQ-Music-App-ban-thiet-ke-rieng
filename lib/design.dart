part of 'main.dart';

// Visual controls use TDesign. Flutter Theme/Material above the navigator only
// supply inherited infrastructure required internally by the TDesign package.
class AppIconButton extends StatelessWidget {
  final String? tooltip;
  final VoidCallback? onPressed;
  final Widget icon;
  final bool filled;
  const AppIconButton({
    super.key,
    this.tooltip,
    this.onPressed,
    required this.icon,
  }) : filled = false;
  const AppIconButton.filled({
    super.key,
    this.tooltip,
    this.onPressed,
    required this.icon,
  }) : filled = true;
  @override
  Widget build(BuildContext context) => Semantics(
    label: tooltip,
    button: true,
    child: TDButton(
      width: filled ? 70 : 44,
      height: filled ? 70 : 44,
      shape: TDButtonShape.circle,
      type: filled ? TDButtonType.fill : TDButtonType.text,
      theme: filled ? TDButtonTheme.primary : TDButtonTheme.defaultTheme,
      disabled: onPressed == null,
      onTap: onPressed,
      child: IconTheme(
        data: IconThemeData(
          color: filled
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
        ),
        child: icon,
      ),
    ),
  );
}

/// Nút quay lại tròn kiểu iOS 26 (Liquid Glass): nền kính mờ, viền mảnh,
/// bóng nhẹ, mũi tên chevron.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  const AppBackButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Quay lại',
    this.size = 40,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: tooltip,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .35 : .12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? Colors.white.withValues(alpha: .14)
                      : const Color(0xFFEEF1F6).withValues(alpha: .92),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withValues(alpha: .18)
                        : Colors.black.withValues(alpha: .10),
                    width: .8,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    LucideIcons.chevronLeft,
                    size: size * .56,
                    color: ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final bool danger;
  const AppTextButton({
    super.key,
    this.onPressed,
    required this.child,
    this.danger = false,
  }) : icon = null;
  const AppTextButton.icon({
    super.key,
    this.onPressed,
    required Widget label,
    required this.icon,
    this.danger = false,
  }) : child = label;
  @override
  Widget build(BuildContext context) {
    final color = danger ? dangerColor : accentColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? .4 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            child: IconTheme(
              data: IconThemeData(color: color, size: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final bool showCheckmark;
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.showCheckmark = false,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final brand = dark ? const Color(0xFF407EEB) : blue;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelected?.call(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? brand
              : (dark ? Colors.white.withValues(alpha: .06) : const Color(0xFFEEF1F6)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? brand : cs.outline),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: brand.withValues(alpha: .28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? Colors.white
                : cs.onSurface.withValues(alpha: .78),
          ),
          child: label,
        ),
      ),
    );
  }
}

class AppPanel extends StatelessWidget {
  final Widget child;
  const AppPanel({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        // Sáng: nền trang cũng trắng nên ô phải xám nhạt mới nhìn thấy;
        // tối: dùng màu surface (sáng hơn nền trang).
        color: dark ? scheme.surface : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class AppTap extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  const AppTap({super.key, required this.child, this.onTap, this.borderRadius});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    ),
  );
}

class AppSlider extends StatelessWidget {
  final double value, max;
  final ValueChanged<double>? onChanged;
  const AppSlider({
    super.key,
    required this.value,
    this.max = 1,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => TDSlider(
    value: value,
    sliderThemeData: TDSliderThemeData(
      context: context,
      min: 0,
      max: max,
      activeTrackColor: accentColor,
    ),
    onChanged: onChanged,
  );
}

class AppProgress extends StatelessWidget {
  final double value, minHeight;
  const AppProgress({super.key, required this.value, this.minHeight = 2});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: minHeight,
    child: LayoutBuilder(
      builder: (_, box) => Stack(
        children: [
          Container(color: Theme.of(context).colorScheme.outline),
          Container(width: box.maxWidth * value, color: accentColor),
        ],
      ),
    ),
  );
}

/// Nền kính mờ trong suốt cho popup: làm mờ nội dung phía sau + phủ màu mờ.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double shadowAlpha, shadowBlur;
  final Offset shadowOffset;

  /// Có chạy hiệu ứng hiện/ẩn theo animation của route popup hay không.
  final bool animateWithRoute;
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.shadowAlpha = .2,
    this.shadowBlur = 36,
    this.shadowOffset = const Offset(0, 14),
    this.animateWithRoute = true,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    final route = animateWithRoute ? ModalRoute.of(context) : null;
    final anim = route?.animation ?? kAlwaysCompleteAnimation;

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        // Mở: nhanh rồi chậm dần. Đóng: tụt nhanh ngay từ đầu (không bị "đuôi" lề mề).
        final v = anim.value.clamp(0.0, 1.0);
        final t = anim.status == AnimationStatus.reverse
            ? Curves.easeIn.transform(v)
            : Curves.easeOutCubic.transform(v);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: shadowAlpha * t),
                blurRadius: shadowBlur,
                offset: shadowOffset,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: shape,
            child: BackdropFilter(
              // Blur tăng dần ngay từ lúc mở (không dùng Opacity bọc ngoài).
              filter: ImageFilter.blur(
                sigmaX: 0.01 + 24 * t,
                sigmaY: 0.01 + 24 * t,
              ),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: (dark ? .7 : .78) * t),
                  borderRadius: shape,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: (dark ? .1 : .7) * t,
                    ),
                  ),
                ),
                // Opacity đặt BÊN TRONG BackdropFilter nên không phá blur.
                child: Opacity(opacity: t, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<T?> appDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Đóng',
  barrierColor: Colors.black.withValues(alpha: .5),
  transitionDuration: const Duration(milliseconds: 180),
  transitionBuilder: (ctx, a, b, child) {
    final c = CurvedAnimation(
      parent: a,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    return ScaleTransition(
      scale: Tween<double>(begin: .92, end: 1).animate(c),
      child: child,
    );
  },
  pageBuilder: (ctx, a, b) => Center(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        MediaQuery.viewInsetsOf(ctx).bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: builder(ctx),
      ),
    ),
  ),
);
Future<T?> appSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  BoxConstraints? constraints,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Đóng',
  barrierColor: Colors.black.withValues(alpha: .45),
  transitionDuration: const Duration(milliseconds: 260),
  transitionBuilder: (ctx, a, b, child) => SlideTransition(
    position: Tween(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
    child: child,
  ),
  pageBuilder: (ctx, a, b) {
    final cs = Theme.of(ctx).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: constraints ?? const BoxConstraints(maxWidth: 480),
        child: SafeArea(
          top: useSafeArea,
          child: Padding(
            // Thẻ nổi: cách mép màn hình, bo đủ 4 góc.
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GlassSurface(
              radius: 28,
              shadowAlpha: .22,
              animateWithRoute: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(child: builder(ctx)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  },
);

class _PopoverLayout extends SingleChildLayoutDelegate {
  final Rect anchor;
  final double width;
  const _PopoverLayout(this.anchor, this.width);
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(
    minWidth: width,
    maxWidth: width,
    maxHeight: c.maxHeight - 24,
  );
  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = (anchor.right - child.width).clamp(
      12.0,
      size.width - child.width - 12,
    );
    var y = anchor.bottom + 6;
    if (y + child.height > size.height - 12) y = anchor.top - 6 - child.height;
    return Offset(x, y.clamp(12.0, size.height - child.height - 12));
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor || old.width != width;
}

/// Popup nổi neo vào nút bấm (kiểu context menu), tự lật lên nếu hết chỗ.
Future<T?> appPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 236,
}) {
  final box = context.findRenderObject() as RenderBox;
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  final opensUp = anchor.center.dy > overlay.size.height * .6;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng',
    barrierColor: Colors.black.withValues(alpha: .12),
    transitionDuration: const Duration(milliseconds: 150),
    transitionBuilder: (ctx, a, b, child) {
      final c = CurvedAnimation(
        parent: a,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      );
      return ScaleTransition(
        alignment: opensUp ? Alignment.bottomRight : Alignment.topRight,
        scale: Tween<double>(begin: .88, end: 1).animate(c),
        child: child,
      );
    },
    pageBuilder: (ctx, a, b) {
      return CustomSingleChildLayout(
        delegate: _PopoverLayout(anchor, width),
        child: GlassSurface(
          radius: 20,
          padding: const EdgeInsets.all(6),
          shadowAlpha: .22,
          shadowBlur: 32,
          shadowOffset: const Offset(0, 12),
          child: SingleChildScrollView(child: builder(ctx)),
        ),
      );
    },
  );
}

class AppDialog extends StatelessWidget {
  final Widget? title, content;
  final List<Widget> actions;
  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassSurface(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      shadowAlpha: .18,
      shadowOffset: const Offset(0, 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                  color: cs.onSurface,
                ),
                child: title!,
              ),
              const SizedBox(height: 16),
            ],
            if (content != null)
              DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: cs.onSurfaceVariant,
                ),
                child: content!,
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppOptionsDialog extends StatelessWidget {
  final Widget title;
  final List<Widget> children;
  const AppOptionsDialog({
    super.key,
    required this.title,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => AppDialog(
    title: title,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class AppDialogOption extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool danger, compact;
  const AppDialogOption({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.danger = false,
    this.compact = false,
  });
  @override
  State<AppDialogOption> createState() => _AppDialogOptionState();
}

class _AppDialogOptionState extends State<AppDialogOption> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = widget.danger ? dangerColor : accentColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => pressed = true),
      onTapUp: (_) => setState(() => pressed = false),
      onTapCancel: () => setState(() => pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: EdgeInsets.only(bottom: widget.compact ? 2 : 4),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 8 : 10,
          vertical: widget.compact ? 7 : 10,
        ),
        decoration: BoxDecoration(
          color: pressed
              ? (dark
                    ? Colors.white.withValues(alpha: .08)
                    : Colors.black.withValues(alpha: .05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Container(
                width: widget.compact ? 32 : 38,
                height: widget.compact ? 32 : 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(widget.compact ? 10 : 11),
                ),
                child: Icon(
                  widget.icon,
                  size: widget.compact ? 17 : 19,
                  color: tint,
                ),
              ),
              SizedBox(width: widget.compact ? 12 : 14),
            ],
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: widget.compact ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  color: widget.danger ? dangerColor : cs.onSurface,
                ),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppMenuItem<T> {
  final T value;
  final Widget child;
  final IconData? icon;
  final bool danger;
  const AppMenuItem({
    required this.value,
    required this.child,
    this.icon,
    this.danger = false,
  });
}

class AppMenuButton<T> extends StatelessWidget {
  final String? tooltip;
  final ValueChanged<T>? onSelected;
  final List<AppMenuItem<T>> Function(BuildContext) itemBuilder;
  final bool bordered; // true: có viền tròn quanh nút
  const AppMenuButton({
    super.key,
    this.tooltip,
    this.onSelected,
    required this.itemBuilder,
    this.bordered = false,
  });
  @override
  Widget build(BuildContext context) {
    final button = _button(context);
    if (!bordered) return button;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1.2,
          ),
        ),
        child: button,
      ),
    );
  }

  Widget _button(BuildContext context) => AppIconButton(
    tooltip: tooltip,
    icon: const Icon(LucideIcons.ellipsis, size: 20),
    onPressed: () async {
      final value = await appDialog<T>(
        context: context,
        builder: (ctx) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: AppDialog(
              title: const Text('Tùy chọn'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: itemBuilder(ctx)
                    .map(
                      (item) => AppDialogOption(
                        icon: item.icon,
                        danger: item.danger,
                        onPressed: () => Navigator.pop(ctx, item.value),
                        child: item.child,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      );
      if (value != null) onSelected?.call(value);
    },
  );
}

class AppSelectItem<T> {
  final T value;
  final Widget child;
  const AppSelectItem({required this.value, required this.child});
}

class AppSelect<T> extends StatefulWidget {
  final T? initialValue;
  final bool isExpanded;
  final List<AppSelectItem<T>> items;
  final ValueChanged<T?>? onChanged;
  const AppSelect({
    super.key,
    this.initialValue,
    this.isExpanded = true,
    required this.items,
    this.onChanged,
  });
  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  late T? value = widget.initialValue;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onChanged == null
          ? null
          : () async {
              final next = await appDialog<T>(
                context: context,
                builder: (ctx) => AppOptionsDialog(
                  title: const Text('Chọn thể loại'),
                  children: widget.items
                      .map(
                        (item) => AppDialogOption(
                          icon: LucideIcons.music2,
                          onPressed: () => Navigator.pop(ctx, item.value),
                          child: item.child,
                        ),
                      )
                      .toList(),
                ),
              );
              if (next != null && mounted) {
                setState(() => value = next);
                widget.onChanged?.call(next);
              }
            },
      child: Opacity(
        opacity: widget.onChanged == null ? .5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: DefaultTextStyle.merge(
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                  child: widget.items
                      .firstWhere(
                        (e) => e.value == value,
                        orElse: () => widget.items.first,
                      )
                      .child,
                ),
              ),
              Icon(
                LucideIcons.chevronDown,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> appSlidePage<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  BoxConstraints? constraints,
}) => Navigator.of(context).push<T>(
  CupertinoPageRoute<T>(
    builder: (ctx) => ColoredBox(
      color: Theme.of(ctx).colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: constraints ?? const BoxConstraints(maxWidth: 480),
          // Không bọc SafeArea: SafeArea cắt cứng nội dung cuộn ở mép status bar
          // / home indicator. Trang con tự cộng MediaQuery.paddingOf(ctx) vào padding.
          child: builder(ctx),
        ),
      ),
    ),
  ),
);

/// Hàng cuộn ngang có gợi ý: nền mờ dần + nút mũi tên ở phía còn vuốt được.
class ScrollHintRow extends StatefulWidget {
  final double height, gap;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  const ScrollHintRow({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.gap = 8,
  });
  @override
  State<ScrollHintRow> createState() => _ScrollHintRowState();
}

class _ScrollHintRowState extends State<ScrollHintRow> {
  final controller = ScrollController();
  bool left = false, right = false;

  void update(ScrollMetrics m) {
    final l = m.pixels > 4;
    final r = m.pixels < m.maxScrollExtent - 4;
    if (l != left || r != right) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            left = l;
            right = r;
          });
        }
      });
    }
  }

  void scrollBy(double delta) {
    final p = controller.position;
    controller.animateTo(
      (p.pixels + delta).clamp(0.0, p.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget edge(BuildContext context, bool isLeft, bool visible) {
    final cs = Theme.of(context).colorScheme;
    final page = Theme.of(context).scaffoldBackgroundColor;
    return Positioned(
      top: 0,
      bottom: 0,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: Container(
            width: 72,
            alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                colors: [page, page.withValues(alpha: 0)],
              ),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => scrollBy(isLeft ? -220 : 220),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  isLeft ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
                  size: 16,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: NotificationListener<Notification>(
      onNotification: (n) {
        if (n is ScrollMetricsNotification) {
          update(n.metrics);
        } else if (n is ScrollNotification) {
          update(n.metrics);
        }
        return false;
      },
      child: Stack(
        children: [
          ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: widget.itemCount,
            separatorBuilder: (_, _) => SizedBox(width: widget.gap),
            itemBuilder: widget.itemBuilder,
          ),
          edge(context, true, left),
          edge(context, false, right),
        ],
      ),
    ),
  );
}

/// Thanh kính mờ: nền bán trong suốt + làm mờ nội dung phía sau.
class GlassBar extends StatelessWidget {
  final Widget child;
  final bool atTop; // true: viền dưới (header), false: viền trên (thanh dưới)
  const GlassBar({super.key, required this.child, this.atTop = false});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = dark
        ? Colors.white.withValues(alpha: .08)
        : Colors.black.withValues(alpha: .06);
    final side = BorderSide(color: line);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: dark ? .66 : .72),
            border: atTop ? null : Border(top: side),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Nội dung nằm dưới thanh trên và thanh dưới (cuộn xuyên qua lớp kính mờ).
/// [body] nhận chiều cao đo được của hai thanh để chừa khoảng đệm.
class GlassScaffold extends StatefulWidget {
  final Widget top, bottom;
  final Widget Function(double top, double bottom) body;
  const GlassScaffold({
    super.key,
    required this.top,
    required this.bottom,
    required this.body,
  });
  @override
  State<GlassScaffold> createState() => _GlassScaffoldState();
}

class _GlassScaffoldState extends State<GlassScaffold> {
  final _topKey = GlobalKey();
  final _bottomKey = GlobalKey();
  double _top = 0, _bottom = 0;

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = (_topKey.currentContext?.size?.height) ?? _top;
      final b = (_bottomKey.currentContext?.size?.height) ?? _bottom;
      if ((t - _top).abs() > .5 || (b - _bottom).abs() > .5) {
        setState(() {
          _top = t;
          _bottom = b;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _measure();
        return false;
      },
      child: Stack(
        children: [
          Positioned.fill(child: widget.body(_top, _bottom)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizeChangedLayoutNotifier(
              child: GlassBar(
                atTop: true,
                child: KeyedSubtree(key: _topKey, child: widget.top),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizeChangedLayoutNotifier(
              child: GlassBar(
                child: KeyedSubtree(key: _bottomKey, child: widget.bottom),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
