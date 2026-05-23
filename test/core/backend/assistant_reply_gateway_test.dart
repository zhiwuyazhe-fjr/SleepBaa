import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/assistant_reply_gateway.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

void main() {
  test(
    'cloudbase assistant reply gateway retries once when stream fails before any reply payload',
    () async {
      final _FakeStreamCloudBaseAppApiClient
      appApiClient = _FakeStreamCloudBaseAppApiClient(
        postSseBehaviors: <Future<Stream<CloudBaseSseFrame>> Function()>[
          () async => throw const CloudBaseAppApiException(
            message: 'The operation was aborted.',
          ),
          () async => Stream<CloudBaseSseFrame>.fromIterable(const <
            CloudBaseSseFrame
          >[
            CloudBaseSseFrame(event: 'ack', data: '{}'),
            CloudBaseSseFrame(event: 'message_delta', data: '{"delta":"你好"}'),
            CloudBaseSseFrame(
              event: 'message_completed',
              data:
                  '{"reply":"你好","sourceMode":"remoteSuccess","assistantMessageId":"assistant-1"}',
            ),
          ]),
        ],
      );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAssistantReplyGateway gateway =
          CloudBaseAssistantReplyGateway(
            appApiClient: appApiClient,
            snapshotStore: snapshotStore,
          );

      final List<AssistantStreamEvent> events = await gateway
          .streamReply(
            prompt: '你好',
            threadId: 'thread-1',
            clientUserMessageId: 'user-1',
            clientAssistantMessageId: 'assistant-1',
            dorm: _testDorm(),
          )
          .toList();

      expect(appApiClient.postSseCallCount, 2);
      expect(
        events
            .where(
              (AssistantStreamEvent event) =>
                  event.type != AssistantStreamEventType.ack,
            )
            .map((AssistantStreamEvent event) => event.type)
            .toList(),
        <AssistantStreamEventType>[
          AssistantStreamEventType.messageDelta,
          AssistantStreamEventType.messageCompleted,
          AssistantStreamEventType.done,
        ],
      );
      expect(
        events
            .where(
              (AssistantStreamEvent event) =>
                  event.type == AssistantStreamEventType.messageCompleted,
            )
            .single
            .reply,
        '你好',
      );
    },
  );

  test('cloudbase assistant reply gateway parses agent tool events', () async {
    final _FakeStreamCloudBaseAppApiClient
    appApiClient = _FakeStreamCloudBaseAppApiClient(
      postSseBehaviors: <Future<Stream<CloudBaseSseFrame>> Function()>[
        () async => Stream<CloudBaseSseFrame>.fromIterable(const <
          CloudBaseSseFrame
        >[
          CloudBaseSseFrame(event: 'ack', data: '{}'),
          CloudBaseSseFrame(
            event: 'planning_started',
            data: '{"runId":"run-1","planId":"plan-1"}',
          ),
          CloudBaseSseFrame(
            event: 'tool_completed',
            data:
                '{"runId":"run-1","planId":"plan-1","toolName":"plan.generate_tonight","toolTitle":"生成今晚计划","updatedSurfaces":["home_pre_sleep"]}',
          ),
          CloudBaseSseFrame(
            event: 'memory_updated',
            data: '{"runId":"run-1","count":1}',
          ),
          CloudBaseSseFrame(
            event: 'agent_done',
            data:
                '{"runId":"run-1","planId":"plan-1","updatedSurfaces":["assistant_context"]}',
          ),
          CloudBaseSseFrame(
            event: 'message_completed',
            data:
                '{"reply":"done","sourceMode":"fallbackSuccess","assistantMessageId":"assistant-1","runId":"run-1"}',
          ),
          CloudBaseSseFrame(event: 'done', data: '{"runId":"run-1"}'),
        ]),
      ],
    );
    final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
      appApiClient: appApiClient,
    );
    final CloudBaseAssistantReplyGateway gateway =
        CloudBaseAssistantReplyGateway(
          appApiClient: appApiClient,
          snapshotStore: snapshotStore,
        );

    final List<AssistantStreamEvent> events = await gateway
        .streamReply(
          prompt: '帮我规划今晚',
          threadId: 'thread-1',
          clientUserMessageId: 'user-1',
          clientAssistantMessageId: 'assistant-1',
          dorm: _testDorm(),
        )
        .toList();

    expect(
      events.map((AssistantStreamEvent event) => event.type),
      containsAll(<AssistantStreamEventType>[
        AssistantStreamEventType.planningStarted,
        AssistantStreamEventType.toolCompleted,
        AssistantStreamEventType.memoryUpdated,
        AssistantStreamEventType.agentDone,
      ]),
    );
    expect(
      events
          .where(
            (AssistantStreamEvent event) =>
                event.type == AssistantStreamEventType.toolCompleted,
          )
          .single
          .updatedSurfaces,
      containsAll(<String>['home_pre_sleep', 'agent_tool_plan_generate_tonight']),
    );
  });

  test(
    'cloudbase assistant reply gateway does not retry after reply delta has started',
    () async {
      final _FakeStreamCloudBaseAppApiClient
      appApiClient = _FakeStreamCloudBaseAppApiClient(
        postSseBehaviors: <Future<Stream<CloudBaseSseFrame>> Function()>[
          () async {
            final StreamController<CloudBaseSseFrame> controller =
                StreamController<CloudBaseSseFrame>();
            scheduleMicrotask(() async {
              controller.add(const CloudBaseSseFrame(event: 'ack', data: '{}'));
              controller.add(
                const CloudBaseSseFrame(
                  event: 'message_delta',
                  data: '{"delta":"你"}',
                ),
              );
              controller.addError(StateError('aborted after delta'));
              await controller.close();
            });
            return controller.stream;
          },
          () async =>
              Stream<CloudBaseSseFrame>.fromIterable(const <CloudBaseSseFrame>[
                CloudBaseSseFrame(
                  event: 'message_completed',
                  data: '{"reply":"不应被重试"}',
                ),
              ]),
        ],
      );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAssistantReplyGateway gateway =
          CloudBaseAssistantReplyGateway(
            appApiClient: appApiClient,
            snapshotStore: snapshotStore,
          );

      await expectLater(
        gateway
            .streamReply(
              prompt: '你好',
              threadId: 'thread-1',
              clientUserMessageId: 'user-1',
              clientAssistantMessageId: 'assistant-1',
              dorm: _testDorm(),
            )
            .toList(),
        throwsA(isA<StateError>()),
      );
      expect(appApiClient.postSseCallCount, 1);
    },
  );

  test(
    'cloudbase assistant reply gateway surfaces THREAD_TURN_BUSY error code',
    () async {
      final _FakeStreamCloudBaseAppApiClient
      appApiClient = _FakeStreamCloudBaseAppApiClient(
        postSseBehaviors: <Future<Stream<CloudBaseSseFrame>> Function()>[
          () async => Stream<CloudBaseSseFrame>.fromIterable(const <
            CloudBaseSseFrame
          >[
            CloudBaseSseFrame(
              event: 'error',
              data:
                  '{"code":"THREAD_TURN_BUSY","message":"This assistant thread is already processing another turn."}',
            ),
          ]),
        ],
      );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAssistantReplyGateway gateway =
          CloudBaseAssistantReplyGateway(
            appApiClient: appApiClient,
            snapshotStore: snapshotStore,
          );

      final List<AssistantStreamEvent> events = await gateway
          .streamReply(
            prompt: 'hi',
            threadId: 'thread-1',
            clientUserMessageId: 'user-1',
            clientAssistantMessageId: 'assistant-1',
            dorm: _testDorm(),
          )
          .toList();

      expect(events.single.type, AssistantStreamEventType.error);
      expect(events.single.errorCode, 'THREAD_TURN_BUSY');
    },
  );

  test(
    'cloudbase assistant reply gateway preserves ASSISTANT_REPLY_TIMEOUT in generateReply results',
    () async {
      final _FakeStreamCloudBaseAppApiClient
      appApiClient = _FakeStreamCloudBaseAppApiClient(
        postSseBehaviors: <Future<Stream<CloudBaseSseFrame>> Function()>[
          () async => Stream<CloudBaseSseFrame>.fromIterable(const <
            CloudBaseSseFrame
          >[
            CloudBaseSseFrame(event: 'ack', data: '{}'),
            CloudBaseSseFrame(
              event: 'error',
              data:
                  '{"code":"ASSISTANT_REPLY_TIMEOUT","message":"Assistant reply timed out before completion. Please try again."}',
            ),
          ]),
        ],
      );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAssistantReplyGateway gateway =
          CloudBaseAssistantReplyGateway(
            appApiClient: appApiClient,
            snapshotStore: snapshotStore,
          );

      final AssistantReplyResult result = await gateway.generateReply(
        prompt: 'hi',
        threadId: 'thread-1',
        clientUserMessageId: 'user-1',
        clientAssistantMessageId: 'assistant-1',
        dorm: _testDorm(),
      );

      expect(result.sourceMode, AssistantReplySourceMode.error);
      expect(result.errorCode, assistantReplyTimeoutCode);
      expect(result.reply, '这次回复超时了，请重试。');
      expect(
        result.errorMessage,
        'Assistant reply timed out before completion. Please try again.',
      );
    },
  );

  test(
    'cloudbase assistant reply gateway synthesizes done when stream closes after message_completed',
    () async {
      final _FakeStreamCloudBaseAppApiClient
      appApiClient = _FakeStreamCloudBaseAppApiClient(
        postSseBehaviors: <Future<Stream<CloudBaseSseFrame>> Function()>[
          () async => Stream<CloudBaseSseFrame>.fromIterable(const <
            CloudBaseSseFrame
          >[
            CloudBaseSseFrame(event: 'ack', data: '{}'),
            CloudBaseSseFrame(
              event: 'message_completed',
              data:
                  '{"reply":"hello","sourceMode":"remoteSuccess","assistantMessageId":"assistant-1","runId":"run-1"}',
            ),
          ]),
        ],
      );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAssistantReplyGateway gateway =
          CloudBaseAssistantReplyGateway(
            appApiClient: appApiClient,
            snapshotStore: snapshotStore,
          );

      final List<AssistantStreamEvent> events = await gateway
          .streamReply(
            prompt: 'hello',
            threadId: 'thread-1',
            clientUserMessageId: 'user-1',
            clientAssistantMessageId: 'assistant-1',
            dorm: _testDorm(),
          )
          .toList();

      expect(
        events.map((AssistantStreamEvent event) => event.type).toList(),
        <AssistantStreamEventType>[
          AssistantStreamEventType.ack,
          AssistantStreamEventType.messageCompleted,
          AssistantStreamEventType.done,
        ],
      );
      expect(events.last.runId, 'run-1');
      expect(events.last.backgroundSyncPending, isTrue);
    },
  );

  test(
    'cloudbase assistant reply gateway schedules background reconcile from done metadata',
    () async {
      final _FakeStreamCloudBaseAppApiClient
      appApiClient = _FakeStreamCloudBaseAppApiClient(
        postSseBehaviors: <Future<Stream<CloudBaseSseFrame>> Function()>[
          () async => Stream<CloudBaseSseFrame>.fromIterable(const <
            CloudBaseSseFrame
          >[
            CloudBaseSseFrame(event: 'ack', data: '{}'),
            CloudBaseSseFrame(
              event: 'message_completed',
              data:
                  '{"reply":"hello","sourceMode":"remoteSuccess","assistantMessageId":"assistant-1"}',
            ),
            CloudBaseSseFrame(
              event: 'done',
              data:
                  '{"assistantMessageId":"assistant-1","backgroundSyncPending":true,"reconcileAfterMs":1}',
            ),
          ]),
        ],
      );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAssistantReplyGateway gateway =
          CloudBaseAssistantReplyGateway(
            appApiClient: appApiClient,
            snapshotStore: snapshotStore,
          );

      await gateway
          .streamReply(
            prompt: 'hello',
            threadId: 'thread-1',
            clientUserMessageId: 'user-1',
            clientAssistantMessageId: 'assistant-1',
            dorm: _testDorm(),
          )
          .toList();

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(appApiClient.bootstrapCallCount, greaterThanOrEqualTo(1));
    },
  );

  test(
    'cloudbase assistant reply gateway returns error when stream ends before reply completes',
    () async {
      final _FakeStreamCloudBaseAppApiClient appApiClient =
          _FakeStreamCloudBaseAppApiClient(
            postSseBehaviors: <Future<Stream<CloudBaseSseFrame>> Function()>[
              () async => Stream<CloudBaseSseFrame>.fromIterable(
                const <CloudBaseSseFrame>[
                  CloudBaseSseFrame(event: 'ack', data: '{}'),
                ],
              ),
            ],
          );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAssistantReplyGateway gateway =
          CloudBaseAssistantReplyGateway(
            appApiClient: appApiClient,
            snapshotStore: snapshotStore,
          );

      final AssistantReplyResult result = await gateway.generateReply(
        prompt: 'hello',
        threadId: 'thread-1',
        clientUserMessageId: 'user-1',
        clientAssistantMessageId: 'assistant-1',
        dorm: _testDorm(),
      );

      expect(result.sourceMode, AssistantReplySourceMode.error);
      expect(result.errorMessage, 'reply stream ended before completion');
    },
  );
}

