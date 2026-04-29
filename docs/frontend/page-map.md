# Page Map

最后核验日期：2026-04-29。本文以 `lib/app/routes.dart` 的当前路由表为准。

## Redirect

| Route | 当前行为 |
| --- | --- |
| `/` | 重定向到 `/home`。 |
| `/home` | 根据 `HomeMode` 重定向到 `/home/pre_sleep` 或 `/home/post_sleep`。 |
| `/profile/settings/edit` | 旧路径，重定向到 `/profile/settings/account/profile/edit`。 |

CloudBase 模式下，如果手机号身份未验证，业务页面会被门禁到 `/auth/phone`。若存在 active sleep session，`/`、`/home`、`/home/pre_sleep` 会进入 `/home/post_sleep`。

## Bottom Tab Shell

| Tab | Route | Page | 文件 |
| --- | --- | --- | --- |
| 首页 | `/home/pre_sleep` | `NightWelcomeGatePage` -> `HomePreSleepPage` | `lib/features/night_mood/presentation/pages/night_welcome_gate_page.dart`, `lib/features/home/presentation/pages/home_pre_sleep_page.dart` |
| 宿舍 | `/dorm` | `DormPage` | `lib/features/dorm/presentation/pages/dorm_page.dart` |
| 我的 | `/profile` | `ProfilePage` | `lib/features/profile/presentation/pages/profile_page.dart` |

## Home and Sleep

| Route | Page | 文件 | 参数 |
| --- | --- | --- | --- |
| `/home/post_sleep` | `HomePostSleepPage` | `lib/features/home/presentation/pages/home_post_sleep_page.dart` | 无。 |
| `/home/quick_actions/edit` | `HomeQuickActionsEditPage` | `lib/features/home/presentation/pages/home_quick_actions_edit_page.dart` | 无。 |
| `/analysis/interference_factors` | `InterferenceFactorPage` | `lib/features/analysis/presentation/pages/interference_factor_page.dart` | 无。 |
| `/intervention/task` | `MicroInterventionTaskPage` | `lib/features/intervention/presentation/pages/micro_intervention_task_page.dart` | 无。 |
| `/feedback/morning` | `MorningFeedbackPage` | `lib/features/feedback/presentation/pages/morning_feedback_page.dart` | `sessionId`，`resumeToSleep=1`。 |
| `/log/night_awakening` | `NightAwakeningLogPage` | `lib/features/logs/presentation/pages/night_awakening_log_page.dart` | 无。 |
| `/sleep/cant_sleep` | `CantSleepPage` | `lib/features/sleep/presentation/pages/cant_sleep_page.dart` | 无。 |
| `/sleep/audio_catalog` | `SleepAudioCatalogPage` | `lib/features/sleep/presentation/pages/sleep_audio_catalog_page.dart` | 无。 |

## Dream

| Route | Page | 文件 | 参数 |
| --- | --- | --- | --- |
| `/dream/detail` | `DreamDetailPage` | `lib/features/dream/presentation/pages/dream_detail_page.dart` | 无。 |
| `/dream/journal` | `DreamJournalPage` | `lib/features/dream/presentation/pages/dream_journal_page.dart` | 无。 |

## Sleep Encyclopedia

| Route | Page | 文件 | 参数 |
| --- | --- | --- | --- |
| `/sleep/encyclopedia` | `SleepEncyclopediaPage` | `lib/features/sleep_encyclopedia/presentation/pages/sleep_encyclopedia_page.dart` | 无。 |
| `/sleep/encyclopedia/category` | `SleepEncyclopediaCategoryPage` | `lib/features/sleep_encyclopedia/presentation/pages/sleep_encyclopedia_category_page.dart` | `slug`。 |
| `/sleep/encyclopedia/topic` | `SleepEncyclopediaTopicPage` | `lib/features/sleep_encyclopedia/presentation/pages/sleep_encyclopedia_topic_page.dart` | `slug`。 |

## Dorm

