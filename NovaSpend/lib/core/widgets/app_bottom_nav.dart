import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';

/// A single destination in [AppBottomNav].
class AppBottomNavItem {
  const AppBottomNavItem({
    required this.iconAsset,
    required this.label,
  });

  final String iconAsset;
  final String label;
}

/// Bottom navigation matching the NovaSpend tab bar: outline icons, muted
/// unselected ink, and green icon + label for the selected tab.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppBottomNavItem> destinations;

  static const double _iconSize = 22;

  /// Content row height, excluding the top hairline and system inset.
  static const double _barHeight = 64;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Scaffold gives [bottomNavigationBar] a max height of the full screen.
    // heightFactor shrink-wraps the bar so it does not expand into that slot.
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: Material(
        color: AppColors.card(brightness),
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border(brightness).withValues(alpha: 0.4),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: SizedBox(
                height: _barHeight,
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _NavDestination(
                          item: destinations[i],
                          selected: i == selectedIndex,
                          onTap: () {
                            if (i == selectedIndex) return;
                            HapticFeedback.selectionClick();
                            onDestinationSelected(i);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDestination extends StatefulWidget {
  const _NavDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavDestination> createState() => _NavDestinationState();
}

class _NavDestinationState extends State<_NavDestination> {
  bool _pressed = false;

  Duration _duration(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.fast;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final duration = _duration(context);
    final color = widget.selected
        ? AppColors.navActiveForeground(brightness)
        : theme.colorScheme.onSurface.withValues(alpha: 0.72);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: SvgPicture.asset(
                    widget.item.iconAsset,
                    width: AppBottomNav._iconSize,
                    height: AppBottomNav._iconSize,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ExcludeSemantics(
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: AppMotion.standard,
                    style: (theme.textTheme.labelMedium ?? const TextStyle())
                        .copyWith(
                      fontSize: 11.5,
                      fontWeight:
                          widget.selected ? FontWeight.w600 : FontWeight.w500,
                      height: 1.2,
                      letterSpacing: 0.1,
                      color: color,
                    ),
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
