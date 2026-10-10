part of 'main.dart';

ThemeData musicTheme(bool dark) {
  final page = dark ? const Color(0xFF101722) : Colors.white;
  final surface = dark ? const Color(0xFF182230) : Colors.white;
  final elevated = dark ? const Color(0xFF222F40) : const Color(0xFFEEF1F6);
  final ink = dark ? const Color(0xFFEEF3FA) : const Color(0xFF17243D);
  final muted = dark ? const Color(0xFFA5B3C7) : const Color(0xFF69768C);
  final border = dark ? const Color(0xFF2B394C) : const Color(0xFFD9DFE8);
  final accent = dark ? const Color(0xFF83ADFF) : blue;
  final source = dark
      ? TDThemeData.defaultData().dark!
      : TDThemeData.defaultData();
  // Explicit semantic tokens are needed: several TDesign controls also use
  // gray/font tokens directly, rather than reading Flutter's ColorScheme.
  final td = source.copyWithTDThemeData(
    dark ? 'npqDark' : 'npqLight',
    colorMap: {
      'bgColorPage': page,
      'bgColorContainer': surface,
      'bgColorContainerHover': elevated,
      'bgColorContainerActive': elevated,
      'bgColorContainerSelect': elevated,
      'bgColorSecondaryContainer': elevated,
      'bgColorSecondaryContainerHover': elevated,
      'bgColorSecondaryContainerActive': elevated,
      'bgColorComponent': elevated,
      'bgColorComponentHover': elevated,
      'bgColorComponentActive': elevated,
      'bgColorComponentDisabled': elevated,
      'textColorPrimary': ink,
      'textColorSecondary': muted,
      'textColorPlaceholder': muted,
      'textDisabledColor': muted.withValues(alpha: .6),
      'textColorBrand': accent,
      'textColorLink': accent,
      'fontGyColor1': ink,
      'fontGyColor2': muted,
      'fontGyColor3': muted,
      'componentStrokeColor': border,
      'componentBorderColor': border,
      'brandNormalColor': dark ? const Color(0xFF407EEB) : blue,
      'brandLightColor': dark
          ? const Color(0xFF203554)
          : const Color(0xFFE8EFFF),
      if (!dark) 'grayColor1': const Color(0xFFEEF1F6),
      if (!dark) 'grayColor2': const Color(0xFFE3E8F0),
      if (dark) 'grayColor1': elevated,
      if (dark) 'grayColor2': elevated,
      if (dark) 'grayColor3': border,
      if (dark) 'grayColor4': border,
    },
  );
  final scheme = (dark ? const ColorScheme.dark() : const ColorScheme.light())
      .copyWith(
        primary: accent,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: ink,
        surfaceContainer: surface,
        surfaceContainerLow: surface,
        surfaceTint: Colors.transparent,
        error: dark ? const Color(0xFFFF8A80) : const Color(0xFFD54941),
        surfaceContainerHighest: elevated,
        onSurfaceVariant: muted,
        outline: border,
        outlineVariant: border,
      );
  return ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: page,
    dividerColor: border,
    extensions: [td],
    iconTheme: IconThemeData(color: ink),
    textTheme: (dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme)
        .apply(
          bodyColor: ink,
          displayColor: ink,
          decoration: TextDecoration.none,
        ),
  );
}