| Route | Page | 文件 | 参数 |
| --- | --- | --- | --- |
| `/dorm/rules` | `DormRulesPage` | `lib/features/dorm/presentation/pages/dorm_rules_page.dart` | `review=1` 时打开审核 overlay。 |
| `/dorm/invite` | `DormInvitePage` | `lib/features/dorm/presentation/pages/dorm_invite_page.dart` | 无。 |
| `/dorm/status` | `DormStatusPage` | `lib/features/dorm/presentation/pages/dorm_status_page.dart` | 无。 |
| `/dorm/badges` | `HonorBadgesPage` | `lib/features/profile/presentation/pages/honor_badges_page.dart` | 无。 |

## Profile

| Route | Page | 文件 | 参数 |
| --- | --- | --- | --- |
| `/profile/report` | `SleepReportPage` | `lib/features/profile/presentation/pages/sleep_report_page.dart` | 无。 |
| `/profile/calendar` | `CalendarCheckinPage` | `lib/features/profile/presentation/pages/calendar_checkin_page.dart` | 无。 |
| `/profile/settings` | `SettingsPage` | `lib/features/profile/presentation/pages/settings_page.dart` | 无。 |
| `/profile/settings/account` | `AccountManagementPage` | `lib/features/profile/presentation/pages/profile_account_pages.dart` | 无。 |
| `/profile/settings/account/profile` | `AccountProfilePage` | `lib/features/profile/presentation/pages/profile_account_pages.dart` | 无。 |
| `/profile/settings/account/profile/edit` | `ProfileEditPage` | `lib/features/profile/presentation/pages/profile_edit_page.dart` | 无。 |
| `/profile/settings/account/password` | `AccountResetPasswordPage` | `lib/features/profile/presentation/pages/profile_account_reset_password_page.dart` | 无。 |
| `/profile/settings/account/login` | `LoginManagementPage` | `lib/features/profile/presentation/pages/profile_account_pages.dart` | 无。 |
| `/profile/settings/account/dorm` | `DormManagementPage` | `lib/features/profile/presentation/pages/profile_account_pages.dart` | 无。 |
| `/profile/faq` | `ProfileFaqPage` | `lib/features/profile/presentation/pages/profile_faq_page.dart` | 无。 |
| `/profile/badges` | `ProfileBadgesPage` | `lib/features/profile/presentation/pages/profile_badges_page.dart` | 无。 |
| `/profile/thought_vault` | `ThoughtVaultPage` | `lib/features/profile/presentation/pages/thought_vault_page.dart` | 无。 |
| `/profile/thought_detail` | `ThoughtNoteDetailPage` | `lib/features/profile/presentation/pages/thought_note_detail_page.dart` | `state.extra` 必须是 `SleepCaptureRecord`。 |

## Assistant, Auth, Notifications

| Route | Page | 文件 | 参数 |
| --- | --- | --- | --- |
| `/assistant` | `AssistantPage` | `lib/features/assistant/presentation/pages/assistant_page.dart` | `flow=sleep_capture` 开启 capture；`mode=memo` 选择事记，否则梦记；`sessionId`；`repairSession=1`。 |
| `/assistant/history` | `AssistantHistoryPage` | `lib/features/assistant/presentation/pages/assistant_history_page.dart` | 无。 |
| `/auth/phone` | `PhoneAuthPage` | `lib/features/auth/presentation/pages/phone_auth_page.dart` | 无。 |
| `/notifications` | `NotificationsPage` | `lib/features/notifications/presentation/pages/notifications_page.dart` | 无。 |

## 路由 helper

`AppRoutes` 提供带参数的 helper：

- `feedbackMorningLocation(sessionId: ..., resumeToSleep: ...)`
- `assistantSleepCaptureLocation(mode: ..., sessionId: ..., repairSession: ...)`
- `sleepEncyclopediaCategoryLocation(slug)`
- `sleepEncyclopediaTopicLocation(slug)`

新增带 query 参数的入口时，优先补 helper，避免页面散落字符串拼接。
