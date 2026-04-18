import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import http from "node:http";
import test from "node:test";
import { createAppApiServer, normalizeCloudBasePhoneNumber } from "../src/http/app_api";

test("normalizeCloudBasePhoneNumber adds +86 for mainland China numbers", () => {
  assert.equal(normalizeCloudBasePhoneNumber("13800138000"), "+86 13800138000");
});

test("normalizeCloudBasePhoneNumber preserves normalized numbers", () => {
  assert.equal(
    normalizeCloudBasePhoneNumber("+86 13800138000"),
    "+86 13800138000",
  );
});

test("normalizeCloudBasePhoneNumber normalizes explicit country code separators", () => {
  assert.equal(
    normalizeCloudBasePhoneNumber("+86-13800138000"),
    "+86 13800138000",
  );
});

async function withLocalAppApiServer<T>(
  run: (params: { baseUrl: string; uid: string }) => Promise<T>,
): Promise<T> {
  const originalEnv = {
    AI_PROVIDER_MODE: process.env.AI_PROVIDER_MODE,
    AI_PROVIDER_BASE_URL: process.env.AI_PROVIDER_BASE_URL,
    AI_PROVIDER_API_KEY: process.env.AI_PROVIDER_API_KEY,
    AI_PROVIDER_MODEL: process.env.AI_PROVIDER_MODEL,
    CLOUDBASE_ENV_ID: process.env.CLOUDBASE_ENV_ID,
    TCB_ENV: process.env.TCB_ENV,
    SCF_NAMESPACE: process.env.SCF_NAMESPACE,
    CLOUDBASE_AUTH_BASE_URL: process.env.CLOUDBASE_AUTH_BASE_URL,
    LOCAL_DEBUG_UID: process.env.LOCAL_DEBUG_UID,
  };

  process.env.AI_PROVIDER_MODE = "deterministic";
  delete process.env.AI_PROVIDER_BASE_URL;
  delete process.env.AI_PROVIDER_API_KEY;
  delete process.env.AI_PROVIDER_MODEL;
  delete process.env.CLOUDBASE_ENV_ID;
  delete process.env.TCB_ENV;
  delete process.env.SCF_NAMESPACE;
  if (originalEnv.CLOUDBASE_AUTH_BASE_URL === undefined) {
    delete process.env.CLOUDBASE_AUTH_BASE_URL;
  }

  const uid = `app-api-test-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  process.env.LOCAL_DEBUG_UID = uid;

  const app = createAppApiServer();
  const server = await new Promise<import("node:http").Server>((resolve) => {
    const next = app.listen(0, () => resolve(next));
  });
  const address = server.address() as AddressInfo;

  try {
    return await run({
      baseUrl: `http://127.0.0.1:${address.port}`,
      uid,
    });
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
    for (const [key, value] of Object.entries(originalEnv)) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  }
}

test(
  "assistant reply reuses client ids and persists provider metadata in bootstrap payload",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const threadId = `${uid}-thread`;
      const clientUserMessageId = `${uid}-user-msg`;
      const clientAssistantMessageId = `${uid}-assistant-msg`;

      const replyResponse = await fetch(`${baseUrl}/api/assistant/reply`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          threadId,
          prompt: "宿舍有点吵，今晚怎么办？",
          clientUserMessageId,
          clientAssistantMessageId,
        }),
      });

      assert.equal(replyResponse.status, 200);
      const replyPayload = await replyResponse.json();
      assert.equal(replyPayload.assistantMessageId, clientAssistantMessageId);
      assert.equal(replyPayload.provider, "deterministic");
      assert.equal(replyPayload.model, "rules-v1");
      assert.equal(replyPayload.sourceMode, "fallbackSuccess");
      assert.equal(replyPayload.errorMessage, null);

      const bootstrapResponse = await fetch(`${baseUrl}/api/app/bootstrap`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({}),
      });

      assert.equal(bootstrapResponse.status, 200);
      const bootstrapPayload = await bootstrapResponse.json();
      const threadMessages =
        bootstrapPayload.data.assistantMessages[threadId] ?? [];
      const assistantMessage = threadMessages.find(
        (item: Record<string, unknown>) => item.id === clientAssistantMessageId,
      );

      assert.ok(assistantMessage);
      assert.equal(assistantMessage.sourceMode, "fallbackSuccess");
      assert.equal(assistantMessage.provider, "deterministic");
      assert.equal(assistantMessage.model, "rules-v1");
      assert.equal(assistantMessage.errorMessage, undefined);
    });
  },
);

