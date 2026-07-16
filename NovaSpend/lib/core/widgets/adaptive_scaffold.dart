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
    super.key,
  });

  final Widget body;
  final String? title;
  final ObstructingPreferredSizeWidget? navigationBar;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;

    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
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
