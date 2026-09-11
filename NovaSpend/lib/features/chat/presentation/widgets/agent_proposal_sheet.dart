import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/chat/domain/entities/agent_proposal_entity.dart';
import 'package:nova_spend/l10n/app_strings.dart';

Future<bool?> showAgentProposalSheet(
  BuildContext context, {
  required AgentProposalEntity proposal,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AgentProposalSheet(proposal: proposal),
  );
}

class _AgentProposalSheet extends StatelessWidget {
  const _AgentProposalSheet({required this.proposal});

  final AgentProposalEntity proposal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final l10n = context.l10n;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: AppColors.surface(brightness),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(brightness).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.askProposalTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Material(
                      color: AppColors.neutralFill(brightness),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
                if (proposal.summary.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      proposal.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: proposal.steps.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: AppColors.border(brightness).withValues(alpha: 0.35),
                    ),
                    itemBuilder: (context, index) {
                      final step = proposal.steps[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          _stepLabel(step),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.askProposalCancel),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryStrong,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l10n.askProposalConfirm),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stepLabel(AgentProposalStepEntity step) {
    switch (step.op) {
      case 'create':
        final sign = step.type == 'credit' ? '+' : '-';
        return 'Add ${step.merchant ?? ''}  $sign${step.amount ?? 0}';
      case 'settle':
        return 'Settle ${step.sourceRefs.isNotEmpty ? step.sourceRefs.join(", ") : step.sourceTransactionIds.join(", ")} → ${step.primaryRef ?? step.primaryTransactionId ?? ""}';
      case 'unsettle':
        return 'Unsettle group ${step.groupId ?? ""}';
      case 'unmerge':
        return 'Unmerge ${step.transactionId ?? ""}';
      default:
        return step.op;
    }
  }
}