test(
  "legacy phone auth endpoints stay disabled",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      for (const path of [
        "/api/auth/recover-phone-account",
        "/api/auth/link-phone",
      ]) {
        const response = await fetch(`${baseUrl}${path}`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-debug-uid": uid,
          },
          body: JSON.stringify({}),
        });
        const payload = await response.json();

        assert.equal(response.status, 410);
        assert.equal(payload.code, "LEGACY_DISABLED");
      }
    });
  },
);

test(
  "bootstrap repairs phone number from the current access token when profile phone is empty",
  { concurrency: false },
  async () => {
    const originalAuthBase = process.env.CLOUDBASE_AUTH_BASE_URL;
    let expectedUid = "phone-user-1";
    const authServer = await new Promise<http.Server>((resolve) => {
      const server = http.createServer((request, response) => {
        if (request.url === "/auth/v1/user/me") {
          response.writeHead(200, { "content-type": "application/json" });
          response.end(
            JSON.stringify({
              sub: expectedUid,
              phone_number: "+86 13800138000",
            }),
          );
          return;
        }
        response.writeHead(404).end();
      });
      server.listen(0, () => resolve(server));
    });
    const authAddress = authServer.address() as AddressInfo;
    process.env.CLOUDBASE_AUTH_BASE_URL = `http://127.0.0.1:${authAddress.port}`;

    try {
      await withLocalAppApiServer(async ({ baseUrl, uid }) => {
        expectedUid = uid;
        const payload = Buffer.from(
          JSON.stringify({ sub: uid }),
          "utf8",
        ).toString("base64url");
        const token = `header.${payload}.signature`;

        const bootstrapResponse = await fetch(`${baseUrl}/api/app/bootstrap`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({}),
        });

        assert.equal(bootstrapResponse.status, 200);
        const bootstrapPayload = await bootstrapResponse.json();
        assert.equal(
          bootstrapPayload.data.user.phoneNumber,
          "+86 13800138000",
        );
      });
    } finally {
      await new Promise<void>((resolve, reject) => {
        authServer.close((error) => (error ? reject(error) : resolve()));
      });
      if (originalAuthBase === undefined) {
        delete process.env.CLOUDBASE_AUTH_BASE_URL;
      } else {
        process.env.CLOUDBASE_AUTH_BASE_URL = originalAuthBase;
      }
    }
  },
);

test(
  "bootstrap rejects bearer tokens that CloudBase auth can no longer verify",
  { concurrency: false },
  async () => {
    const originalAuthBase = process.env.CLOUDBASE_AUTH_BASE_URL;
    const authServer = await new Promise<http.Server>((resolve) => {
      const server = http.createServer((_request, response) => {
        response.writeHead(401, { "content-type": "application/json" });
        response.end(
          JSON.stringify({
            error: "unauthorized",
            error_description: "token invalid",
          }),
        );
      });
      server.listen(0, () => resolve(server));
    });
    const authAddress = authServer.address() as AddressInfo;
    process.env.CLOUDBASE_AUTH_BASE_URL = `http://127.0.0.1:${authAddress.port}`;

    try {
      await withLocalAppApiServer(async ({ baseUrl, uid }) => {
        const payload = Buffer.from(
          JSON.stringify({ sub: uid }),
          "utf8",
        ).toString("base64url");
        const token = `header.${payload}.signature`;

        const bootstrapResponse = await fetch(`${baseUrl}/api/app/bootstrap`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({}),
        });

        assert.equal(bootstrapResponse.status, 400);
        const bootstrapPayload = await bootstrapResponse.json();
        assert.equal(
          bootstrapPayload.message,
          "CloudBase auth verification failed with 401.",
        );
      });
    } finally {
      await new Promise<void>((resolve, reject) => {
        authServer.close((error) => (error ? reject(error) : resolve()));
      });
      if (originalAuthBase === undefined) {
        delete process.env.CLOUDBASE_AUTH_BASE_URL;
      } else {
        process.env.CLOUDBASE_AUTH_BASE_URL = originalAuthBase;
      }
    }
  },
);

