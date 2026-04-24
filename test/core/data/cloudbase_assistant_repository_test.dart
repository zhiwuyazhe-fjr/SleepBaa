import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
import 'package:sleep_dorm_app/core/data/cloudbase_repositories.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

void main() {
  test(
    'cloudbase assistant repository keeps thread turn state until finish',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'assistant-user',
        ),
      );
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            bootstrapPayload: const <String, dynamic>{
              'data': <String, dynamic>{},
            },
            onPost: (String path, Map<String, dynamic> body) async {
              return <String, dynamic>{};
            },
          );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAssistantRepository repository =
          CloudBaseAssistantRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
          );

      final AssistantThread thread = repository.currentThread!;
      final bool started = await repository.tryStartThreadTurn(
        threadId: thread.id,
        turnId: 'turn-1',
      );

      expect(started, isTrue);
      expect(
        repository.turnStateForThread(thread.id)?.status,
        AssistantThreadTurnStatus.streaming,
      );
      expect(
        await repository.tryStartThreadTurn(
          threadId: thread.id,
          turnId: 'turn-2',
        ),
        isFalse,
      );

      await repository.markThreadTurnFinalizing(
        threadId: thread.id,
        turnId: 'turn-1',
      );
      expect(
        repository.turnStateForThread(thread.id)?.status,
        AssistantThreadTurnStatus.finalizing,
      );

      await repository.finishThreadTurn(threadId: thread.id, turnId: 'turn-1');
      expect(
        repository.turnStateForThread(thread.id)?.status,
        AssistantThreadTurnStatus.idle,
      );
    },
  );

  test(
    'cloudbase assistant repository keeps a newly created remote thread selected while snapshot is stale',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'assistant-user',
        ),
      );
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            bootstrapPayload: <String, dynamic>{
              'data': <String, dynamic>{
                'user': <String, dynamic>{'uid': 'assistant-user'},
                'assistantThreads': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'remote-old-thread',
                    'userId': 'assistant-user',
                    'title': '旧对话',
                    'createdAt': '2026-04-08T12:00:00.000Z',
                    'updatedAt': '2026-04-08T12:05:00.000Z',
                  },
                ],
                'assistantMessages': <String, dynamic>{
                  'remote-old-thread': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'old-message-1',
                      'threadId': 'remote-old-thread',
                      'role': 'assistant',
                      'content': '旧消息',
                      'createdAt': '2026-04-08T12:05:00.000Z',
                    },
                  ],
                },
                'userState': <String, dynamic>{
                  'latestThreadId': 'remote-old-thread',
                },
              },
            },
            onPost: (String path, Map<String, dynamic> body) async {
              expect(path, '/api/assistant/threads');
              expect(body['title'], '新建对话');
              return <String, dynamic>{
                'id': 'remote-new-thread',
                'userId': 'assistant-user',
                'title': '新建对话',
                'createdAt': '2026-04-09T12:00:00.000Z',
                'updatedAt': '2026-04-09T12:00:00.000Z',
              };
            },
          );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAssistantRepository repository =
          CloudBaseAssistantRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
          );

      final AssistantThread created = await repository.createThread(
        title: '新建对话',
      );

      expect(created.id, 'remote-new-thread');
      expect(repository.currentThread?.id, 'remote-new-thread');
      expect(
        repository.threads.any(
          (AssistantThread item) => item.id == 'remote-new-thread',
        ),
        isTrue,
      );
      expect(repository.messagesForThread('remote-new-thread'), isEmpty);

      final AssistantThread ensured = await repository.ensureThread();
      expect(ensured.id, 'remote-new-thread');
      expect(repository.currentThread?.id, 'remote-new-thread');
    },
  );

  test(
    'cloudbase assistant repository preserves local optimistic messages when bootstrap snapshot is stale',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'assistant-user',
        ),
      );
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            bootstrapPayload: <String, dynamic>{
              'data': <String, dynamic>{
                'user': <String, dynamic>{'uid': 'assistant-user'},
                'assistantThreads': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'thread-1',
                    'userId': 'assistant-user',
                    'title': '鏃у璇?',
                    'createdAt': '2026-04-08T12:00:00.000Z',
                    'updatedAt': '2026-04-08T12:05:00.000Z',
                  },
                ],
                'assistantMessages': <String, dynamic>{
                  'thread-1': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'remote-message-1',
                      'threadId': 'thread-1',
                      'role': 'assistant',
                      'content': '鏃ф秷鎭?',
                      'createdAt': '2026-04-08T12:05:00.000Z',
                    },
                  ],
                },
                'userState': <String, dynamic>{'latestThreadId': 'thread-1'},
              },
            },
            onPost: (String path, Map<String, dynamic> body) async {
              expect(path, isNotEmpty);
              expect(body, isEmpty);
              return <String, dynamic>{};
            },
          );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAssistantRepository repository =
          CloudBaseAssistantRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
          );

      await snapshotStore.refresh();
      await repository.setCurrentThread('thread-1');
      await repository.sendUserMessage(
        threadId: 'thread-1',
        content: 'local user message',
        messageId: 'local-user-1',
      );
      await repository.addAssistantMessage(
        threadId: 'thread-1',
        content: 'local assistant placeholder',
        messageId: 'local-assistant-1',
        status: AssistantMessageStatus.pending,
      );

      appApiClient.bootstrapPayload = <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'uid': 'assistant-user'},
          'assistantThreads': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'thread-1',
              'userId': 'assistant-user',
              'title': '鏃у璇?',
              'createdAt': '2026-04-08T12:00:00.000Z',
              'updatedAt': '2026-04-08T12:06:00.000Z',
            },
          ],
          'assistantMessages': <String, dynamic>{
            'thread-1': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'remote-message-1',
                'threadId': 'thread-1',
                'role': 'assistant',
                'content': '鏃ф秷鎭?',
                'createdAt': '2026-04-08T12:05:00.000Z',
              },
            ],
          },
          'userState': <String, dynamic>{'latestThreadId': 'thread-1'},
        },
      };

      await snapshotStore.refresh();

      final List<AssistantMessage> messages = repository.messagesForThread(
        'thread-1',
      );
      expect(messages.map((AssistantMessage item) => item.id), <String>[
        'remote-message-1',
        'local-user-1',
        'local-assistant-1',
      ]);
      expect(messages.last.status, AssistantMessageStatus.pending);
      expect(messages.last.content, 'local assistant placeholder');
    },
  );

  test(
    'cloudbase assistant repository keeps user message before assistant when stale snapshot only contains assistant reply',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'assistant-user',
        ),
      );
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            bootstrapPayload: <String, dynamic>{
              'data': <String, dynamic>{
                'user': <String, dynamic>{'uid': 'assistant-user'},
                'assistantThreads': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'thread-1',
                    'userId': 'assistant-user',
                    'title': '鏃у璇?',
                    'createdAt': '2026-04-08T12:00:00.000Z',
                    'updatedAt': '2026-04-08T12:05:00.000Z',
                  },
                ],
                'assistantMessages': <String, dynamic>{
                  'thread-1': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'history-1',
                      'threadId': 'thread-1',
                      'role': 'assistant',
                      'content': 'history',
                      'createdAt': '2026-04-08T12:05:00.000Z',
                    },
                  ],
                },
                'userState': <String, dynamic>{'latestThreadId': 'thread-1'},
              },
            },
            onPost: (String path, Map<String, dynamic> body) async {
              expect(path, isNotEmpty);
              expect(body, isEmpty);
              return <String, dynamic>{};
            },
          );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAssistantRepository repository =
          CloudBaseAssistantRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
          );

      await snapshotStore.refresh();
      await repository.setCurrentThread('thread-1');
      await repository.sendUserMessage(
        threadId: 'thread-1',
        content: 'my question',
        messageId: 'local-user-1',
      );
      await repository.addAssistantMessage(
        threadId: 'thread-1',
        content: 'placeholder',
        messageId: 'local-assistant-1',
        status: AssistantMessageStatus.pending,
      );

      appApiClient.bootstrapPayload = <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'uid': 'assistant-user'},
          'assistantThreads': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'thread-1',
              'userId': 'assistant-user',
              'title': '鏃у璇?',
              'createdAt': '2026-04-08T12:00:00.000Z',
              'updatedAt': '2026-04-08T12:06:00.000Z',
            },
          ],
          'assistantMessages': <String, dynamic>{
            'thread-1': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'history-1',
                'threadId': 'thread-1',
                'role': 'assistant',
                'content': 'history',
                'createdAt': '2026-04-08T12:05:00.000Z',
              },
              <String, dynamic>{
                'id': 'local-assistant-1',
                'threadId': 'thread-1',
                'role': 'assistant',
                'content': 'real reply',
                'createdAt': '2026-04-08T12:06:30.000Z',
                'status': 'complete',
              },
            ],
          },
          'userState': <String, dynamic>{'latestThreadId': 'thread-1'},
        },
      };

      await snapshotStore.refresh();

      final List<AssistantMessage> messages = repository.messagesForThread(
        'thread-1',
      );
      expect(
        messages.map((AssistantMessage item) => item.id).toList(),
        <String>['history-1', 'local-user-1', 'local-assistant-1'],
      );
      expect(messages[1].role, AssistantMessageRole.user);
      expect(messages[2].content, 'real reply');
    },
  );
}

class _FakeCloudBaseAppApiClient extends CloudBaseAppApiClient {
  _FakeCloudBaseAppApiClient({
    required this.bootstrapPayload,
    required this.onPost,
  }) : super(
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

  Map<String, dynamic> bootstrapPayload;
  final Future<Map<String, dynamic>> Function(
    String path,
    Map<String, dynamic> body,
  )
  onPost;

  @override
  bool get isConfigured => true;

  @override
  Future<Map<String, dynamic>> bootstrap() async => bootstrapPayload;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> body = const <String, dynamic>{},
  }) {
    return onPost(path, body);
  }
}

class _FakeSessionStore extends CloudBaseSessionStore {
  _FakeSessionStore();
}
