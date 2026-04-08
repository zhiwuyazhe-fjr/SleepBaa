import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class NightAwakeningLogPage extends StatefulWidget {
  const NightAwakeningLogPage({super.key});

  @override
  State<NightAwakeningLogPage> createState() => _NightAwakeningLogPageState();
}

class _NightAwakeningLogPageState extends State<NightAwakeningLogPage> {
  TimeOfDay _time = TimeOfDay.now();
  int _minutesToSleep = 12;
  String _trigger = '轻微噪声';
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记录夜醒')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: <Widget>[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('夜醒时间', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (picked != null) {
                        setState(() => _time = picked);
                      }
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(_time.format(context)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('可能诱因', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <String>['轻微噪声', '光线变化', '身体不适', '做梦惊醒', '情绪波动']
                        .map((String trigger) {
                          return ChoiceChip(
                            label: Text(trigger),
                            selected: _trigger == trigger,
                            onSelected: (_) =>
                                setState(() => _trigger = trigger),
                          );
                        })
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        '重新入睡时长',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Text('$_minutesToSleep min'),
                    ],
                  ),
                  Slider(
                    value: _minutesToSleep.toDouble(),
                    min: 1,
                    max: 45,
                    divisions: 44,
                    onChanged: (double value) {
                      setState(() => _minutesToSleep = value.round());
                    },
                  ),
                  TextField(
                    controller: _noteController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '补充记录',
                      hintText: '比如：是否翻身、是否喝水、当时的情绪感受',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: '保存夜醒记录',
              onPressed: () async {
                final NavigatorState navigator = Navigator.of(context);
                final DateTime now = DateTime.now();
                final DateTime occurredAt = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  _time.hour,
                  _time.minute,
                );
                await context.appServices.sleepExperienceController
                    .addNightAwakening(
                      occurredAt: occurredAt,
                      trigger: _trigger,
                      minutesToSleep: _minutesToSleep,
                      note: _noteController.text.trim(),
                    );
                if (!context.mounted) {
                  return;
                }
                notifyPassiveToast(context, message: '夜醒记录已保存');
                navigator.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