test(
  "assistant identity prompt returns truthful provider and model information",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const replyResponse = await fetch(`${baseUrl}/api/assistant/reply`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          threadId: `${uid}-thread`,
          prompt: "你是什么模型？",
          clientUserMessageId: `${uid}-user-msg`,
          clientAssistantMessageId: `${uid}-assistant-msg`,
        }),
      });

      assert.equal(replyResponse.status, 200);
      const replyPayload = await replyResponse.json();
      assert.equal(replyPayload.sourceMode, "fallbackSuccess");
      assert.equal(replyPayload.provider, "deterministic");
      assert.equal(replyPayload.model, "rules-v1");
      assert.match(replyPayload.reply, /deterministic/i);
      assert.match(replyPayload.reply, /rules-v1/i);
    });
  },
);

test(
  "assistant capture persists structured sleep capture records in bootstrap payload",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const threadId = `${uid}-capture-thread`;
      const clientUserMessageId = `${uid}-capture-user`;
      const clientAssistantMessageId = `${uid}-capture-assistant`;
      const captureResponse = await fetch(`${baseUrl}/api/assistant/capture`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          threadId,
          sessionId: `${uid}-session-1`,
          captureType: "dream",
          prompt: "我梦见自己在很高的桥上往下看。",
          clientUserMessageId,
          clientAssistantMessageId,
        }),
      });

      assert.equal(captureResponse.status, 200);
      const capturePayload = await captureResponse.json();
      assert.equal(capturePayload.assistantMessageId, clientAssistantMessageId);
      assert.equal(capturePayload.provider, "deterministic");
      assert.equal(capturePayload.model, "rules-v1");
      assert.equal(capturePayload.record.type, "dream");
      assert.equal(capturePayload.record.sessionId, `${uid}-session-1`);
      assert.match(capturePayload.record.title, /梦记|姊﹁/i);

      const bootstrapResponse = await fetch(`${baseUrl}/api/app/bootstrap`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({}),
      });

      assert.equal(bootstrapResponse.status, 200);
      const bootstrapPayload = await bootstrapResponse.json();
      const records = bootstrapPayload.data.sleepCaptureRecords ?? [];
      assert.ok(
        records.some(
          (item: Record<string, unknown>) =>
            item.sessionId === `${uid}-session-1` && item.type === "dream",
        ),
      );
    });
  },
);

test(
  "sleep capture banner show and clear update bootstrap user state",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const saveResponse = await fetch(`${baseUrl}/api/sleep-capture/save`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          record: {
            id: `${uid}-memo-1`,
            type: "memo",
            sessionId: `${uid}-session-2`,
            createdAt: "2026-04-09T12:00:00.000Z",
            title: "事记 12:00",
            outline: "AI整理后的事记",
            content: "记得明早给导师发材料",
          },
        }),
      });
      assert.equal(saveResponse.status, 200);

      const showResponse = await fetch(
        `${baseUrl}/api/sleep-capture/banner/show`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-debug-uid": uid,
          },
          body: JSON.stringify({ sessionId: `${uid}-session-2` }),
        },
      );
      assert.equal(showResponse.status, 200);
      const showPayload = await showResponse.json();
      assert.equal(showPayload.pendingMemoBanner.groups[0].sessionId, `${uid}-session-2`);

      const bootstrapWithBanner = await fetch(`${baseUrl}/api/app/bootstrap`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({}),
      });
      const bootstrapWithBannerPayload = await bootstrapWithBanner.json();
      assert.equal(
        bootstrapWithBannerPayload.data.userState.sleepCapture.pendingMemoBanner.groups[0].sessionId,
        `${uid}-session-2`,
      );

      const clearResponse = await fetch(
        `${baseUrl}/api/sleep-capture/banner/clear`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-debug-uid": uid,
          },
          body: JSON.stringify({}),
        },
      );
      assert.equal(clearResponse.status, 200);

      const bootstrapAfterClear = await fetch(`${baseUrl}/api/app/bootstrap`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({}),
      });
      const bootstrapAfterClearPayload = await bootstrapAfterClear.json();
      assert.equal(
        bootstrapAfterClearPayload.data.userState.sleepCapture.pendingMemoBanner,
        null,
      );
    });
  },
);

