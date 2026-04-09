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
