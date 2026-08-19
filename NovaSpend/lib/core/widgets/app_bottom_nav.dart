import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
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

/// Bottom navigation matching the NovaSpend tab bar: outline icons, ink
/// unselected state, and a pale-green pill wrapping the selected icon + label.
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

  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Scaffold gives bottomNavigationBar unbounded max height. Shrink-wrap
    // so the bar does not expand to fill the screen.
    return Material(
      color: AppColors.card(brightness),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border(brightness).withValues(alpha: 0.45),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm + bottomInset,
            ),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _NavDestination(
                      item: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final color = selected
        ? AppColors.navActiveForeground(brightness)
        : theme.colorScheme.onSurface;
    final fill = selected
        ? AppColors.navActiveFill(brightness)
        : Colors.transparent;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          splashColor: AppColors.navActiveFill(brightness),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Align(
              alignment: Alignment.center,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.smPlus2,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: SvgPicture.asset(
                        item.iconAsset,
                        width: AppBottomNav._iconSize,
                        height: AppBottomNav._iconSize,
                        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ExcludeSemantics(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
