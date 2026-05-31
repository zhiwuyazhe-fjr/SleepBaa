import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sleep_dorm_app/app/theme/app_page_insets.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

enum _DormInviteMode { choose, create, join, manage }

class DormInvitePage extends StatefulWidget {
  const DormInvitePage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<DormInvitePage> createState() => _DormInvitePageState();
}

class _DormInvitePageState extends State<DormInvitePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _overviewController;
  late final TextEditingController _inviteCodeController;

  _DormInviteMode? _preferredMode;
  DormInvite? _generatedInvite;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _overviewController = TextEditingController();
    _inviteCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _overviewController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _createDorm(AppServices services) async {
    final String dormName = _nameController.text.trim();
    if (dormName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写宿舍名称')));
      return;
    }

    final DormRulesSettings defaults = DormRulesSettings.defaults();
    setState(() => _isBusy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final DormLocationAnchor? locationAnchor = await services
          .dormPresenceSyncController
          .captureCurrentLocationAnchor(requestPermission: true);
      await services.dormFacade.createDorm(
        name: dormName,
        overview: _overviewController.text.trim().isEmpty
            ? null
            : _overviewController.text.trim(),
        rulesSettings: defaults,
        locationAnchor: locationAnchor,
      );
      if (locationAnchor != null) {
        await services.dormPresenceSyncController.persistDormLocationAnchor(
          locationAnchor,
        );
      }
      final DormInvite invite = await services.dormFacade.createInvite();
      if (!mounted) {
        return;
      }
      setState(() {
        _generatedInvite = invite;
        _preferredMode = _DormInviteMode.manage;
      });
      messenger.showSnackBar(const SnackBar(content: Text('宿舍已创建，可以开始邀请舍友了')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('创建宿舍失败：${error.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _acceptInvite(AppServices services) async {
    final String inviteCode = _inviteCodeController.text.trim();
    if (inviteCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先输入邀请码')));
      return;
    }

    setState(() => _isBusy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await services.dormFacade.acceptInvite(inviteCode);
      if (!mounted) {
        return;
      }
      setState(() {
        _preferredMode = _DormInviteMode.manage;
        _inviteCodeController.clear();
      });
      messenger.showSnackBar(const SnackBar(content: Text('已加入宿舍')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('加入宿舍失败：${error.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _generateInvite(AppServices services) async {
    setState(() => _isBusy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final DormInvite invite = await services.dormFacade.createInvite();
      if (!mounted) {
        return;
      }
      setState(() => _generatedInvite = invite);
      messenger.showSnackBar(const SnackBar(content: Text('邀请码已更新')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('生成邀请码失败：${error.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _copyInviteCode(DormInvite invite) async {
    await Clipboard.setData(ClipboardData(text: invite.code));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('邀请码已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final AppSemanticColors appColors = context.appColors;
    return Scaffold(
      backgroundColor: appColors.pageBackground,
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.authRepository,
          services.dormRepository,
        ]),
        builder: (BuildContext context, Widget? child) {
          final Dorm dorm = services.dormFacade.currentDorm;
          final _DormInviteMode mode = _resolveMode(dorm);
          final DormInvite? invite =
              _pendingInviteFor(dorm) ?? _generatedInvite;

          return SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double widthFactor = _inviteWidthFactor(
                  constraints.maxWidth,
                );
                return Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    widthFactor: widthFactor,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        padding: AppPageInsets.page(bottom: AppSpacing.lg),
                        children: <Widget>[
                          if (widget.showAppBar) ...<Widget>[
                            _DormInviteHeader(
                              onBack: () => Navigator.of(context).maybePop(),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          _DormInviteIntroCard(dorm: dorm, mode: mode),
                          const SizedBox(height: AppSpacing.sm),
                          ...switch (mode) {
                            _DormInviteMode.choose => _buildChooseMode(),
                            _DormInviteMode.create => _buildCreateMode(
                              services,
                            ),
                            _DormInviteMode.join => _buildJoinMode(services),
                            _DormInviteMode.manage => _buildManageMode(
                              services: services,
                              dorm: dorm,
                              invite: invite,
                            ),
                          },
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildChooseMode() {
    final AppSemanticColors appColors = context.appColors;
    return <Widget>[
      AppCard(
        onTap: () => setState(() => _preferredMode = _DormInviteMode.create),
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppRadius.compactCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '创建宿舍',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '适合你是当前宿舍里第一个使用 App 的人，先完成宿舍初始化，再生成邀请码邀请舍友。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: appColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '会设置：宿舍名称、简介，并在创建后直接生成邀请模块',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppCard(
        onTap: () => setState(() => _preferredMode = _DormInviteMode.join),
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppRadius.compactCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '加入宿舍',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '如果你的舍友已经创建过宿舍，直接输入邀请码就能加入当前宿舍协作空间。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: appColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '加入后会自动同步宿舍成员、规则和室友动态。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildCreateMode(AppServices services) {
    return <Widget>[
      AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppRadius.compactCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '创建宿舍',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LabeledField(
              label: '宿舍名称',
              controller: _nameController,
              hintText: '例如 梅苑 2 栋 204',
            ),
            const SizedBox(height: AppSpacing.sm),
            _LabeledField(
              label: '宿舍简介',
              controller: _overviewController,
              maxLines: 2,
              hintText: '简单描述宿舍氛围或协作目标',
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                PrimaryButton(
                  label: _isBusy ? '创建中...' : '创建宿舍',
                  icon: Icons.home_work_rounded,
                  expand: false,
                  size: PrimaryButtonSize.compact,
                  onPressed: _isBusy ? null : () => _createDorm(services),
                ),
                PrimaryButton(
                  label: '返回选择',
                  icon: Icons.arrow_back_rounded,
                  expand: false,
                  size: PrimaryButtonSize.compact,
                  variant: PrimaryButtonVariant.ghost,
                  onPressed: _isBusy
                      ? null
                      : () => setState(
                          () => _preferredMode = _DormInviteMode.choose,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildJoinMode(AppServices services) {
    return <Widget>[
      AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppRadius.compactCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '加入宿舍',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '输入舍友分享的邀请码即可加入宿舍。加入成功后，宿舍页会自动刷新。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LabeledField(
              label: '邀请码',
              controller: _inviteCodeController,
              hintText: '例如 DORM-AB12CD',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                PrimaryButton(
                  label: _isBusy ? '加入中...' : '确认加入',
                  icon: Icons.group_add_rounded,
                  expand: false,
                  size: PrimaryButtonSize.compact,
                  onPressed: _isBusy ? null : () => _acceptInvite(services),
                ),
                PrimaryButton(
                  label: '返回选择',
                  icon: Icons.arrow_back_rounded,
                  expand: false,
                  size: PrimaryButtonSize.compact,
                  variant: PrimaryButtonVariant.ghost,
                  onPressed: _isBusy
                      ? null
                      : () => setState(
                          () => _preferredMode = _DormInviteMode.choose,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildManageMode({
    required AppServices services,
    required Dorm dorm,
    required DormInvite? invite,
  }) {
    return <Widget>[
      AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppRadius.compactCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _InfoRow(label: '当前宿舍', value: dorm.name),
            _InfoRow(label: '成员人数', value: '${dorm.members.length} 人'),
            _InfoRow(
              label: '邀请码',
              value: invite?.code ?? '暂未生成',
              selectable: invite != null,
            ),
            if (invite != null)
              _InfoRow(label: '有效期至', value: _formatDateTime(invite.expiresAt)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                PrimaryButton(
                  label: invite == null ? '生成邀请码' : '刷新邀请码',
                  icon: Icons.qr_code_rounded,
                  expand: false,
                  size: PrimaryButtonSize.compact,
                  isLoading: _isBusy,
                  loadingLabel: '处理中...',
                  onPressed: () => _generateInvite(services),
                ),
                PrimaryButton(
                  label: '复制邀请码',
                  icon: Icons.copy_rounded,
                  expand: false,
                  size: PrimaryButtonSize.compact,
                  variant: PrimaryButtonVariant.soft,
                  onPressed: invite == null
                      ? null
                      : () => _copyInviteCode(invite),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppCard(
        color: context.appColors.surfaceMuted,
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppRadius.compactCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '当前可邀请的协作内容',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...dorm.members.map(
              (DormMember member) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(
                  '• ${member.name}：${member.note}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            if (dorm.members.isEmpty)
              Text(
                '宿舍成员还没有同步过来，先生成邀请码邀请舍友加入。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    ];
  }

  _DormInviteMode _resolveMode(Dorm dorm) {
    if (dorm.id.isNotEmpty) {
      return _DormInviteMode.manage;
    }
    return _preferredMode ?? _DormInviteMode.choose;
  }

  DormInvite? _pendingInviteFor(Dorm dorm) {
    for (final DormInvite invite in dorm.invites) {
      if (invite.status == DormInviteStatus.pending) {
        return invite;
      }
    }
    return null;
  }

  String _formatDateTime(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}

class _DormInviteHeader extends StatelessWidget {
  const _DormInviteHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AppDetailPageHeader(title: '邀请舍友', onBack: onBack);
  }
}

class _DormInviteIntroCard extends StatelessWidget {
  const _DormInviteIntroCard({required this.dorm, required this.mode});

  final Dorm dorm;
  final _DormInviteMode mode;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return AppCard(
      color: appColors.accentSoft,
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: AppRadius.card,
      boxShadow: const <BoxShadow>[],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            mode == _DormInviteMode.manage ? dorm.name : '邀请舍友一起协作',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: appColors.accentDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            mode == _DormInviteMode.manage
                ? (dorm.overview.isEmpty
                      ? '现在可以把邀请码发给舍友，大家一起同步睡眠状态和宿舍动态。'
                      : dorm.overview)
                : '先决定创建宿舍或通过邀请码加入，之后会同步宿舍成员、规则和室友动态。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: appColors.accentDeep,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

double _inviteWidthFactor(double maxWidth) {
  if (maxWidth >= 1200) {
    return 0.38;
  }
  if (maxWidth >= 900) {
    return 0.48;
  }
  if (maxWidth >= 700) {
    return 0.68;
  }
  return 1;
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        isDense: true,
        filled: true,
        fillColor: appColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide(color: appColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide(color: appColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide(color: appColors.textSecondary),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final Widget valueWidget = selectable
        ? SelectableText(value, style: Theme.of(context).textTheme.bodyMedium)
        : Text(value, style: Theme.of(context).textTheme.bodyMedium);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: appColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}
