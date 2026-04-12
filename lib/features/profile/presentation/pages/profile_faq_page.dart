import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/widgets/placeholder_page_scaffold.dart';

class ProfileFaqPage extends StatelessWidget {
  const ProfileFaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPageScaffold(
      title: '常见问题',
      description: '这里会整理账号、睡眠记录、宿舍协作和夜间功能的常见问题。',
      icon: Icons.help_outline_rounded,
      primaryActionLabel: 'FAQ 内容待完善',
      supportingPoints: <String>['个人资料和头像相关问题', '睡眠记录、报告与打卡说明', '梦记、事记仓库的使用帮助'],
    );
  }
}