test(
  "morning feedback upserts a completed sleep session when the remote session does not exist",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const sessionId = `${uid}-feedback-upsert`;
      const response = await fetch(`${baseUrl}/api/feedback/morning`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          sessionId,
          session: {
            id: sessionId,
            startedAt: "2026-04-17T21:00:00.000Z",
            endedAt: "2026-04-18T07:00:00.000Z",
            sleepDayKey: "2026-04-18",
            status: "awaitingFeedback",
            sleepModeActive: false,
            dormId: "dorm-204",
            recommendations: [],
            selectedRecommendationIds: ["rec-1"],
            segments: [
              {
                startedAt: "2026-04-17T21:00:00.000Z",
                endedAt: "2026-04-18T01:30:00.000Z",
              },
              {
                startedAt: "2026-04-18T02:00:00.000Z",
                endedAt: "2026-04-18T07:00:00.000Z",
              },
            ],
            trackedDurationMinutes: 450,
            awakenings: [
              {
                id: "awake-1",
                occurredAt: "2026-04-18T03:15:00.000Z",
                trigger: "noise",
                minutesToSleep: 5,
                note: "brief wake-up",
              },
            ],
          },
          summary: {
            sleepQuality: 4,
            restedLevel: 5,
            totalSleepHours: 7.1,
            awakeningsCount: 1,
            note: "upserted from feedback",
          },
          feedback: [
            {
              recommendationId: "rec-1",
              status: "effective",
              note: "worked well",
              submittedAt: "2026-04-18T07:05:00.000Z",
            },
          ],
        }),
      });

      assert.equal(response.status, 200);
      const payload = await response.json();
      assert.equal(payload.sessionId, sessionId);
      assert.equal(payload.status, "completed");

      const bootstrapResponse = await fetch(`${baseUrl}/api/app/bootstrap`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({}),
      });
      assert.equal(bootstrapResponse.status, 200);
      const bootstrapPayload = await bootstrapResponse.json();
      const sessions = bootstrapPayload.data.sleepSessions ?? [];
      const session = sessions.find(
        (item: Record<string, unknown>) => item.id === sessionId,
      );

      assert.ok(session);
      assert.equal(session.status, "completed");
      assert.equal(session.sleepDayKey, "2026-04-18");
      assert.equal(session.trackedDurationMinutes, 450);
      assert.equal(session.summary.totalSleepHours, 7.1);
      assert.equal(session.feedback.length, 1);
      assert.equal(session.feedback[0].recommendationId, "rec-1");
      assert.equal(session.awakenings.length, 1);
      assert.equal(session.selectedRecommendationIds[0], "rec-1");
    });
  },
);

test(
  "morning feedback keeps backward compatibility with recommendationFeedback payloads",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const sessionId = `${uid}-feedback-legacy`;
      const response = await fetch(`${baseUrl}/api/feedback/morning`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          sessionId,
          session: {
            id: sessionId,
            startedAt: "2026-04-17T22:30:00.000Z",
            endedAt: "2026-04-18T06:30:00.000Z",
            sleepDayKey: "2026-04-18",
            status: "awaitingFeedback",
            sleepModeActive: false,
            recommendations: [],
            selectedRecommendationIds: [],
            segments: [
              {
                startedAt: "2026-04-17T22:30:00.000Z",
                endedAt: "2026-04-18T06:30:00.000Z",
              },
            ],
            trackedDurationMinutes: 480,
            awakenings: [],
          },
          summary: {
            sleepQuality: 3,
            restedLevel: 3,
            totalSleepHours: 6.5,
            awakeningsCount: 0,
            note: "legacy feedback payload",
          },
          recommendationFeedback: [
            {
              recommendationId: "rec-legacy",
              status: "neutral",
              note: "legacy field still accepted",
              submittedAt: "2026-04-18T06:35:00.000Z",
            },
          ],
        }),
      });

      assert.equal(response.status, 200);

      const bootstrapResponse = await fetch(`${baseUrl}/api/app/bootstrap`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({}),
      });
      assert.equal(bootstrapResponse.status, 200);
      const bootstrapPayload = await bootstrapResponse.json();
      const sessions = bootstrapPayload.data.sleepSessions ?? [];
      const session = sessions.find(
        (item: Record<string, unknown>) => item.id === sessionId,
      );

      assert.ok(session);
      assert.equal(session.status, "completed");
      assert.equal(session.feedback.length, 1);
      assert.equal(session.feedback[0].recommendationId, "rec-legacy");
    });
  },
);

