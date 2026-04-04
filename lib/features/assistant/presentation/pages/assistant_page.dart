import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/core/widgets/status_chip.dart';
import 'package:sleep_dorm_app/mock/mock_data.dart';

class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep Assistant')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: <Widget>[
                  Text('最近建议', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  ...MockData.assistantSuggestions.map(
                    (AssistantSuggestion suggestion) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            StatusChip(
                              label: suggestion.tag,
                              backgroundColor: AppColors.primarySoft.withAlpha(
                                85,
                              ),
                              foregroundColor: AppColors.primaryDeep,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(suggestion.title, style: textTheme.titleLarge),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              suggestion.summary,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('对话列表', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  ...MockData.conversation.map(
                    (ConversationPlaceholder item) => Align(
                      alignment: item.fromAssistant
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: AppCard(
                            color: item.fromAssistant
                                ? AppColors.surface
                                : AppColors.primarySoft.withAlpha(75),
                            child: Text(
                              item.message,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: AppCard(
                      color: AppColors.surfaceMuted,
                      boxShadow: const <BoxShadow>[],
                      child: Text(
                        '文本输入框占位：告诉我今晚的困扰…',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  PrimaryButton(
                    label: '语音',
                    icon: Icons.mic_none_rounded,
                    variant: PrimaryButtonVariant.soft,
                    expand: false,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
