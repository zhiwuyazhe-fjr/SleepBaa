import assert from "node:assert/strict";
import test from "node:test";
import { DeterministicAIProvider } from "../src/providers/ai_provider";
import { createAIProviderFromEnv } from "../src/providers/provider_factory";
import { AssistantContext } from "../src/shared/types";

function buildContext(): AssistantContext {
  return {
    assistantProfile: {
      userId: "user-1",
      assistantName: "小眠",
      identityPrompt: "你是一个温柔的睡前陪伴助手。",
      tone: "温柔、稳定、共情",
      relationshipRole: "睡前陪伴助手",
      updatedAt: "2026-04-08T12:00:00.000Z",
    },
    user: {
      uid: "user-1",
      displayName: "Test User",
      tagline: "Dorm sleeper",
      role: "Student",
      dormId: "dorm-204",
      avatarUrl: "",
    },
    settings: {
      sleepGoalHours: 7.5,
      bedtimeReminderEnabled: true,
      morningReminderEnabled: true,
      dormAlertsEnabled: true,
      bedtimeReminder: {
        hour: 23,
        minute: 10,
      },
      preferredTrackTitle: "Deep Ocean Waves",
      smartSuggestionsEnabled: true,
      selectedNightMood: "calm",
    },
    dorm: {
      id: "dorm-204",
      name: "Dorm 204",
      overview: "Quiet enough for sleep.",
      noiseDb: 34,
      lightLabel: "Dim",
      quietLabel: "Stable",
      members: [
        {
          uid: "user-1",
          name: "Test User",
          status: "quiet",
          sleepModeActive: false,
        },
      ],
      events: [],
    },
    recentSessions: [],
    recentDreams: [],
    recentMessages: [],
    userState: null,
  };
}

test("provider factory honors explicit deterministic mode even when baseUrl exists", () => {
  const provider = createAIProviderFromEnv({
    AI_PROVIDER_MODE: "deterministic",
    AI_PROVIDER_BASE_URL: "https://example.com/not-used",
  } as NodeJS.ProcessEnv);

  assert.ok(provider instanceof DeterministicAIProvider);
});

