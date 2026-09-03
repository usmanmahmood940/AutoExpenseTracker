import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Platform-adaptive page shell — Cupertino on iOS, Material elsewhere.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    required this.body,
    this.title,
    this.navigationBar,
    this.appBar,
    this.backgroundColor,
    this.applySafeArea = true,
    super.key,
  });

  final Widget body;
  final String? title;
  final ObstructingPreferredSizeWidget? navigationBar;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;

  /// When false, the body is not wrapped in [SafeArea] (e.g. full-bleed glass headers).
  final bool applySafeArea;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final useCupertino = (platform == TargetPlatform.iOS ||
            platform == TargetPlatform.macOS) &&
        applySafeArea;

    // Full-bleed layouts (custom glass headers) use Material [Scaffold] so
    // CupertinoPageScaffold does not own chrome / hit-testing.
    if (useCupertino) {
      final hasChrome = navigationBar != null || title != null;
      final barColor =
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        navigationBar: navigationBar ??
            (title != null
                ? CupertinoNavigationBar(
                    middle: Text(title!),
                    // Opaque so [CupertinoPageScaffold] pads the body under the
                    // bar. A translucent bar + [SafeArea] left a sticky gap.
                    backgroundColor: barColor.withValues(alpha: 1),
                    automaticallyImplyLeading: false,
                    leading: _maybeBackButton(context, iosStyle: true),
                  )
                : null),
        // Material widgets (TextField, SwitchListTile, etc.) need a Material
        // ancestor; CupertinoPageScaffold does not provide one.
        child: Material(
          type: MaterialType.transparency,
          // Top inset is owned by the nav bar. Another [SafeArea] here becomes
          // a blank band that does not scroll with the body.
          child: SafeArea(top: !hasChrome, child: body),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar ??
          (title != null
              ? AppBar(
                  title: Text(title!),
                  automaticallyImplyLeading: false,
                  leading: _maybeBackButton(context, iosStyle: false),
                )
              : null),
      body: body,
    );
  }

  Widget? _maybeBackButton(BuildContext context, {required bool iosStyle}) {
    if (!(ModalRoute.of(context)?.canPop ?? false)) return null;
    return _AdaptiveBackButton(iosStyle: iosStyle);
  }
}

/// Back control that uses Material icons (always bundled) instead of
/// [CupertinoIcons], which render as "?" when `cupertino_icons` is missing.
class _AdaptiveBackButton extends StatelessWidget {
  const _AdaptiveBackButton({required this.iosStyle});

  final bool iosStyle;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      iosStyle ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_rounded,
      size: iosStyle ? 20 : 24,
    );

    if (iosStyle) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        onPressed: () => Navigator.of(context).maybePop(),
        child: Semantics(
          button: true,
          label: MaterialLocalizations.of(context).backButtonTooltip,
          child: icon,
        ),
      );
    }

    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => Navigator.of(context).maybePop(),
      icon: icon,
    );
  }
}
