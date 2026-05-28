import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/icon_badge.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';

class InterferenceFactorPage extends StatefulWidget {
  const InterferenceFactorPage({super.key});

  @override
  State<InterferenceFactorPage> createState() => _InterferenceFactorPageState();
}

class _InterferenceFactorPageState extends State<InterferenceFactorPage> {
  bool _didRequestAutoRefresh = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRequestAutoRefresh) {
      return;
    }
    _didRequestAutoRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.appServices.interferenceProbeController
          .ensureFreshForDetailPage();
    });
  }

  Future<void> _detectFactor(InterferenceFactorType type) {
    return context.appServices.interferenceProbeController.detectFactor(type);
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final NightMoodPalette palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: services.interferenceProbeController,
          builder: (BuildContext context, Widget? child) {
            final TonightInterferenceState state =
                services.interferenceProbeController.currentState;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                140,
              ),
              children: <Widget>[
                AppDetailPageHeader(
                  title: '今晚影响因素',
                  onBack: () => context.pop(),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppRadius.surfacePrimary,
                  border: Border.all(color: palette.primarySoft.withAlpha(90)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '今晚先一起看看，哪些细小因素正在悄悄影响你的安睡。',
                        style: AppTypography.sectionTitle(textTheme),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '进入后小眠已经再次帮你检测啦',
                        style: AppTypography.bodyMuted(
                          textTheme,
                        ).copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionTitle(
                  title: '今晚的四个观察点',
                  actionLabel: '回到首页',
                  titleStyle: AppTypography.sectionTitle(textTheme),
                  actionStyle: AppTypography.meta(
                    textTheme,
                  ).copyWith(color: AppColors.textSecondary),
                  onAction: () => context.pop(),
                ),
                const SizedBox(height: AppSpacing.md),
                ...state.factors.map(
                  (InterferenceFactorSnapshot factor) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _FactorDetailCard(
                      factor: factor,
                      onRetest: factor.type == InterferenceFactorType.emotion
                          ? null
                          : () => _detectFactor(factor.type),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppRadius.surfacePrimary,
                  color: AppColors.surfaceMuted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '和小眠说一说，看看还有哪些因素影响了今晚的安睡……',
                        style: AppTypography.panelTitle(textTheme),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '如果你觉得这些结果还不够完整，可以把当下的感受、舍友动态，或者刚刚发生的小插曲告诉小眠，它会继续帮你一起梳理。',
                        style: AppTypography.bodyMuted(
                          textTheme,
                        ).copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: '和小眠聊一聊',
                        icon: Icons.auto_awesome_rounded,
                        size: PrimaryButtonSize.compact,
                        onPressed: () => context.push(AppRoutes.assistant),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FactorDetailCard extends StatelessWidget {
  const _FactorDetailCard({required this.factor, required this.onRetest});

  final InterferenceFactorSnapshot factor;
  final VoidCallback? onRetest;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final _FactorVisual visual = _visualOf(factor.type, palette);
    final bool isWorking = factor.status == InterferenceFactorStatus.measuring;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadius.surfacePrimary,
      border: Border.all(color: visual.borderColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconBadge(
                icon: visual.icon,
                backgroundColor: visual.badgeBackground,
                iconColor: visual.badgeForeground,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      factor.title,
                      style: AppTypography.cardTitle(textTheme),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _headlineFor(factor),
                      style: AppTypography.bodyMuted(
                        textTheme,
                      ).copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: visual.badgeBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  factor.gradeLabel,
                  style: AppTypography.chip(textTheme).copyWith(
                    color: visual.badgeForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _MetaChip(label: '当前值', value: factor.value),
              _MetaChip(label: '状态', value: _statusLabelOf(factor.status)),
              _MetaChip(
                label: '最近检测',
                value: _measuredAtLabel(factor.measuredAt),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(factor.detail, style: AppTypography.body(textTheme)),
          if (isWorking) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(minHeight: 6),
          ],
          if (onRetest != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: isWorking ? '检测中...' : '再次检测',
              icon: Icons.refresh_rounded,
              variant: PrimaryButtonVariant.soft,
              size: PrimaryButtonSize.compact,
              onPressed: isWorking ? null : onRetest,
            ),
          ],
        ],
      ),
    );
  }

  String _headlineFor(InterferenceFactorSnapshot factor) {
    return switch (factor.status) {
      InterferenceFactorStatus.measuring => '小眠正在重新看看这一项',
      InterferenceFactorStatus.denied => '需要先打开相关权限，才能继续判断',
      InterferenceFactorStatus.unavailable => '这次没有拿到可用结果',
      InterferenceFactorStatus.unsupported => '当前设备暂时不支持这项能力',
      InterferenceFactorStatus.error => '这次没测成功，稍后再试一次',
      InterferenceFactorStatus.idle => '还没开始检测，点一下就能更新',
      InterferenceFactorStatus.ready => '这是目前离你最近的一次结果',
    };
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label  $value', style: AppTypography.chip(textTheme)),
    );
  }
}

class _FactorVisual {
  const _FactorVisual({
    required this.icon,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.borderColor,
  });

  final IconData icon;
  final Color badgeBackground;
  final Color badgeForeground;
  final Color borderColor;
}

_FactorVisual _visualOf(InterferenceFactorType type, NightMoodPalette palette) {
  return switch (type) {
    InterferenceFactorType.noise => _FactorVisual(
      icon: Icons.volume_up_outlined,
      badgeBackground: palette.primarySoft.withAlpha(24),
      badgeForeground: palette.primaryDeep,
      borderColor: palette.primarySoft.withAlpha(80),
    ),
    InterferenceFactorType.light => _FactorVisual(
      icon: Icons.lightbulb_outline_rounded,
      badgeBackground: const Color(0xFFFFF3D7),
      badgeForeground: const Color(0xFF9D6B00),
      borderColor: const Color(0xFFFFE1A0),
    ),
    InterferenceFactorType.phoneUsage => _FactorVisual(
      icon: Icons.smartphone_rounded,
      badgeBackground: const Color(0xFFE8EEFF),
      badgeForeground: const Color(0xFF3C5CCF),
      borderColor: const Color(0xFFC9D6FF),
    ),
    InterferenceFactorType.emotion => _FactorVisual(
      icon: Icons.favorite_border_rounded,
      badgeBackground: const Color(0xFFFFE7EE),
      badgeForeground: const Color(0xFFD44E78),
      borderColor: const Color(0xFFFFC5D6),
    ),
  };
}

String _statusLabelOf(InterferenceFactorStatus status) {
  return switch (status) {
    InterferenceFactorStatus.idle => '待检测',
    InterferenceFactorStatus.measuring => '检测中',
    InterferenceFactorStatus.ready => '已更新',
    InterferenceFactorStatus.denied => '未授权',
    InterferenceFactorStatus.unavailable => '不可用',
    InterferenceFactorStatus.unsupported => '暂不支持',
    InterferenceFactorStatus.error => '检测失败',
  };
}

String _measuredAtLabel(DateTime? measuredAt) {
  if (measuredAt == null) {
    return '暂无';
  }
  final DateTime local = measuredAt.toLocal();
  final String hh = local.hour.toString().padLeft(2, '0');
  final String mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
