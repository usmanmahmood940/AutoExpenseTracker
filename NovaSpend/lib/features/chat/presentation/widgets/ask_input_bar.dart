import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class AskInputBar extends StatelessWidget {
  const AskInputBar({
    required this.controller,
    required this.enabled,
    required this.canSend,
    required this.onChanged,
    required this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool canSend;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onChanged: onChanged,
              onSubmitted: (_) {
                if (canSend) onSend();
              },
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurface,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: l10n.askHint,
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                filled: true,
                fillColor: AppColors.neutralFill(brightness),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.smPlus2,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: AppColors.border(brightness)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: AppColors.border(brightness)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(
                    color: AppColors.primaryInk(brightness),
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: AppColors.border(brightness)),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Tooltip(
            message: l10n.askSend,
            child: FilledButton(
              onPressed: canSend ? onSend : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryStrong,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.neutralFill(brightness),
                disabledForegroundColor: cs.onSurfaceVariant,
                minimumSize: const Size(48, 48),
                maximumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
                elevation: 0,
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 22,
                color: canSend ? Colors.white : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
