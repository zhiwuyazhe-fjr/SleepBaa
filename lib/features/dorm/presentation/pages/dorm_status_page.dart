import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';

class DormStatusPage extends StatelessWidget {
  const DormStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppBar(title: const Text('Dorm Status')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: services.dormRepository,
          builder: (BuildContext context, Widget? child) {
            final dorm = services.dormRepository.currentDorm;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SectionTitle(title: 'Roommate Status'),
                  const SizedBox(height: AppSpacing.md),
                  ...dorm.members.map(
                    (roommate) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Text(roommate.name.characters.first),
                          ),
                          title: Text(roommate.name),
                          subtitle: Text(roommate.note),
                          trailing: Text(roommate.status.name),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionTitle(title: 'Noise / Light / Quiet Status'),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.volume_down_rounded),
                          title: const Text('Noise'),
                          trailing: Text('${dorm.noiseDb} dB'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.light_mode_rounded),
                          title: const Text('Light'),
                          trailing: Text(dorm.lightLabel),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.bedroom_parent_rounded),
                          title: const Text('Quiet'),
                          trailing: Text(dorm.quietLabel),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