test(
  "sleep exit keeps closed segments and tracked duration in bootstrap payload",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const sessionId = `${uid}-sleep-exit`;
      const enterResponse = await fetch(`${baseUrl}/api/sleep/enter`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          session: {
            id: sessionId,
            startedAt: "2026-04-17T23:00:00.000Z",
            sleepDayKey: "2026-04-18",
            status: "active",
            sleepModeActive: true,
            dormId: "dorm-204",
            recommendations: [],
            selectedRecommendationIds: [],
            segments: [
              {
                startedAt: "2026-04-17T23:00:00.000Z",
                endedAt: null,
              },
            ],
            trackedDurationMinutes: 0,
            awakenings: [],
            feedback: [],
          },
        }),
      });
      assert.equal(enterResponse.status, 200);

      const exitEndedAt = "2026-04-18T06:45:00.000Z";
      const exitResponse = await fetch(`${baseUrl}/api/sleep/exit`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          sessionId,
          endedAt: exitEndedAt,
          trackedDurationMinutes: 465,
          session: {
            id: sessionId,
            sleepDayKey: "2026-04-18",
            segments: [
              {
                startedAt: "2026-04-17T23:00:00.000Z",
                endedAt: exitEndedAt,
              },
            ],
            trackedDurationMinutes: 465,
          },
        }),
      });
      assert.equal(exitResponse.status, 200);

      const bootstrapResponse = await fetch(`${baseUrl}/api/app/bootstrap`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({}),
      });
      assert.equal(bootstrapResponse.status, 200);

      const bootstrapPayload = await bootstrapResponse.json();
      const sessions = bootstrapPayload.data.sleepSessions ?? [];
      const session = sessions.find(
        (item: Record<string, unknown>) => item.id === sessionId,
      );

      assert.ok(session);
      assert.equal(session.status, "awaitingFeedback");
      assert.equal(session.sleepModeActive, false);
      assert.equal(session.endedAt, exitEndedAt);
      assert.equal(session.trackedDurationMinutes, 465);
      assert.equal(session.segments.length, 1);
      assert.equal(session.segments[0].endedAt, exitEndedAt);
    });
  },
);