test("xAI responses provider returns remoteSuccess for valid structured JSON", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (async () =>
    ({
      ok: true,
      status: 200,
      text: async () =>
        JSON.stringify({
          output_text: JSON.stringify({
            reply: "这次先从耳塞和放松音频开始。",
            intent: "noise_issue",
            recommendedActions: [
              {
                id: "earplug",
                title: "提前准备耳塞",
                subtitle: "先压住宿舍噪声。",
                type: "quickAction",
                priority: 1,
                reason: "噪声是第一干扰项。",
                route: "/intervention/task",
                trackId: null,
                tags: ["1 分钟"],
              },
            ],
            updateTonightPlan: true,
            updatedSurfaces: ["assistant_context", "home_pre_sleep"],
          }),
        }),
    }) as Response);

  try {
    const provider = createAIProviderFromEnv({
      AI_PROVIDER_MODE: "xai_responses",
      AI_PROVIDER_API_KEY: "test-key",
      AI_PROVIDER_MODEL: "grok-test",
      AI_PROVIDER_BASE_URL: "https://api.x.ai/v1/responses",
    } as NodeJS.ProcessEnv);

    const result = await provider.generateStructuredReply(
      buildContext(),
      "noise_issue",
      "宿舍有点吵，今晚怎么办？",
    );

    assert.equal(result.sourceMode, "remoteSuccess");
    assert.equal(result.providerName, "xai_responses");
    assert.equal(result.modelName, "grok-test");
    assert.equal(result.value.reply, "这次先从耳塞和放松音频开始。");
    assert.equal(result.errorMessage, null);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("xAI responses provider falls back when remote payload is not valid JSON", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (async () =>
    ({
      ok: true,
      status: 200,
      text: async () => JSON.stringify({ output_text: "not-json-at-all" }),
    }) as Response);

  try {
    const provider = createAIProviderFromEnv({
      AI_PROVIDER_MODE: "xai_responses",
      AI_PROVIDER_API_KEY: "test-key",
      AI_PROVIDER_MODEL: "grok-test",
      AI_PROVIDER_BASE_URL: "https://api.x.ai/v1/responses",
    } as NodeJS.ProcessEnv);

    const result = await provider.generateStructuredReply(
      buildContext(),
      "general_support",
      "陪我说两句",
    );

    assert.equal(result.sourceMode, "fallbackSuccess");
    assert.equal(result.providerName, "xai_responses");
    assert.equal(result.modelName, "grok-test");
    assert.ok(result.errorMessage?.includes("valid JSON object"));
    assert.notEqual(result.value.reply.trim(), "");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("xAI responses provider falls back when remote JSON misses required reply fields", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (async () =>
    ({
      ok: true,
      status: 200,
      text: async () =>
        JSON.stringify({
          output_text: JSON.stringify({
            intent: "general_support",
            recommendedActions: [],
            updateTonightPlan: false,
            updatedSurfaces: ["assistant_context"],
          }),
        }),
    }) as Response);

  try {
    const provider = createAIProviderFromEnv({
      AI_PROVIDER_MODE: "xai_responses",
      AI_PROVIDER_API_KEY: "test-key",
      AI_PROVIDER_MODEL: "grok-test",
      AI_PROVIDER_BASE_URL: "https://api.x.ai/v1/responses",
    } as NodeJS.ProcessEnv);

    const result = await provider.generateStructuredReply(
      buildContext(),
      "general_support",
      "你是什么模型？",
    );

    assert.equal(result.sourceMode, "fallbackSuccess");
    assert.ok(result.errorMessage?.includes("reply"));
    assert.notEqual(result.value.reply.trim(), "");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("xAI responses provider retries regional endpoint after network fetch failure", async () => {
  const originalFetch = globalThis.fetch;
  let attempt = 0;
  globalThis.fetch = (async (input: string | URL | Request) => {
    attempt += 1;
    const url = String(input);
    if (attempt === 1) {
      const error = new Error("fetch failed") as Error & {
        cause?: { code: string; message: string };
      };
      error.cause = {
        code: "ECONNRESET",
        message: "socket hang up",
      };
      throw error;
    }
    assert.equal(url, "https://us-east-1.api.x.ai/v1/responses");
    return {
      ok: true,
      status: 200,
      text: async () =>
        JSON.stringify({
          output_text: JSON.stringify({
            reply: "Regional retry succeeded.",
            intent: "general_support",
            recommendedActions: [],
            updateTonightPlan: false,
            updatedSurfaces: ["assistant_context"],
          }),
        }),
    } as Response;
  }) as typeof fetch;

  try {
    const provider = createAIProviderFromEnv({
      AI_PROVIDER_MODE: "xai_responses",
      AI_PROVIDER_API_KEY: "test-key",
      AI_PROVIDER_MODEL: "grok-test",
      AI_PROVIDER_BASE_URL: "https://api.x.ai/v1/responses",
    } as NodeJS.ProcessEnv);

    const result = await provider.generateStructuredReply(
      buildContext(),
      "general_support",
      "陪我说句话",
    );

    assert.equal(result.sourceMode, "remoteSuccess");
    assert.equal(result.value.reply, "Regional retry succeeded.");
    assert.equal(attempt, 2);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("cloudbase_ai preserves remote reply text when structured metadata is incomplete", async () => {
  const modulePath = require.resolve("@cloudbase/node-sdk");
  const originalExports = require(modulePath);
  require.cache[modulePath]!.exports = {
    init: () => ({
      ai: () => ({
        createModel: () => ({
          generateText: async () => ({
            text: JSON.stringify({
              reply: "这条内容来自真实模型，只是没有补全其它结构字段。",
            }),
          }),
        }),
      }),
    }),
  };

  try {
    const provider = createAIProviderFromEnv({
      AI_PROVIDER_MODE: "cloudbase_ai",
      AI_PROVIDER_MODEL: "hunyuan-2.0-instruct-20251111",
      CLOUDBASE_ENV_ID: "demo-env",
    } as NodeJS.ProcessEnv);

    const result = await provider.generateStructuredReply(
      buildContext(),
      "general_support",
      "hi",
    );

    assert.equal(result.sourceMode, "fallbackSuccess");
    assert.equal(result.providerName, "cloudbase_ai");
    assert.equal(result.modelName, "hunyuan-2.0-instruct-20251111");
    assert.equal(
      result.value.reply,
      "这条内容来自真实模型，只是没有补全其它结构字段。",
    );
    assert.ok(result.errorMessage?.includes("intent"));
  } finally {
    require.cache[modulePath]!.exports = originalExports;
  }
});

test("cloudbase_ai uses CloudBase OpenAI-compatible gateway for custom provider groups", async () => {
  const originalFetch = globalThis.fetch;
  let capturedUrl = "";
  let capturedAuth = "";
  globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    capturedUrl = String(input);
    capturedAuth = String(init?.headers && (init.headers as Record<string, string>).authorization);
    return {
      ok: true,
      status: 200,
      text: async () =>
        JSON.stringify({
          choices: [
            {
              message: {
                content: JSON.stringify({
                  reviewSummary: "ok",
                  effectiveActions: [],
                  ineffectiveActions: [],
                  profileSummary: {
                    sleepPatternSummary: "stable",
                    highRiskFactors: [],
                    effectiveActions: [],
                    dreamTrendSummary: "stable",
                    emotionTrendSummary: "stable",
                    lastUpdatedAt: "2026-04-08T12:00:00.000Z",
                  },
                }),
              },
            },
          ],
        }),
    } as Response;
  }) as typeof fetch;

  try {
    const provider = createAIProviderFromEnv({
      AI_PROVIDER_MODE: "cloudbase_ai",
      AI_PROVIDER_GROUP: "openai-compatible-custom",
      AI_PROVIDER_MODEL: "gpt-4.1-mini",
      AI_PROVIDER_API_KEY: "cloudbase-api-key",
      CLOUDBASE_ENV_ID: "demo-env",
    } as NodeJS.ProcessEnv);

    await provider.analyzeFeedback(buildContext(), "session-1");

    assert.equal(
      capturedUrl,
      "https://demo-env.api.tcloudbasegateway.com/v1/ai/openai-compatible-custom/v1/chat/completions",
    );
    assert.equal(capturedAuth, "Bearer cloudbase-api-key");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("cloudbase_ai streams plain reply text for custom provider groups", async () => {
  const originalFetch = globalThis.fetch;
  let capturedStream = false;
  globalThis.fetch = (async (_input: string | URL | Request, init?: RequestInit) => {
    const requestBody = JSON.parse(String(init?.body ?? "{}"));
    capturedStream = requestBody.stream === true;
    const stream = new ReadableStream<Uint8Array>({
      start(controller) {
        const encoder = new TextEncoder();
        controller.enqueue(
          encoder.encode(
            'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n',
          ),
        );
        controller.enqueue(
          encoder.encode(
            'data: {"choices":[{"delta":{"content":" world"}}]}\n\n',
          ),
        );
        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
        controller.close();
      },
    });
    return new Response(stream, {
      status: 200,
      headers: {
        "content-type": "text/event-stream",
      },
    });
  }) as typeof fetch;

  try {
    const provider = createAIProviderFromEnv({
      AI_PROVIDER_MODE: "cloudbase_ai",
      AI_PROVIDER_GROUP: "openai-compatible-custom",
      AI_PROVIDER_MODEL: "gpt-4.1-mini",
      AI_PROVIDER_API_KEY: "cloudbase-api-key",
      CLOUDBASE_ENV_ID: "demo-env",
    } as NodeJS.ProcessEnv);

    const deltas: string[] = [];
    const result = await provider.streamReplyText(
      buildContext(),
      "general_support",
      "hi",
      (delta) => {
        deltas.push(delta);
      },
    );

    assert.equal(capturedStream, true);
    assert.deepEqual(deltas, ["Hello", " world"]);
    assert.equal(result.sourceMode, "remoteSuccess");
    assert.equal(result.value, "Hello world");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("cloudbase_ai returns a clear error when custom provider group has no CloudBase API key", async () => {
  const provider = createAIProviderFromEnv({
    AI_PROVIDER_MODE: "cloudbase_ai",
    AI_PROVIDER_GROUP: "openai-compatible-custom",
    AI_PROVIDER_MODEL: "gpt-4.1-mini",
    CLOUDBASE_ENV_ID: "demo-env",
  } as NodeJS.ProcessEnv);

  const result = await provider.generateStructuredReply(
    buildContext(),
    "general_support",
    "hi",
  );

  assert.equal(result.sourceMode, "fallbackSuccess");
  assert.ok(result.errorMessage?.includes("CloudBase API key is missing"));
});

test("xAI responses provider uses reply model override for chat replies", async () => {
  const originalFetch = globalThis.fetch;
  let capturedModel = "";
  globalThis.fetch = (async (_input: string | URL | Request, init?: RequestInit) => {
    const requestBody = JSON.parse(String(init?.body ?? "{}"));
    capturedModel = String(requestBody.model ?? "");
    return {
      ok: true,
      status: 200,
      text: async () => JSON.stringify({ output_text: "Quick reply" }),
    } as Response;
  }) as typeof fetch;

  try {
    const provider = createAIProviderFromEnv({
      AI_PROVIDER_MODE: "xai_responses",
      AI_PROVIDER_API_KEY: "test-key",
      AI_PROVIDER_MODEL: "grok-main",
      AI_PROVIDER_MODEL_REPLY: "grok-fast",
      AI_PROVIDER_BASE_URL: "https://api.x.ai/v1/responses",
    } as NodeJS.ProcessEnv);

    const result = await provider.streamReplyText(
      buildContext(),
      "general_support",
      "hello",
    );

    assert.equal(capturedModel, "grok-fast");
    assert.equal(result.modelName, "grok-fast");
    assert.equal(result.value, "Quick reply");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test(
  "provider factory inherits shared timeout for reply and structured requests when specific overrides are missing",
  { concurrency: false },
  async () => {
    const originalFetch = globalThis.fetch;
    const originalAbortSignalTimeout = AbortSignal.timeout;
    const capturedTimeouts: number[] = [];
    Object.defineProperty(AbortSignal, "timeout", {
      configurable: true,
      value: ((timeoutMs: number) => {
        capturedTimeouts.push(timeoutMs);
        return new AbortController().signal;
      }) as typeof AbortSignal.timeout,
    });
    globalThis.fetch = (async (
      _input: string | URL | Request,
      init?: RequestInit,
    ) => {
      const requestBody = JSON.parse(String(init?.body ?? "{}"));
      if (requestBody.text?.format?.type === "json_schema") {
        return {
          ok: true,
          status: 200,
          text: async () =>
            JSON.stringify({
              output_text: JSON.stringify({
                reply: "Structured reply",
                intent: "general_support",
                recommendedActions: [],
                updateTonightPlan: false,
                updatedSurfaces: ["assistant_context"],
              }),
            }),
        } as Response;
      }
      return {
        ok: true,
        status: 200,
        text: async () => JSON.stringify({ output_text: "Quick reply" }),
      } as Response;
    }) as typeof fetch;

    try {
      const provider = createAIProviderFromEnv({
        AI_PROVIDER_MODE: "xai_responses",
        AI_PROVIDER_API_KEY: "test-key",
        AI_PROVIDER_MODEL: "grok-main",
        AI_PROVIDER_BASE_URL: "https://example.com/replies",
        AI_PROVIDER_TIMEOUT_MS: "240000",
      } as NodeJS.ProcessEnv);

      await provider.streamReplyText(buildContext(), "general_support", "hello");
      await provider.generateStructuredReply(
        buildContext(),
        "general_support",
        "hello",
      );

      assert.deepEqual(capturedTimeouts, [240000, 240000]);
    } finally {
      globalThis.fetch = originalFetch;
      Object.defineProperty(AbortSignal, "timeout", {
        configurable: true,
        value: originalAbortSignalTimeout,
      });
    }
  },
);

test(
  "provider factory prefers explicit reply and structured timeout overrides",
  { concurrency: false },
  async () => {
    const originalFetch = globalThis.fetch;
    const originalAbortSignalTimeout = AbortSignal.timeout;
    const capturedTimeouts: number[] = [];
    Object.defineProperty(AbortSignal, "timeout", {
      configurable: true,
      value: ((timeoutMs: number) => {
        capturedTimeouts.push(timeoutMs);
        return new AbortController().signal;
      }) as typeof AbortSignal.timeout,
    });
    globalThis.fetch = (async (
      _input: string | URL | Request,
      init?: RequestInit,
    ) => {
      const requestBody = JSON.parse(String(init?.body ?? "{}"));
      if (requestBody.text?.format?.type === "json_schema") {
        return {
          ok: true,
          status: 200,
          text: async () =>
            JSON.stringify({
              output_text: JSON.stringify({
                reply: "Structured reply",
                intent: "general_support",
                recommendedActions: [],
                updateTonightPlan: false,
                updatedSurfaces: ["assistant_context"],
              }),
            }),
        } as Response;
      }
      return {
        ok: true,
        status: 200,
        text: async () => JSON.stringify({ output_text: "Quick reply" }),
      } as Response;
    }) as typeof fetch;

    try {
      const provider = createAIProviderFromEnv({
        AI_PROVIDER_MODE: "xai_responses",
        AI_PROVIDER_API_KEY: "test-key",
        AI_PROVIDER_MODEL: "grok-main",
        AI_PROVIDER_BASE_URL: "https://example.com/replies",
        AI_PROVIDER_TIMEOUT_MS: "240000",
        AI_PROVIDER_TIMEOUT_MS_REPLY: "120000",
        AI_PROVIDER_TIMEOUT_MS_STRUCTURED: "180000",
      } as NodeJS.ProcessEnv);

      await provider.streamReplyText(buildContext(), "general_support", "hello");
      await provider.generateStructuredReply(
        buildContext(),
        "general_support",
        "hello",
      );

      assert.deepEqual(capturedTimeouts, [120000, 180000]);
    } finally {
      globalThis.fetch = originalFetch;
      Object.defineProperty(AbortSignal, "timeout", {
        configurable: true,
        value: originalAbortSignalTimeout,
      });
    }
  },
);

test("xAI responses provider surfaces chat reply failures instead of returning fallback text", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (async () => {
    throw new Error("The operation was aborted.");
  }) as typeof fetch;

  try {
    const provider = createAIProviderFromEnv({
      AI_PROVIDER_MODE: "xai_responses",
      AI_PROVIDER_API_KEY: "test-key",
      AI_PROVIDER_MODEL: "grok-main",
      AI_PROVIDER_BASE_URL: "https://api.x.ai/v1/responses",
    } as NodeJS.ProcessEnv);

    await assert.rejects(
      provider.streamReplyText(buildContext(), "general_support", "hi"),
      /aborted/i,
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("cloudbase_ai uses structured model override for JSON tasks", async () => {
  const originalFetch = globalThis.fetch;
  let capturedModel = "";
  globalThis.fetch = (async (_input: string | URL | Request, init?: RequestInit) => {
    const requestBody = JSON.parse(String(init?.body ?? "{}"));
    capturedModel = String(requestBody.model ?? "");
    return {
      ok: true,
      status: 200,
      text: async () =>
        JSON.stringify({
          choices: [
            {
              message: {
                content: JSON.stringify({
                  reviewSummary: "ok",
                  effectiveActions: [],
                  ineffectiveActions: [],
                  profileSummary: {
                    sleepPatternSummary: "stable",
                    highRiskFactors: [],
                    effectiveActions: [],
                    dreamTrendSummary: "stable",
                    emotionTrendSummary: "stable",
                    lastUpdatedAt: "2026-04-08T12:00:00.000Z",
                  },
                }),
              },
            },
          ],
        }),
    } as Response;
  }) as typeof fetch;

  try {
    const provider = createAIProviderFromEnv({
      AI_PROVIDER_MODE: "cloudbase_ai",
      AI_PROVIDER_GROUP: "openai-compatible-custom",
      AI_PROVIDER_MODEL: "gpt-main",
      AI_PROVIDER_MODEL_STRUCTURED: "gpt-structured",
      AI_PROVIDER_API_KEY: "cloudbase-api-key",
      CLOUDBASE_ENV_ID: "demo-env",
    } as NodeJS.ProcessEnv);

    const result = await provider.analyzeFeedback(buildContext(), "session-1");

    assert.equal(capturedModel, "gpt-structured");
    assert.equal(result.modelName, "gpt-structured");
    assert.equal(result.sourceMode, "remoteSuccess");
  } finally {
    globalThis.fetch = originalFetch;
  }
});
