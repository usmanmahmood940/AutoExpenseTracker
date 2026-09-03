import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// One header + its rows inside a [TransactionGroupCard.grouped].
class TransactionGroupSection {
  const TransactionGroupSection({this.header, required this.children});

  final Widget? header;
  final List<Widget> children;
}

/// Bordered container that stacks a set of rows (typically
/// `TransactionListTile`s) separated by inset hairline dividers.
///
/// Use the default constructor for a single list of tiles (search, merchant).
/// Use [TransactionGroupCard.grouped] to keep several day sections in one card.
class TransactionGroupCard extends StatelessWidget {
  const TransactionGroupCard({required List<Widget> this.children, super.key})
    : sections = null;

  const TransactionGroupCard.grouped({
    required List<TransactionGroupSection> this.sections,
    super.key,
  }) : children = null;

  final List<Widget>? children;
  final List<TransactionGroupSection>? sections;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final dividerColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.cardBorder(brightness)),
        boxShadow: AppShadows.card(brightness),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sections != null
              ? _sectionRows(sections!, dividerColor)
              : _tileRows(children!, dividerColor),
        ),
      ),
    );
  }

  List<Widget> _tileRows(List<Widget> tiles, Color dividerColor) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      rows.add(tiles[i]);
      if (i != tiles.length - 1) {
        rows.add(_divider(dividerColor));
      }
    }
    return rows;
  }

  List<Widget> _sectionRows(
    List<TransactionGroupSection> groups,
    Color dividerColor,
  ) {
    final rows = <Widget>[];
    for (final section in groups) {
      if (section.header != null) {
        rows.add(section.header!);
      }
      for (var i = 0; i < section.children.length; i++) {
        rows.add(section.children[i]);
        if (i != section.children.length - 1) {
          rows.add(_divider(dividerColor));
        }
      }
    }
    return rows;
  }

  Widget _divider(Color color) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
      color: color,
    );
  }
}