test(
  "bootstrap derives sleepGoalMet for awaiting feedback and completed sessions only",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const awaitingSessionId = `${uid}-awaiting-goal`;
      const completedSessionId = `${uid}-completed-goal`;
      const activeSessionId = `${uid}-active-goal`;

      const saveSettingsResponse = await fetch(`${baseUrl}/api/profile/save`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          settings: {
            sleepGoalHours: 7.5,
          },
        }),
      });
      assert.equal(saveSettingsResponse.status, 200);

      const enterAwaiting = await fetch(`${baseUrl}/api/sleep/enter`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          session: {
            id: awaitingSessionId,
            startedAt: "2026-04-17T23:00:00.000Z",
            sleepDayKey: "2026-04-18",
            status: "active",
            sleepModeActive: true,
            recommendations: [],
            selectedRecommendationIds: [],
            segments: [
              {
                startedAt: "2026-04-17T23:00:00.000Z",
                endedAt: null,
              },
            ],
            trackedDurationMinutes: 0,
            awakenings: [],
            feedback: [],
          },
        }),
      });
      assert.equal(enterAwaiting.status, 200);

      const exitAwaiting = await fetch(`${baseUrl}/api/sleep/exit`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          sessionId: awaitingSessionId,
          endedAt: "2026-04-18T06:45:00.000Z",
          trackedDurationMinutes: 465,
          session: {
            id: awaitingSessionId,
            sleepDayKey: "2026-04-18",
            segments: [
              {
                startedAt: "2026-04-17T23:00:00.000Z",
                endedAt: "2026-04-18T06:45:00.000Z",
              },
            ],
            trackedDurationMinutes: 465,
          },
        }),
      });
      assert.equal(exitAwaiting.status, 200);

      const completedResponse = await fetch(`${baseUrl}/api/feedback/morning`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          sessionId: completedSessionId,
          session: {
            id: completedSessionId,
            startedAt: "2026-04-16T23:10:00.000Z",
            endedAt: "2026-04-17T07:00:00.000Z",
            sleepDayKey: "2026-04-17",
            status: "awaitingFeedback",
            sleepModeActive: false,
            dormId: "dorm-204",
            recommendations: [],
            selectedRecommendationIds: [],
            segments: [
              {
                startedAt: "2026-04-16T23:10:00.000Z",
                endedAt: "2026-04-17T07:00:00.000Z",
              },
            ],
            trackedDurationMinutes: 470,
            awakenings: [],
            feedback: [],
          },
          summary: {
            sleepQuality: 4,
            restedLevel: 4,
            totalSleepHours: 7.8,
            awakeningsCount: 0,
            note: "goal met",
          },
          feedback: [],
        }),
      });
      assert.equal(completedResponse.status, 200);

      const activeResponse = await fetch(`${baseUrl}/api/sleep/enter`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          session: {
            id: activeSessionId,
            startedAt: "2026-04-18T23:20:00.000Z",
            sleepDayKey: "2026-04-19",
            status: "active",
            sleepModeActive: true,
            recommendations: [],
            selectedRecommendationIds: [],
            segments: [
              {
                startedAt: "2026-04-18T23:20:00.000Z",
                endedAt: null,
              },
            ],
            trackedDurationMinutes: 0,
            awakenings: [],
            feedback: [],
          },
        }),
      });
      assert.equal(activeResponse.status, 200);

      const bootstrapResponse = await fetch(`${baseUrl}/api/app/bootstrap`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({}),
      });
      assert.equal(bootstrapResponse.status, 200);

      const bootstrapPayload = await bootstrapResponse.json();
      const sessions = bootstrapPayload.data.sleepSessions ?? [];
      const awaitingSession = sessions.find(
        (item: Record<string, unknown>) => item.id === awaitingSessionId,
      );
      const completedSession = sessions.find(
        (item: Record<string, unknown>) => item.id === completedSessionId,
      );
      const activeSession = sessions.find(
        (item: Record<string, unknown>) => item.id === activeSessionId,
      );

      assert.ok(awaitingSession);
      assert.ok(completedSession);
      assert.ok(activeSession);
      assert.equal(awaitingSession.sleepGoalMet, true);
      assert.equal(completedSession.sleepGoalMet, true);
      assert.equal(activeSession.sleepGoalMet ?? null, null);
    });
  },
);

test(
  "bootstrap recalculates sleepGoalMet when sleep goal changes",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const sessionId = `${uid}-goal-recalc`;

      const feedbackResponse = await fetch(`${baseUrl}/api/feedback/morning`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          sessionId,
          session: {
            id: sessionId,
            startedAt: "2026-04-15T23:00:00.000Z",
            endedAt: "2026-04-16T06:00:00.000Z",
            sleepDayKey: "2026-04-16",
            status: "awaitingFeedback",
            sleepModeActive: false,
            dormId: "dorm-204",
            recommendations: [],
            selectedRecommendationIds: [],
            segments: [
              {
                startedAt: "2026-04-15T23:00:00.000Z",
                endedAt: "2026-04-16T06:00:00.000Z",
              },
            ],
            trackedDurationMinutes: 420,
            awakenings: [],
            feedback: [],
          },
          summary: {
            sleepQuality: 3,
            restedLevel: 3,
            totalSleepHours: 7.0,
            awakeningsCount: 0,
            note: "goal recalc",
          },
          feedback: [],
        }),
      });
      assert.equal(feedbackResponse.status, 200);

      for (const [sleepGoalHours, expected] of [
        [7.5, false],
        [6.5, true],
      ] as const) {
        const saveSettingsResponse = await fetch(`${baseUrl}/api/profile/save`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-debug-uid": uid,
          },
          body: JSON.stringify({
            settings: {
              sleepGoalHours,
            },
          }),
        });
        assert.equal(saveSettingsResponse.status, 200);

        const bootstrapResponse = await fetch(`${baseUrl}/api/app/bootstrap`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-debug-uid": uid,
          },
          body: JSON.stringify({}),
        });
        assert.equal(bootstrapResponse.status, 200);
        const bootstrapPayload = await bootstrapResponse.json();
        const session = (bootstrapPayload.data.sleepSessions ?? []).find(
          (item: Record<string, unknown>) => item.id === sessionId,
        );

        assert.ok(session);
        assert.equal(session.sleepGoalMet, expected);
      }
    });
  },
);