class _FakeStreamCloudBaseAppApiClient extends CloudBaseAppApiClient {
  _FakeStreamCloudBaseAppApiClient({required this.postSseBehaviors})
    : super(
        environment: const AppEnvironment(
          target: AppBackendTarget.production,
          appIdPrefix: 'com.dormsleep.app',
          cloudbaseEnvId: 'demo-env',
          cloudbaseAuthBaseUrl: 'https://example.com',
          cloudbaseAppApiBaseUrl: 'https://example.com',
          cloudbasePublishableKey: 'publishable-key',
          cloudbaseClientId: 'demo-env',
        ),
        sessionStore: _FakeSessionStore(),
        authClient: CloudBaseAuthClient(
          environment: const AppEnvironment(
            target: AppBackendTarget.production,
            appIdPrefix: 'com.dormsleep.app',
            cloudbaseEnvId: 'demo-env',
            cloudbaseAuthBaseUrl: 'https://example.com',
            cloudbaseAppApiBaseUrl: 'https://example.com',
            cloudbasePublishableKey: 'publishable-key',
            cloudbaseClientId: 'demo-env',
          ),
        ),
      );

  final List<Future<Stream<CloudBaseSseFrame>> Function()> postSseBehaviors;
  int postSseCallCount = 0;
  int bootstrapCallCount = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<Map<String, dynamic>> bootstrap() async {
    bootstrapCallCount += 1;
    return const <String, dynamic>{'data': <String, dynamic>{}};
  }

  @override
  Future<Stream<CloudBaseSseFrame>> postSse(
    String path, {
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    expect(path, '/api/agent/run/stream');
    postSseCallCount += 1;
    return postSseBehaviors[postSseCallCount - 1]();
  }
}

class _FakeSessionStore extends CloudBaseSessionStore {
  @override
  Future<CloudBaseSession?> readSession() async {
    return CloudBaseSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      subject: 'cloud-user',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      deviceId: 'device-1',
    );
  }

  @override
  Future<void> writeSession(CloudBaseSession session) async {}
}

Dorm _testDorm() {
  return const Dorm(
    id: 'dorm-1',
    name: 'Dorm 1',
    overview: 'quiet',
    noiseDb: 28,
    lightLabel: 'Dim',
    quietLabel: 'Stable',
    rules: <DormRule>[],
    members: <DormMember>[],
  );
}
