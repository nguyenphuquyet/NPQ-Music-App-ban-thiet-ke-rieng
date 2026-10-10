# Local compatibility patch

Source: tdesign_flutter 0.2.7 from pub.dev (Tencent TDesign).
Original LICENSE is retained alongside the source and assets.

Flutter 3.47.6 declares IconData final. Upstream td_icons.dart extends it in
_TDIconsData, which prevents both debug and release compilation.

This copy removes that subclass, changes generated constants to direct const
IconData(codePoint, fontFamily: 'TDIcons', fontPackage: 'tdesign_flutter'), and
changes TDIcons.all to Map<String, IconData>. Codepoints and font assets are
unchanged. The original private subclass name field is omitted; this app and
package components do not use it. No machine-global SDK or pub cache is edited.

Remove dependency_overrides when an upstream release supports this SDK.
