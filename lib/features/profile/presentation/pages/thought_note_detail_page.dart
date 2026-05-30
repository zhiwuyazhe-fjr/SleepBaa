import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';

class ThoughtNoteDetailPage extends StatelessWidget {
  const ThoughtNoteDetailPage({super.key, required this.record});

  final SleepCaptureRecord record;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppSemanticColors appColors = context.appColors;
    return Scaffold(
      backgroundColor: appColors.pageBackground,
      appBar: AppDetailPageAppBar(
        title: '事记详情',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          120,
        ),
        children: <Widget>[
          Text(record.title, style: AppTypography.panelTitle(textTheme)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '记录于 ${_formatRecordTime(record.createdAt)}',
            style: AppTypography.meta(
              textTheme,
            ).copyWith(color: appColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            borderRadius: AppRadius.surfacePrimary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('AI整理提要', style: AppTypography.cardTitle(textTheme)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  record.outline,
                  style: AppTypography.bodyMuted(
                    textTheme,
                  ).copyWith(color: appColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('原文内容', style: AppTypography.cardTitle(textTheme)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  record.content,
                  style: AppTypography.body(textTheme).copyWith(height: 1.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRecordTime(DateTime dateTime) {
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String day = dateTime.day.toString().padLeft(2, '0');
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}