test(
  "dorm location anchor and tonight interference persist through bootstrap",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const createResponse = await fetch(`${baseUrl}/api/dorm/create`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          name: "梅苑 204",
          locationAnchor: {
            latitude: 30.1234,
            longitude: 120.5678,
            radiusMeters: 100,
            recordedAt: "2026-04-12T12:00:00.000Z",
            recordedByUid: uid,
          },
        }),
      });
      assert.equal(createResponse.status, 200);

      const environmentResponse = await fetch(`${baseUrl}/api/dorm/environment`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          noiseDb: 43,
          lightLabel: "偏亮",
        }),
      });
      assert.equal(environmentResponse.status, 200);

      const interferenceResponse = await fetch(
        `${baseUrl}/api/interference/tonight`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-debug-uid": uid,
          },
          body: JSON.stringify({
            noise: {
              type: "noise",
              title: "宿舍噪声",
              value: "43 dB",
              gradeLabel: "轻微",
              status: "ready",
              detail: "当前宿舍还有一点生活声，但整体还可以接受。",
              source: "microphone",
              measuredAt: "2026-04-12T12:05:00.000Z",
              numericValue: 43,
              score: 36,
            },
            phoneUsage: {
              type: "phoneUsage",
              title: "手机使用",
              value: "22 分钟",
              gradeLabel: "适中",
              status: "ready",
              detail: "最近 2 小时手机使用还算克制。",
              source: "android_usage_stats",
              measuredAt: "2026-04-12T12:05:00.000Z",
              numericValue: 22,
              score: 34,
            },
          }),
        },
      );
      assert.equal(interferenceResponse.status, 200);

      const bootstrapResponse = await fetch(`${baseUrl}/api/app/bootstrap`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({}),
      });
      assert.equal(bootstrapResponse.status, 200);

      const bootstrapPayload = await bootstrapResponse.json();
      assert.equal(bootstrapPayload.data.dorm.locationAnchor.latitude, 30.1234);
      assert.equal(bootstrapPayload.data.dorm.lightLabel, "偏亮");
      assert.equal(
        bootstrapPayload.data.userState.tonightInterference.noise.value,
        "43 dB",
      );
      assert.equal(
        bootstrapPayload.data.userState.tonightInterference.phoneUsage.value,
        "22 分钟",
      );
    });
  },
);

test(
  "audio catalog falls back to env configured urls when collection is empty",
  { concurrency: false },
  async () => {
    const originalDeepOceanUrl = process.env.SLEEP_AUDIO_DEEP_OCEAN_URL;
    process.env.SLEEP_AUDIO_DEEP_OCEAN_URL =
      "https://example.com/audio/deep-ocean.mp3";

    try {
      await withLocalAppApiServer(async ({ baseUrl, uid }) => {
        const response = await fetch(`${baseUrl}/api/media/audio-catalog`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-debug-uid": uid,
          },
          body: JSON.stringify({}),
        });

        assert.equal(response.status, 200);
        const payload = await response.json();
        assert.ok(Array.isArray(payload.tracks));
        assert.ok(payload.tracks.length >= 1);
        assert.equal(payload.tracks[0].id, "deep-ocean");
        assert.equal(
          payload.tracks[0].sourceUrl,
          "https://example.com/audio/deep-ocean.mp3",
        );
      });
    } finally {
      if (originalDeepOceanUrl === undefined) {
        delete process.env.SLEEP_AUDIO_DEEP_OCEAN_URL;
      } else {
        process.env.SLEEP_AUDIO_DEEP_OCEAN_URL = originalDeepOceanUrl;
      }
    }
  },
);
