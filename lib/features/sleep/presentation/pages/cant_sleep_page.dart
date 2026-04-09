import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class CantSleepPage extends StatefulWidget {
  const CantSleepPage({super.key});

  @override
  State<CantSleepPage> createState() => _CantSleepPageState();
}

class _CantSleepPageState extends State<CantSleepPage> {
  String _selectedCause = '思绪太多';

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: ListenableBuilder(
        listenable: services.audioPlaybackController,
        builder: (BuildContext context, Widget? child) {
          final NightMoodPalette palette = context.nightMoodPalette;
          final _SleepBlockPlan plan = _plans[_selectedCause]!;
          final AudioTrack track =
              services.audioPlaybackController.currentTrack ??
              services.recommendationRepository.tonightRecommendations
                  .firstWhere((NightRecommendation item) => item.track != null)
                  .track!;

          return Stack(
            children: <Widget>[
              const Positioned(
                left: -100,
                top: 30,
                child: _DarkGlow(size: 300, color: Color(0x1237C7A4)),
              ),
              const Positioned(
                right: -80,
                bottom: 40,
                child: _DarkGlow(size: 280, color: Color(0x102A8E78)),
              ),
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _TopCircleButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => context.pop(),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      '难以入睡',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.onDark),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '先别着急清醒，告诉我现在最卡住你的是什么，我们顺着这个点慢慢放松。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onDark.withAlpha(170),
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _DarkPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '今晚更像是哪一种在打断你入睡？',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: AppColors.onDark),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children:
                                <String>[
                                  '思绪太多',
                                  '环境打扰',
                                  '身体不适',
                                  '入睡压力',
                                ].map((String cause) {
                                  final bool selected = _selectedCause == cause;
                                  return _CauseChip(
                                    label: cause,
                                    selected: selected,
                                    palette: palette,
                                    onTap: () =>
                                        setState(() => _selectedCause = cause),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _DarkPanel(
                      tint: palette.primary.withAlpha(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            plan.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: AppColors.onDark),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            plan.subtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.onDark.withAlpha(170),
                                  height: 1.5,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ...plan.steps.asMap().entries.map(
                            (MapEntry<int, String> item) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: palette.primarySoft.withAlpha(50),
                                    ),
                                    child: Text(
                                      '${item.key + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppColors.onDark,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      item.value,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.onDark.withAlpha(
                                              205,
                                            ),
                                            height: 1.55,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(8),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: palette.primarySoft.withAlpha(40),
                              ),
                            ),
                            child: Text(
                              plan.comfortNote,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.onDark.withAlpha(180),
                                    height: 1.55,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _DarkPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '继续助眠音频',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: AppColors.onDark),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            track.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: AppColors.onDark),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${track.subtitle} · ${Formatters.formatDuration(track.duration)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.onDark.withAlpha(160),
                                ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: PrimaryButton(
                                  label: services.audioPlaybackController.isPlaying
                                      ? '暂停音频'
                                      : '继续播放',
                                  foregroundColor: Colors.white,
                                  onPressed: () async {
                                    await services.audioPlaybackController
                                        .toggleTrack(track);
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: PrimaryButton(
                                  label: '停止',
                                  variant: PrimaryButtonVariant.ghost,
                                  foregroundColor: AppColors.onDark,
                                  borderColor: AppColors.darkBorder,
                                  onPressed: () async {
                                    await services.audioPlaybackController.stop();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DarkPanel extends StatelessWidget {
  const _DarkPanel({required this.child, this.tint});

  final Widget child;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: tint ?? AppColors.darkCard,
        borderRadius: AppRadius.cardLarge,
        border: Border.all(color: AppColors.darkBorder),
        boxShadow: AppColors.floatingShadow,
      ),
      child: child,
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.darkSurface.withAlpha(110),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Icon(icon, color: AppColors.onDark.withAlpha(220), size: 20),
        ),
      ),
    );
  }
}

class _DarkGlow extends StatelessWidget {
  const _DarkGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color,
            blurRadius: size * 0.4,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );
  }
}

class _CauseChip extends StatelessWidget {
  const _CauseChip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final NightMoodPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? palette.primary.withAlpha(210)
                : AppColors.darkSurface.withAlpha(190),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? palette.primarySoft.withAlpha(160)
                  : AppColors.darkBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white.withAlpha(235),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? Colors.white
                      : AppColors.onDark.withAlpha(220),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepBlockPlan {
  const _SleepBlockPlan({
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.comfortNote,
  });

  final String title;
  final String subtitle;
  final List<String> steps;
  final String comfortNote;
}

const Map<String, _SleepBlockPlan> _plans = <String, _SleepBlockPlan>{
  '思绪太多': _SleepBlockPlan(
    title: '先把脑子里的线头收一收',
    subtitle: '目标不是立刻想通，而是先把大脑从“继续处理问题”切回“允许休息”。',
    steps: <String>[
      '先去“灵感记事 / 事记”里把正在想的事用简短的话记下来，不用展开分析，快速写完就好，重点是先把思绪从脑子里放出去。',
      '记完以后，先别急着继续想下一步，只要顺着呼吸慢慢吐气，把注意力带回身体，让脑子知道这件事已经暂时被安放好了。',
      '如果还是会反复想到同一件事，就把注意力轻轻放到一个具体感觉上，比如被子的重量、枕头触感，想到别的也没关系，再慢慢带回来就行。',
    ],
    comfortNote:
        '睡前脑子转个不停很常见，尤其在任务密集或情绪还没收尾的时候。今晚先把问题暂存，不代表你逃避它，而是在给大脑一次恢复的机会。',
  ),
  '环境打扰': _SleepBlockPlan(
    title: '先把外界刺激降到最低',
    subtitle: '环境噪声和光线不是靠硬扛解决的，先把刺激源压低，入睡阻力会立刻小很多。',
    steps: <String>[
      '先连续 30 秒判断干扰是“持续型”还是“偶发型”：持续噪声优先戴耳塞或开白噪音，偶发噪声优先调整姿势和心理预期。',
      '如果手边有耳塞，先戴上 10 分钟再判断效果；如果没有，就把枕头稍微转向更安静的一侧，并让被角覆盖一部分耳廓。',
      '如果光线在干扰你，立刻把视线离开亮源，闭眼后只做 12 次缓慢眨眼式放松，再让眼周和额头一起松下来。',
    ],
    comfortNote:
        '很多人并不是“睡不着”，而是被外部刺激一层层拉回清醒。先处理环境，比一味逼自己放松更有效。',
  ),
  '身体不适': _SleepBlockPlan(
    title: '先让身体从警觉里退下来',
    subtitle: '当身体还在绷着、热着、酸着的时候，大脑通常也很难真正进入睡眠。',
    steps: <String>[
      '先做 6 轮“紧 5 秒, 松 8 秒”：依次从肩膀、手掌、小腿开始，不要全身一起用力，避免越做越清醒。',
      '如果有口干、闷热或轻微不适，先小口喝 2 到 3 口温水，或把被子打开 1 分钟再重新盖好，不要一次起身折腾太久。',
      '重新躺下后，连续 2 分钟只关注一个部位，比如肩膀或小腿，默念“这里正在慢慢变松”，不要同时扫描全身。',
    ],
    comfortNote:
        '很多夜里的“睡不着”其实是身体还没收到休息信号。先照顾身体，比急着催眠自己更容易见效。',
  ),
  '入睡压力': _SleepBlockPlan(
    title: '先把“必须快点睡着”的压力放下来',
    subtitle: '一旦开始担心自己睡不着，大脑就会把“入睡”本身也当成任务，越努力越清醒。',
    steps: <String>[
      '先给自己一个 20 分钟缓冲期，这段时间不看钟、不判断“有没有睡意”、也不计算明天还剩多久能睡。',
      '接下来做一句固定提示，配合呼气默念 6 次：‘我现在先休息，不急着立刻睡着。’每次只在呼气时说一次。',
      '如果 20 分钟后还是完全清醒，再离床 5 到 10 分钟，做低刺激的事，例如坐着听轻音乐或看纸质文字，不碰强光屏幕。',
    ],
    comfortNote:
        '不少人在重要日程前一晚都会被“必须睡着”这件事反过来压住。今晚先把目标从“马上睡着”换成“稳定休息”，身体通常会更快接手。',
  ),
};
