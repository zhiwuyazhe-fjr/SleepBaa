import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import http from "node:http";
import test from "node:test";
import {
  createAppApiServer,
  normalizeCloudBasePhoneNumber,
} from "../src/http/app_api";
import { createRepositoryFromEnv } from "../src/repositories/firestore_repositories";

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
  envOverrides: Record<string, string | undefined> = {},
): Promise<T> {
  const originalEnv = {
    AI_PROVIDER_MODE: process.env.AI_PROVIDER_MODE,
    AI_PROVIDER_BASE_URL: process.env.AI_PROVIDER_BASE_URL,
    AI_PROVIDER_API_KEY: process.env.AI_PROVIDER_API_KEY,
    AI_PROVIDER_MODEL: process.env.AI_PROVIDER_MODEL,
    AI_PROVIDER_TIMEOUT_MS: process.env.AI_PROVIDER_TIMEOUT_MS,
    AI_PROVIDER_TIMEOUT_MS_REPLY: process.env.AI_PROVIDER_TIMEOUT_MS_REPLY,
    AI_PROVIDER_TIMEOUT_MS_STRUCTURED:
      process.env.AI_PROVIDER_TIMEOUT_MS_STRUCTURED,
    CLOUDBASE_ENV_ID: process.env.CLOUDBASE_ENV_ID,
    TCB_ENV: process.env.TCB_ENV,
    SCF_NAMESPACE: process.env.SCF_NAMESPACE,
    CLOUDBASE_AUTH_BASE_URL: process.env.CLOUDBASE_AUTH_BASE_URL,
    LOCAL_DEBUG_UID: process.env.LOCAL_DEBUG_UID,
  };

  const uid = `app-api-test-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const nextEnv: Record<string, string | undefined> = {
    AI_PROVIDER_MODE: "deterministic",
    AI_PROVIDER_BASE_URL: undefined,
    AI_PROVIDER_API_KEY: undefined,
    AI_PROVIDER_MODEL: undefined,
    AI_PROVIDER_TIMEOUT_MS: undefined,
    AI_PROVIDER_TIMEOUT_MS_REPLY: undefined,
    AI_PROVIDER_TIMEOUT_MS_STRUCTURED: undefined,
    CLOUDBASE_ENV_ID: undefined,
    TCB_ENV: undefined,
    SCF_NAMESPACE: undefined,
    CLOUDBASE_AUTH_BASE_URL: originalEnv.CLOUDBASE_AUTH_BASE_URL,
    ...envOverrides,
    LOCAL_DEBUG_UID: uid,
  };
  for (const [key, value] of Object.entries(nextEnv)) {
    if (value === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = value;
    }
  }

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

function parseSseEvents(raw: string): Array<{
  event: string;
  data: Record<string, unknown>;
}> {
  return raw
    .split("\n\n")
    .map((chunk) => chunk.trim())
    .filter((chunk) => chunk.length > 0)
    .map((chunk) => {
      const eventLine = chunk
        .split("\n")
        .find((line) => line.startsWith("event:"));
      const dataLine = chunk
        .split("\n")
        .find((line) => line.startsWith("data:"));
      return {
        event: eventLine?.slice("event:".length).trim() ?? "",
        data: dataLine
          ? (JSON.parse(dataLine.slice("data:".length).trim()) as Record<
              string,
              unknown
            >)
          : {},
      };
    });
}

test(
  "profile save persists home quick action ids in bootstrap payload",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const selectedIds = [
        "profileSettings",
        "thoughtVault",
        "dreamJournal",
        "profileReport",
      ];
      const saveResponse = await fetch(`${baseUrl}/api/profile/save`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          settings: {
            homeQuickActionIds: [
              "profileSettings",
              "unknown",
              "thoughtVault",
              "profileSettings",
              "dreamJournal",
              "profileReport",
            ],
          },
        }),
      });

      assert.equal(saveResponse.status, 200);
      const savePayload = await saveResponse.json();
      assert.deepEqual(savePayload.settings.homeQuickActionIds, selectedIds);

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
      assert.deepEqual(
        bootstrapPayload.data.settings.homeQuickActionIds,
        selectedIds,
      );
    });
  },
);

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
        assert.equal(bootstrapPayload.data.user.phoneNumber, "+86 13800138000");
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
  "assistant identity prompt does not reveal provider or model information",
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
      assert.match(replyPayload.reply, /小眠/);
      assert.doesNotMatch(
        replyPayload.reply,
        /deterministic|rules-v1|provider|model|模型|gpt|openai|claude|deepseek|hunyuan|混元|后台|接口/i,
      );
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
      assert.equal(
        showPayload.pendingMemoBanner.groups[0].sessionId,
        `${uid}-session-2`,
      );

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
        bootstrapWithBannerPayload.data.userState.sleepCapture.pendingMemoBanner
          .groups[0].sessionId,
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
        bootstrapAfterClearPayload.data.userState.sleepCapture
          .pendingMemoBanner,
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
  "sleep enter pause and exit synchronize dorm sleep mode",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const headers = {
        "content-type": "application/json",
        "x-debug-uid": uid,
      };
      const createResponse = await fetch(`${baseUrl}/api/dorm/create`, {
        method: "POST",
        headers,
        body: JSON.stringify({ name: "Dorm" }),
      });
      assert.equal(createResponse.status, 200);

      const currentDormMember = async (): Promise<Record<string, unknown>> => {
        const bootstrapResponse = await fetch(`${baseUrl}/api/app/bootstrap`, {
          method: "POST",
          headers,
          body: JSON.stringify({}),
        });
        assert.equal(bootstrapResponse.status, 200);
        const bootstrapPayload = await bootstrapResponse.json();
        const member = bootstrapPayload.data.dorm.members.find(
          (item: Record<string, unknown>) => item.uid === uid,
        );
        assert.ok(member);
        return member;
      };

      const memberSleepMode = async (): Promise<boolean> => {
        const member = await currentDormMember();
        return Boolean(member.sleepModeActive);
      };

      const firstSessionId = `${uid}-sleep-sync-pause`;
      const enterPauseResponse = await fetch(`${baseUrl}/api/sleep/enter`, {
        method: "POST",
        headers,
        body: JSON.stringify({
          session: {
            id: firstSessionId,
            startedAt: "2026-04-17T23:00:00.000Z",
            sleepDayKey: "2026-04-18",
            status: "active",
            sleepModeActive: true,
            recommendations: [],
            selectedRecommendationIds: [],
            segments: [],
            trackedDurationMinutes: 0,
            awakenings: [],
            feedback: [],
          },
        }),
      });
      assert.equal(enterPauseResponse.status, 200);
      assert.equal(await memberSleepMode(), true);
      assert.equal((await currentDormMember()).status, "quiet");

      const pauseResponse = await fetch(`${baseUrl}/api/sleep/pause`, {
        method: "POST",
        headers,
        body: JSON.stringify({ sessionId: firstSessionId }),
      });
      assert.equal(pauseResponse.status, 200);
      assert.equal(await memberSleepMode(), false);
      assert.equal((await currentDormMember()).status, "quiet");

      const secondSessionId = `${uid}-sleep-sync-exit`;
      const enterExitResponse = await fetch(`${baseUrl}/api/sleep/enter`, {
        method: "POST",
        headers,
        body: JSON.stringify({
          session: {
            id: secondSessionId,
            startedAt: "2026-04-18T23:00:00.000Z",
            sleepDayKey: "2026-04-19",
            status: "active",
            sleepModeActive: true,
            recommendations: [],
            selectedRecommendationIds: [],
            segments: [],
            trackedDurationMinutes: 0,
            awakenings: [],
            feedback: [],
          },
        }),
      });
      assert.equal(enterExitResponse.status, 200);
      assert.equal(await memberSleepMode(), true);
      assert.equal((await currentDormMember()).status, "quiet");

      const exitResponse = await fetch(`${baseUrl}/api/sleep/exit`, {
        method: "POST",
        headers,
        body: JSON.stringify({ sessionId: secondSessionId }),
      });
      assert.equal(exitResponse.status, 200);
      assert.equal(await memberSleepMode(), false);
      assert.equal((await currentDormMember()).status, "quiet");
    });
  },
);

test(
  "assistant reply stream emits ordered SSE events",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const response = await fetch(`${baseUrl}/api/assistant/reply/stream`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          threadId: `${uid}-stream-thread`,
          prompt: "宿舍有点吵，帮我想想今晚怎么稳住。",
          clientUserMessageId: `${uid}-stream-user`,
          clientAssistantMessageId: `${uid}-stream-assistant`,
        }),
      });

      assert.equal(response.status, 200);
      assert.match(
        response.headers.get("content-type") ?? "",
        /text\/event-stream/i,
      );

      const events = parseSseEvents(await response.text());
      assert.equal(events[0]?.event, "ack");
      assert.ok(events.some((item) => item.event === "message_delta"));
      assert.ok(events.some((item) => item.event === "message_completed"));
      assert.equal(events[events.length - 1]?.event, "done");
      assert.equal(events[events.length - 1]?.data.backgroundSyncPending, true);
    });
  },
);

test(
  "assistant reply stream releases the thread lease before delayed background postprocess completes",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const repo = createRepositoryFromEnv();
      const originalWriteUserState = repo.writeUserState.bind(repo);
      let unblockWriteUserState!: () => void;
      const writeUserStateBlocked = new Promise<void>((resolve) => {
        unblockWriteUserState = resolve;
      });
      let blockedOnce = false;
      let backgroundStarted = false;
      repo.writeUserState = (async (...args) => {
        if (!blockedOnce) {
          blockedOnce = true;
          backgroundStarted = true;
          await writeUserStateBlocked;
        }
        return originalWriteUserState(...args);
      }) as typeof repo.writeUserState;

      try {
        const threadId = `${uid}-reply-delay-thread`;
        const firstResponse = await fetch(
          `${baseUrl}/api/assistant/reply/stream`,
          {
            method: "POST",
            headers: {
              "content-type": "application/json",
              "x-debug-uid": uid,
            },
            body: JSON.stringify({
              threadId,
              prompt: "stay with me a bit",
              clientUserMessageId: `${uid}-delay-user-1`,
              clientAssistantMessageId: `${uid}-delay-assistant-1`,
            }),
          },
        );

        assert.equal(firstResponse.status, 200);
        const firstEvents = parseSseEvents(await firstResponse.text());
        assert.equal(firstEvents[0]?.event, "ack");
        assert.ok(
          firstEvents.some((item) => item.event === "message_completed"),
        );
        assert.ok(!firstEvents.some((item) => item.event === "surface_patch"));
        assert.ok(!firstEvents.some((item) => item.event === "memory_synced"));
        assert.equal(firstEvents[firstEvents.length - 1]?.event, "done");

        await new Promise<void>((resolve) => setTimeout(resolve, 0));
        assert.equal(backgroundStarted, true);

        const secondResponse = await fetch(
          `${baseUrl}/api/assistant/reply/stream`,
          {
            method: "POST",
            headers: {
              "content-type": "application/json",
              "x-debug-uid": uid,
            },
            body: JSON.stringify({
              threadId,
              prompt: "hi again",
              clientUserMessageId: `${uid}-delay-user-2`,
              clientAssistantMessageId: `${uid}-delay-assistant-2`,
            }),
          },
        );

        assert.equal(secondResponse.status, 200);
        const secondEvents = parseSseEvents(await secondResponse.text());
        assert.equal(secondEvents[0]?.event, "ack");
        assert.equal(secondEvents[secondEvents.length - 1]?.event, "done");
        assert.equal(
          secondEvents.some(
            (item) =>
              item.event === "error" && item.data.code === "THREAD_TURN_BUSY",
          ),
          false,
        );
      } finally {
        unblockWriteUserState();
        repo.writeUserState = originalWriteUserState;
      }
    });
  },
);

test(
  "assistant reply stream returns THREAD_TURN_BUSY when the thread lease is already held",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const repo = createRepositoryFromEnv();
      const threadId = `${uid}-busy-thread`;
      await repo.ensureAssistantThread(uid, threadId, "busy-thread");
      const acquired = await repo.tryAcquireAssistantThreadTurn({
        uid,
        threadId,
        turnId: `${threadId}-turn-1`,
        status: "streaming",
      });
      assert.equal(acquired, true);

      try {
        const response = await fetch(`${baseUrl}/api/assistant/reply/stream`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-debug-uid": uid,
          },
          body: JSON.stringify({
            threadId,
            prompt: "hi",
            clientUserMessageId: `${uid}-busy-user`,
            clientAssistantMessageId: `${uid}-busy-assistant`,
          }),
        });

        assert.equal(response.status, 200);
        const events = parseSseEvents(await response.text());
        assert.equal(events[0]?.event, "error");
        assert.equal(events[0]?.data.code, "THREAD_TURN_BUSY");
      } finally {
        await repo.releaseAssistantThreadTurn({
          uid,
          threadId,
          turnId: `${threadId}-turn-1`,
        });
      }
    });
  },
);

test(
  "assistant reply stream returns ASSISTANT_REPLY_TIMEOUT when the provider reply times out",
  { concurrency: false },
  async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = (async () => {
      throw new Error("TimeoutError: The operation was aborted due to timeout");
    }) as typeof fetch;

    try {
      await withLocalAppApiServer(
        async ({ baseUrl, uid }) => {
          const response = await originalFetch(
            `${baseUrl}/api/assistant/reply/stream`,
            {
              method: "POST",
              headers: {
                "content-type": "application/json",
                "x-debug-uid": uid,
              },
              body: JSON.stringify({
                threadId: `${uid}-timeout-thread`,
                prompt: "hi",
                clientUserMessageId: `${uid}-timeout-user`,
                clientAssistantMessageId: `${uid}-timeout-assistant`,
              }),
            },
          );

          assert.equal(response.status, 200);
          const events = parseSseEvents(await response.text());
          assert.equal(events[0]?.event, "ack");
          const errorEvent = events.find((item) => item.event === "error");
          assert.equal(errorEvent?.data.code, "ASSISTANT_REPLY_TIMEOUT");
          assert.equal(
            errorEvent?.data.message,
            "Assistant reply timed out before completion. Please try again.",
          );
        },
        {
          AI_PROVIDER_MODE: "cloudbase_ai",
          AI_PROVIDER_API_KEY: "test-key",
          AI_PROVIDER_GROUP: "openai-compatible-custom",
          AI_PROVIDER_BASE_URL: "https://example.com/replies",
          AI_PROVIDER_MODEL: "test-model",
          AI_PROVIDER_TIMEOUT_MS: "240000",
        },
      );
    } finally {
      globalThis.fetch = originalFetch;
    }
  },
);

test(
  "assistant reply stream still handles greetings without fast path rules",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const response = await fetch(`${baseUrl}/api/assistant/reply/stream`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          threadId: `${uid}-fast-path-thread`,
          prompt: "hi",
          clientUserMessageId: `${uid}-fast-path-user`,
          clientAssistantMessageId: `${uid}-fast-path-assistant`,
        }),
      });

      assert.equal(response.status, 200);
      const events = parseSseEvents(await response.text());
      assert.equal(events[0]?.event, "ack");
      assert.ok(events.some((item) => item.event === "message_delta"));
      assert.ok(events.some((item) => item.event === "message_completed"));
      assert.equal(events[events.length - 1]?.event, "done");

      const completed = events.find(
        (item) => item.event === "message_completed",
      );
      assert.notEqual(completed?.data.provider, "fast_path");
      assert.notEqual(completed?.data.model, "rules-fast-path");
      assert.equal(
        events.some((item) => item.event === "surface_patch"),
        false,
      );
    });
  },
);

test(
  "assistant capture stream emits capture_record and surface patch",
  { concurrency: false },
  async () => {
    await withLocalAppApiServer(async ({ baseUrl, uid }) => {
      const response = await fetch(`${baseUrl}/api/assistant/capture/stream`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-debug-uid": uid,
        },
        body: JSON.stringify({
          threadId: `${uid}-capture-stream-thread`,
          sessionId: `${uid}-capture-stream-session`,
          captureType: "memo",
          prompt: "记得明天早上给导师发材料。",
          clientUserMessageId: `${uid}-capture-stream-user`,
          clientAssistantMessageId: `${uid}-capture-stream-assistant`,
        }),
      });

      assert.equal(response.status, 200);
      const events = parseSseEvents(await response.text());
      assert.equal(events[0]?.event, "ack");
      assert.ok(events.some((item) => item.event === "message_delta"));
      assert.ok(events.some((item) => item.event === "message_completed"));
      assert.ok(events.some((item) => item.event === "surface_patch"));
      const captureEvent = events.find(
        (item) => item.event === "capture_record",
      );
      const record = (captureEvent?.data.record ?? {}) as Record<
        string,
        unknown
      >;
      assert.ok(captureEvent);
      assert.equal(record.type, "memo");
      assert.equal(record.sessionId, `${uid}-capture-stream-session`);
      assert.equal(events[events.length - 1]?.event, "done");
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
        const saveSettingsResponse = await fetch(
          `${baseUrl}/api/profile/save`,
          {
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
          },
        );
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

      const environmentResponse = await fetch(
        `${baseUrl}/api/dorm/environment`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-debug-uid": uid,
          },
          body: JSON.stringify({
            noiseDb: 43,
            lightLabel: "偏亮",
          }),
        },
      );
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
