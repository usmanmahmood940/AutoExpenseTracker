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
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        navigationBar: navigationBar ??
            (title != null
                ? CupertinoNavigationBar(middle: Text(title!))
                : null),
        // Material widgets (TextField, SwitchListTile, etc.) need a Material
        // ancestor; CupertinoPageScaffold does not provide one.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(child: body),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar ??
          (title != null ? AppBar(title: Text(title!)) : null),
      body: body,
    );
  }
}
