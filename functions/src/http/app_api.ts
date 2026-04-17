import { randomUUID } from "node:crypto";
import cors from "cors";
import express, { Request, Response } from "express";
import { acceptDormInviteCallable } from "../callables/accept_dorm_invite";
import { assistantCaptureCallable } from "../callables/assistant_capture";
import { assistantReplyCallable } from "../callables/assistant_reply";
import { createDormInviteCallable } from "../callables/create_dorm_invite";
import { prepareTonightPlanCallable } from "../callables/prepare_tonight_plan";
import { refreshUserCardsCallable } from "../callables/refresh_user_cards";
import {
  handleDreamEntryChange,
  handleSleepSessionChange,
} from "../orchestrators/assistant_orchestrator";
import { createAIProviderFromEnv } from "../providers/provider_factory";
import { createRepositoryFromEnv } from "../repositories/firestore_repositories";
import {
  buildCompletedAutomation,
  buildRequestedAutomation,
} from "../shared/automation";

type JsonMap = Record<string, unknown>;

interface AuthContext {
  uid: string;
  accessToken?: string;
}

interface AuthedRequest extends Request {
  authContext?: AuthContext;
}

function nowIso(): string {
  return new Date().toISOString();
}

function logHttp(message: string): void {
  console.log(`[app-api] ${message}`);
}

function asMap(value: unknown): JsonMap {
  return value && typeof value === "object" && !Array.isArray(value)
    ? ({ ...(value as JsonMap) } as JsonMap)
    : {};
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((item) => String(item));
}

function asList(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function asNumber(value: unknown, fallback = 0): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function asSleepCaptureKind(value: unknown): "dream" | "memo" {
  return asString(value) === "dream" ? "dream" : "memo";
}

function sleepDayKeyFromIso(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  const shifted = new Date(date.getTime() + 4 * 60 * 60 * 1000);
  const month = `${shifted.getMonth() + 1}`.padStart(2, "0");
  const day = `${shifted.getDate()}`.padStart(2, "0");
  return `${shifted.getFullYear()}-${month}-${day}`;
}

function fallbackTrackedDurationMinutes(input: {
  summary: unknown;
  startedAt: string;
  endedAt: string;
}): number {
  const summary = asMap(input.summary);
  if (typeof summary.totalSleepHours === "number") {
    return Math.round(summary.totalSleepHours * 60);
  }
  if (!input.startedAt || !input.endedAt) {
    return 0;
  }
  const startedAt = new Date(input.startedAt);
  const endedAt = new Date(input.endedAt);
  if (Number.isNaN(startedAt.getTime()) || Number.isNaN(endedAt.getTime())) {
    return 0;
  }
  return Math.max(
    0,
    Math.min(24 * 60, Math.round((endedAt.getTime() - startedAt.getTime()) / 60000)),
  );
}

export function normalizeCloudBasePhoneNumber(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    return "";
  }
  const normalized = trimmed.replace(/\s+/g, " ");
  if (/^\+[1-9][0-9]{0,3}\s[0-9]{4,20}$/.test(normalized)) {
    return normalized;
  }
  const explicitCountryCode = /^\+([1-9][0-9]{0,3})[- ]([0-9]{4,20})$/.exec(
    normalized,
  );
  if (explicitCountryCode) {
    return `+${explicitCountryCode[1]} ${explicitCountryCode[2]}`;
  }
  const digitsOnly = normalized.replace(/\D/g, "");
  if (!digitsOnly) {
    return normalized;
  }
  if (digitsOnly.startsWith("86") && digitsOnly.length > 5) {
    return `+86 ${digitsOnly.slice(2)}`;
  }
  return `+86 ${digitsOnly}`;
}

function buildGatewayBaseUrl(env: NodeJS.ProcessEnv): string {
  const envId =
    env.CLOUDBASE_ENV_ID?.trim() ||
    env.TCB_ENV?.trim() ||
    env.SCF_NAMESPACE?.trim() ||
    "";
  const explicit = env.CLOUDBASE_AUTH_BASE_URL?.trim();
  if (explicit) {
    return explicit.endsWith("/") ? explicit.slice(0, -1) : explicit;
  }
  return envId ? `https://${envId}.api.tcloudbasegateway.com` : "";
}

function decodeBase64Url(input: string): string {
  const normalized = input.replace(/-/g, "+").replace(/_/g, "/");
  const padding = normalized.length % 4;
  const withPadding =
    padding === 0 ? normalized : `${normalized}${"=".repeat(4 - padding)}`;
  return Buffer.from(withPadding, "base64").toString("utf8");
}

function readUidFromAccessToken(accessToken: string): string {
  const parts = accessToken.split(".");
  if (parts.length < 2) {
    return "";
  }
  try {
    const payload = asMap(JSON.parse(decodeBase64Url(parts[1] ?? "")));
    return (
      asString(payload.sub) ||
      asString(payload.user_id) ||
      asString(payload.id) ||
      ""
    );
  } catch {
    return "";
  }
}

async function resolveAuthenticatedUser(
  request: AuthedRequest,
): Promise<AuthContext> {
  const authorization = request.header("authorization") ?? "";
  const accessToken = authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length).trim()
    : "";
  const fallbackUid =
    request.header("x-debug-uid")?.trim() ||
    process.env.LOCAL_DEBUG_UID?.trim() ||
    "local-user";
  const baseUrl = buildGatewayBaseUrl(process.env);

  if (!accessToken) {
    if (!baseUrl) {
      logHttp(`auth fallback without access token -> uid=${fallbackUid}`);
      return { uid: fallbackUid };
    }
    throw new Error("Missing Authorization bearer token.");
  }

  if (!baseUrl) {
    const localUid = readUidFromAccessToken(accessToken);
    if (localUid) {
      logHttp(`auth resolved from jwt -> uid=${localUid}`);
      return { uid: localUid, accessToken };
    }
    logHttp(`auth fallback without auth base url -> uid=${fallbackUid}`);
    return { uid: fallbackUid, accessToken };
  }

  logHttp("auth verifying bearer token with /auth/v1/user/me");
  const response = await fetch(`${baseUrl}/auth/v1/user/me`, {
    method: "GET",
    headers: {
      authorization: `Bearer ${accessToken}`,
      "x-device-id": request.header("x-device-id") ?? "",
    },
  });
  if (!response.ok) {
    throw new Error(
      `CloudBase auth verification failed with ${response.status}.`,
    );
  }
  const payload = asMap(await response.json());
  const uid =
    asString(payload.sub) ||
    asString(payload.user_id) ||
    asString(payload.id) ||
    readUidFromAccessToken(accessToken) ||
    fallbackUid;
  logHttp(`auth verified by cloudbase -> uid=${uid}`);
  return { uid, accessToken };
}

async function resolvePhoneAccountIdentity(
  request: AuthedRequest,
  phoneAccessToken: string,
): Promise<{ uid: string; phoneNumber: string }> {
  const baseUrl = buildGatewayBaseUrl(process.env);
  if (!baseUrl) {
    throw new Error(
      "CloudBase auth base URL is missing for phone verification.",
    );
  }
  if (!phoneAccessToken.trim()) {
    throw new Error("phoneAccessToken is required.");
  }
  const response = await fetch(`${baseUrl}/auth/v1/user/me`, {
    method: "GET",
    headers: {
      authorization: `Bearer ${phoneAccessToken}`,
      "x-device-id": request.header("x-device-id") ?? "",
    },
  });
  if (!response.ok) {
    throw new Error(`Phone verification failed with ${response.status}.`);
  }
  const payload = asMap(await response.json());
  const uid =
    asString(payload.sub) ||
    asString(payload.user_id) ||
    asString(payload.id) ||
    readUidFromAccessToken(phoneAccessToken);
  const phoneNumber =
    asString(payload.phone_number) ||
    asString(asMap(payload.meta).phone_number);
  if (!uid) {
    throw new Error("Verified phone account uid is missing.");
  }
  if (!phoneNumber) {
    throw new Error(
      "Verified phone number is missing from CloudBase auth response.",
    );
  }
  return {
    uid,
    phoneNumber: normalizeCloudBasePhoneNumber(phoneNumber),
  };
}

async function maybeRepairBootstrapPhone(params: {
  request: AuthedRequest;
  repo: ReturnType<typeof createRepositoryFromEnv>;
  uid: string;
  payload: JsonMap;
}): Promise<JsonMap> {
  const user = asMap(asMap(params.payload.data).user);
  if (asString(user.phoneNumber).trim()) {
    return params.payload;
  }
  const accessToken = params.request.authContext?.accessToken?.trim() || "";
  if (!accessToken) {
    logHttp(`bootstrap phone repair skipped uid=${params.uid} reason=no_access_token`);
    return params.payload;
  }

  try {
    const identity = await resolvePhoneAccountIdentity(params.request, accessToken);
    if (identity.uid !== params.uid) {
      logHttp(
        `bootstrap phone repair skipped uid=${params.uid} reason=uid_mismatch resolvedUid=${identity.uid}`,
      );
      return params.payload;
    }
    await params.repo.saveUserProfile(params.uid, {
      phoneNumber: identity.phoneNumber,
      phoneLinkedAt: nowIso(),
    });
    logHttp(`bootstrap phone repaired uid=${params.uid}`);
    return (await params.repo.getBootstrapPayload(params.uid)) as unknown as JsonMap;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    logHttp(`bootstrap phone repair failed uid=${params.uid} error=${message}`);
    return params.payload;
  }
}

function asyncRoute(
  handler: (request: AuthedRequest, response: Response) => Promise<void>,
) {
  return (
    request: Request,
    response: Response,
    next: (error?: unknown) => void,
  ) => {
    void handler(request as AuthedRequest, response).catch(next);
  };
}

function asyncMiddleware(
  handler: (request: AuthedRequest, response: Response) => Promise<void>,
) {
  return (
    request: Request,
    response: Response,
    next: (error?: unknown) => void,
  ) => {
    void handler(request as AuthedRequest, response)
      .then(() => next())
      .catch(next);
  };
}

function buildSleepSessionPayload(input: {
  uid: string;
  existing?: JsonMap | null;
  body: JsonMap;
  active: boolean;
}): JsonMap {
  const rawSession = asMap(input.body.session);
  const recommendationSnapshot = asList(
    input.body.recommendationSnapshot ?? rawSession.recommendations,
  ).map((item) => asMap(item));
  const selectedRecommendationIds = asStringArray(
    input.body.selectedRecommendationIds ??
      rawSession.selectedRecommendationIds,
  );
  const awakenings = asList(input.body.awakenings ?? rawSession.awakenings).map(
    (item) => asMap(item),
  );
  const feedback = asList(input.body.feedback ?? rawSession.feedback).map(
    (item) => asMap(item),
  );
  const summary =
    input.body.summary === null
      ? null
      : (input.body.summary ??
        rawSession.summary ??
        input.existing?.summary ??
        null);
  const sessionId =
    asString(rawSession.id) ||
    asString(input.body.sessionId) ||
    asString(input.existing?.id) ||
    randomUUID();
  const startedAt = asString(
    rawSession.startedAt,
    asString(input.existing?.startedAt, nowIso()),
  );
  const sleepModeActive =
    rawSession.sleepModeActive === undefined &&
    input.body.sleepModeActive === undefined
      ? input.active
      : Boolean(
          rawSession.sleepModeActive ?? input.body.sleepModeActive ?? input.active,
        );
  const endedAt = sleepModeActive
    ? null
    : asString(
        rawSession.endedAt,
        asString(input.body.endedAt, asString(input.existing?.endedAt)),
      );
  const segments = asList(rawSession.segments ?? input.existing?.segments).map(
    (item) => asMap(item),
  );
  const normalizedSegments =
    segments.length > 0
      ? segments
      : [
          {
            startedAt,
            endedAt,
          },
        ];
  const sleepDayKey = asString(
    rawSession.sleepDayKey,
    asString(
      input.body.sleepDayKey,
      asString(input.existing?.sleepDayKey, sleepDayKeyFromIso(startedAt)),
    ),
  );
  const trackedDurationMinutes = asNumber(
    rawSession.trackedDurationMinutes ??
      input.body.trackedDurationMinutes ??
      input.existing?.trackedDurationMinutes,
    fallbackTrackedDurationMinutes({
      summary,
      startedAt,
      endedAt: asString(endedAt),
    }),
  );

  return {
    ...(input.existing ?? {}),
    ...rawSession,
    id: sessionId,
    uid: input.uid,
    startedAt,
    endedAt,
    sleepDayKey,
    status: asString(
      rawSession.status,
      asString(
        input.body.status,
        asString(input.existing?.status, input.active ? "active" : "awaitingFeedback"),
      ),
    ),
    sleepModeActive,
    dormId: asString(
      input.body.dormId,
      asString(rawSession.dormId, asString(input.existing?.dormId)),
    ),
    recommendations: recommendationSnapshot,
    selectedRecommendationIds,
    segments: normalizedSegments,
    trackedDurationMinutes,
    awakenings,
    feedback,
    summary,
    updatedAt: nowIso(),
  };
}

export function createAppApiServer() {
  const app = express();
  app.use(cors());
  app.use(express.json({ limit: "1mb" }));

  app.get("/health", (_request, response) => {
    response.json({
      ok: true,
      runtime: "cloudbase-http-function",
      timestamp: nowIso(),
      env: {
        hasCloudFunctionEnv: Boolean(
          process.env.SCF_NAMESPACE || process.env.TCB_ENV,
        ),
        hasTencentCloudSecret: Boolean(
          process.env.TENCENTCLOUD_SECRETID &&
          process.env.TENCENTCLOUD_SECRETKEY,
        ),
        hasCloudbaseApiKey: Boolean(process.env.CLOUDBASE_APIKEY),
      },
    });
  });

  app.use(
    asyncMiddleware(async (request, _response) => {
      request.authContext = await resolveAuthenticatedUser(request);
    }),
  );

  app.post(
    "/api/app/bootstrap",
    asyncRoute(async (request, response) => {
      const uid = request.authContext!.uid;
      const startedAt = Date.now();
      logHttp(`bootstrap route start uid=${uid}`);
      logHttp(`bootstrap before createRepository uid=${uid}`);
      const repo = createRepositoryFromEnv();
      logHttp(`bootstrap after createRepository uid=${uid}`);
      const payload = await maybeRepairBootstrapPhone({
        request,
        repo,
        uid,
        payload: (await repo.getBootstrapPayload(uid)) as unknown as JsonMap,
      });
      logHttp(`bootstrap done uid=${uid} durationMs=${Date.now() - startedAt}`);
      response.json(payload);
    }),
  );

  app.post(
    "/api/app/bootstrap-diagnose",
    asyncRoute(async (request, response) => {
      logHttp(`bootstrap-diagnose route start uid=${request.authContext!.uid}`);
      const repo = createRepositoryFromEnv();
      logHttp(
        `bootstrap-diagnose after createRepository uid=${request.authContext!.uid}`,
      );
      response.json(await repo.diagnoseBootstrap(request.authContext!.uid));
    }),
  );

  app.post(
    "/api/profile/save",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const body = asMap(request.body);
      const profile = asMap(body.profile);
      const settings = asMap(body.settings);
      const uid = request.authContext!.uid;
      const result: JsonMap = {};
      if (Object.keys(profile).length > 0) {
        result.profile = await repo.saveUserProfile(uid, profile);
      }
      if (Object.keys(settings).length > 0) {
        result.settings = await repo.saveUserSettings(uid, settings);
      }
      response.json(result);
    }),
  );

  app.post(
    "/api/notifications/read",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const body = asMap(request.body);
      const notificationId = asString(body.notificationId);
      if (!notificationId.trim()) {
        throw new Error("notificationId is required.");
      }
      await repo.markNotificationRead(
        request.authContext!.uid,
        notificationId,
        asString(body.readAt, nowIso()),
      );
      response.json({ ok: true, notificationId });
    }),
  );

  app.post(
    "/api/assistant/profile",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await repo.saveAssistantProfile(
          request.authContext!.uid,
          asMap(request.body),
        ),
      );
    }),
  );

  app.post(
    "/api/profile/avatar",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await repo.updateAvatar(request.authContext!.uid, asMap(request.body)),
      );
    }),
  );

  app.post(
    "/api/dorm/member-status",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await repo.updateDormMemberStatus(
          request.authContext!.uid,
          asMap(request.body),
        ),
      );
    }),
  );

  app.post(
    "/api/profile/night-mood",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const provider = createAIProviderFromEnv();
      const body = asMap(request.body);
      const selectedNightMood = asString(body.selectedNightMood) || null;
      await repo.saveUserSettings(request.authContext!.uid, {
        selectedNightMood,
      });
      response.json(
        await prepareTonightPlanCallable({
          uid: request.authContext!.uid,
          source: asString(body.source, "night_mood"),
          repo,
          provider,
        }),
      );
    }),
  );

  app.post(
    "/api/sleep/enter",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const provider = createAIProviderFromEnv();
      const body = asMap(request.body);
      const existing = body.sessionId
        ? await repo.getSleepSession(asString(body.sessionId))
        : null;
      const session = buildSleepSessionPayload({
        uid: request.authContext!.uid,
        existing,
        body,
        active: true,
      });
      const automationRequestedAt = nowIso();
      session._automation = buildRequestedAutomation(
        "app-api",
        automationRequestedAt,
      );
      session.updatedAt = automationRequestedAt;
      await repo.saveSleepSession(session);
      await handleSleepSessionChange(
        repo,
        provider,
        request.authContext!.uid,
        asString(session.id),
        asString(existing?.status) || null,
        "active",
      );
      await repo.patchSleepSession(asString(session.id), {
        _automation: buildCompletedAutomation({
          previous: session._automation,
          derivedAt: automationRequestedAt,
          derivedBy: "app-api",
          lastHandledStatus: "active",
        }),
      });
      response.json({
        sessionId: session.id,
        status: session.status,
        updatedSurfaces: ["sleep_mode"],
      });
    }),
  );

  app.post(
    "/api/sleep/pause",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const provider = createAIProviderFromEnv();
      const body = asMap(request.body);
      const sessionId = asString(
        body.sessionId,
        asString(asMap(body.session).id),
      );
      const existing = sessionId ? await repo.getSleepSession(sessionId) : null;
      if (!existing) {
        throw new Error("Sleep session was not found.");
      }
      const feedbackAlreadySubmitted = Boolean(existing.summary);
      const nextStatus = feedbackAlreadySubmitted ? "completed" : "paused";
      const session = buildSleepSessionPayload({
        uid: request.authContext!.uid,
        existing,
        body: {
          ...body,
          status: nextStatus,
          sleepModeActive: false,
          endedAt: asString(body.endedAt, nowIso()),
        },
        active: false,
      });
      const automationRequestedAt = nowIso();
      session._automation = buildRequestedAutomation(
        "app-api",
        automationRequestedAt,
      );
      session.updatedAt = automationRequestedAt;
      await repo.saveSleepSession(session);
      await handleSleepSessionChange(
        repo,
        provider,
        request.authContext!.uid,
        asString(session.id),
        asString(existing.status) || null,
        "paused",
      );
      await repo.patchSleepSession(asString(session.id), {
        _automation: buildCompletedAutomation({
          previous: session._automation,
          derivedAt: automationRequestedAt,
          derivedBy: "app-api",
          lastHandledStatus: "paused",
        }),
      });
      response.json({
        sessionId: session.id,
        status: nextStatus,
        feedbackAlreadySubmitted,
        updatedSurfaces: ["profile_report"],
      });
    }),
  );

  app.post(
    "/api/sleep/exit",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const provider = createAIProviderFromEnv();
      const body = asMap(request.body);
      const sessionId = asString(
        body.sessionId,
        asString(asMap(body.session).id),
      );
      const existing = sessionId ? await repo.getSleepSession(sessionId) : null;
      if (!existing) {
        throw new Error("Sleep session was not found.");
      }
      const completed = asString(body.status) === "completed";
      const feedbackAlreadySubmitted = Boolean(existing.summary);
      const nextStatus = completed
        ? "completed"
        : feedbackAlreadySubmitted
          ? asString(existing.status, "completed")
          : "awaitingFeedback";
      const session = buildSleepSessionPayload({
        uid: request.authContext!.uid,
        existing,
        body: {
          ...body,
          status: nextStatus,
          sleepModeActive: false,
          endedAt: asString(body.endedAt, nowIso()),
        },
        active: false,
      });
      const automationRequestedAt = nowIso();
      session._automation = buildRequestedAutomation(
        "app-api",
        automationRequestedAt,
      );
      session.updatedAt = automationRequestedAt;
      await repo.saveSleepSession(session);
      await handleSleepSessionChange(
        repo,
        provider,
        request.authContext!.uid,
        asString(session.id),
        asString(existing.status) || null,
        completed
          ? "completed"
          : feedbackAlreadySubmitted
            ? "paused"
            : "awaitingFeedback",
      );
      await repo.patchSleepSession(asString(session.id), {
        _automation: buildCompletedAutomation({
          previous: session._automation,
          derivedAt: automationRequestedAt,
          derivedBy: "app-api",
          lastHandledStatus: completed
            ? "completed"
            : feedbackAlreadySubmitted
              ? "paused"
              : "awaitingFeedback",
        }),
      });
      response.json({
        sessionId: session.id,
        status: nextStatus,
        feedbackAlreadySubmitted,
        updatedSurfaces: completed
          ? ["morning_feedback", "profile_report", "assistant_context"]
          : feedbackAlreadySubmitted
            ? ["profile_report"]
            : ["morning_feedback", "profile_report"],
      });
    }),
  );

  app.post(
    "/api/dream/save",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const provider = createAIProviderFromEnv();
      const body = asMap(request.body);
      const rawEntry = asMap(body.entry);
      const automationRequestedAt = nowIso();
      const entry = await repo.saveDreamEntry({
        ...rawEntry,
        id: asString(rawEntry.id, randomUUID()),
        userId: request.authContext!.uid,
        createdAt: asString(rawEntry.createdAt, nowIso()),
        updatedAt: automationRequestedAt,
        _automation: buildRequestedAutomation("app-api", automationRequestedAt),
      });
      const analysis = await handleDreamEntryChange(
        repo,
        provider,
        request.authContext!.uid,
        asString(entry.id),
        asString(entry.body),
      );
      await repo.patchDreamEntry(asString(entry.id), {
        _automation: buildCompletedAutomation({
          previous: entry._automation,
          derivedAt: automationRequestedAt,
          derivedBy: "app-api",
        }),
      });
      response.json({
        entryId: entry.id,
        analysis,
        updatedSurfaces: ["profile_report", "assistant_context"],
      });
    }),
  );

  app.post(
    "/api/sleep-capture/save",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const body = asMap(request.body);
      const record = asMap(body.record);
      response.json({
        record: await repo.saveSleepCaptureRecord(request.authContext!.uid, {
          ...record,
          type: asSleepCaptureKind(record.type),
        }),
        updatedSurfaces: ["assistant_context"],
      });
    }),
  );

  app.post(
    "/api/sleep-capture/banner/show",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const sessionId = asString(asMap(request.body).sessionId);
      if (!sessionId.trim()) {
        throw new Error("sessionId is required.");
      }
      const pendingMemoBanner = await repo.buildPendingSleepMemoBanner(
        request.authContext!.uid,
        sessionId,
      );
      await repo.writeUserState(request.authContext!.uid, {
        sleepCapture: {
          pendingMemoBanner:
            pendingMemoBanner === null
              ? null
              : (pendingMemoBanner as any),
        },
      });
      response.json({
        pendingMemoBanner,
        updatedSurfaces: ["home_pre_sleep"],
      });
    }),
  );

  app.post(
    "/api/sleep-capture/banner/clear",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      await repo.clearPendingSleepMemoBanner(request.authContext!.uid);
      response.json({ ok: true, updatedSurfaces: ["home_pre_sleep"] });
    }),
  );

  app.post(
    "/api/feedback/morning",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const provider = createAIProviderFromEnv();
      const body = asMap(request.body);
      const sessionId = asString(
        body.sessionId,
        asString(asMap(body.session).id),
      );
      const existing = sessionId ? await repo.getSleepSession(sessionId) : null;
      if (!existing) {
        throw new Error("Sleep session was not found.");
      }
      const automationRequestedAt = nowIso();
      const session = await repo.saveSleepSession({
        ...existing,
        ...asMap(body.session),
        id: sessionId,
        uid: request.authContext!.uid,
        status: "completed",
        sleepModeActive: false,
        summary: body.summary ?? existing.summary ?? null,
        feedback: asList(body.feedback ?? existing.feedback).map((item) =>
          asMap(item),
        ),
        endedAt: asString(body.endedAt, asString(existing.endedAt, nowIso())),
        updatedAt: automationRequestedAt,
        _automation: buildRequestedAutomation("app-api", automationRequestedAt),
      });
      await handleSleepSessionChange(
        repo,
        provider,
        request.authContext!.uid,
        sessionId,
        asString(existing.status) || null,
        "completed",
      );
      await repo.patchSleepSession(sessionId, {
        _automation: buildCompletedAutomation({
          previous: session._automation,
          derivedAt: automationRequestedAt,
          derivedBy: "app-api",
          lastHandledStatus: "completed",
        }),
      });
      response.json({
        sessionId,
        status: session.status,
        updatedSurfaces: [
          "morning_feedback",
          "profile_report",
          "assistant_context",
        ],
      });
    }),
  );

  app.post(
    "/api/dorm/invite/create",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await createDormInviteCallable({
          uid: request.authContext!.uid,
          expiresInHours: Number(asMap(request.body).expiresInHours ?? 72),
          repo,
        }),
      );
    }),
  );

  app.post(
    "/api/dorm/create",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await repo.createDorm(request.authContext!.uid, asMap(request.body)),
      );
    }),
  );

  app.post(
    "/api/dorm/invite/accept",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await acceptDormInviteCallable({
          uid: request.authContext!.uid,
          inviteCode: asString(asMap(request.body).inviteCode),
          repo,
        }),
      );
    }),
  );

  app.post(
    "/api/dorm/rename",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await repo.renameDorm(
          request.authContext!.uid,
          asString(asMap(request.body).name),
        ),
      );
    }),
  );

  app.post(
    "/api/dorm/member/status",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await repo.updateDormMemberStatus(
          request.authContext!.uid,
          asMap(request.body),
        ),
      );
    }),
  );

  app.post(
    "/api/dorm/location-anchor",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await repo.saveDormLocationAnchor(
          request.authContext!.uid,
          asMap(request.body),
        ),
      );
    }),
  );

  app.post(
    "/api/dorm/environment",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await repo.saveDormEnvironment(
          request.authContext!.uid,
          asMap(request.body),
        ),
      );
    }),
  );

  app.post(
    "/api/dorm/leave",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(await repo.leaveDorm(request.authContext!.uid));
    }),
  );

  app.post(
    "/api/dorm/rules",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const body = asMap(request.body);
      response.json(
        await repo.saveDormRules(
          request.authContext!.uid,
          asMap(body.rulesSettings ?? body),
        ),
      );
    }),
  );

  app.post(
    "/api/dorm/rules/approve",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const body = asMap(request.body);
      response.json(
        await repo.approveDormRules(
          request.authContext!.uid,
          asString(body.proposalId),
        ),
      );
    }),
  );

  app.post(
    "/api/dorm/rules/reject",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const body = asMap(request.body);
      response.json(
        await repo.rejectDormRules(
          request.authContext!.uid,
          asString(body.proposalId),
          asString(body.reason),
        ),
      );
    }),
  );

  app.post(
    "/api/dorm/reminders/gentle",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await repo.sendGentleDormReminder(
          request.authContext!.uid,
          asString(asMap(request.body).targetUid),
          asMap(request.body).anonymous === false ? false : true,
          asString(asMap(request.body).message),
        ),
      );
    }),
  );

  app.post(
    "/api/media/audio-catalog",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(await repo.getAudioTrackCatalog(request.authContext!.uid));
    }),
  );

  app.post(
    "/api/interference/tonight",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await repo.saveTonightInterference(
          request.authContext!.uid,
          asMap(request.body),
        ),
      );
    }),
  );

  app.post(
    "/api/assistant/threads",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      response.json(
        await repo.createAssistantThread(
          request.authContext!.uid,
          asString(asMap(request.body).title),
        ),
      );
    }),
  );

  app.post(
    "/api/assistant/threads/:id",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const body = asMap(request.body);
      response.json(
        await repo.renameAssistantThread(
          request.authContext!.uid,
          asString(request.params.id),
          asString(body.title),
        ),
      );
    }),
  );

  app.post(
    "/api/assistant/threads/:id/delete",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      await repo.deleteAssistantThread(
        request.authContext!.uid,
        asString(request.params.id),
      );
      response.json({ ok: true });
    }),
  );

  app.post(
    "/api/assistant/reply",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const provider = createAIProviderFromEnv();
      const body = asMap(request.body);
      const threadId = asString(
        body.threadId,
        `thread-${request.authContext!.uid}`,
      );
      const prompt = asString(body.prompt);
      if (!prompt.trim()) {
        throw new Error("prompt is required.");
      }
      logHttp(
        `assistant reply start uid=${request.authContext!.uid} threadId=${threadId} provider=${provider.providerName} model=${provider.modelName}`,
      );
      const clientUserMessageId = asString(body.clientUserMessageId, randomUUID());
      const clientAssistantMessageId = asString(
        body.clientAssistantMessageId,
        randomUUID(),
      );
      await repo.ensureAssistantThread(
        request.authContext!.uid,
        threadId,
        asString(body.title, "今晚睡前聊聊"),
      );
      await repo.appendAssistantMessage({
        id: clientUserMessageId,
        threadId,
        role: "user",
        content: prompt,
        createdAt: nowIso(),
        status: "complete",
      });
      const reply = await assistantReplyCallable({
        uid: request.authContext!.uid,
        threadId,
        prompt,
        repo,
        provider,
      });
      logHttp(
        `assistant reply done uid=${request.authContext!.uid} threadId=${threadId} provider=${asString(reply.provider)} model=${asString(reply.model)} sourceMode=${asString(reply.sourceMode)} error=${asString(reply.errorMessage)}`,
      );
      await repo.appendAssistantMessage({
        id: clientAssistantMessageId,
        threadId,
        role: "assistant",
        content: asString(reply.reply),
        createdAt: nowIso(),
        status: asString(reply.sourceMode) === "error" ? "error" : "complete",
        sourceMode: asString(reply.sourceMode, "fallbackSuccess"),
        provider: asString(reply.provider) || undefined,
        model: asString(reply.model) || undefined,
        errorMessage: asString(reply.errorMessage) || undefined,
      });
      response.json({
        ...reply,
        assistantMessageId: clientAssistantMessageId,
      });
    }),
  );

  app.post(
    "/api/assistant/capture",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const provider = createAIProviderFromEnv();
      const body = asMap(request.body);
      const threadId = asString(
        body.threadId,
        `thread-${request.authContext!.uid}`,
      );
      const prompt = asString(body.prompt);
      const sessionId = asString(body.sessionId);
      if (!prompt.trim()) {
        throw new Error("prompt is required.");
      }
      if (!sessionId.trim()) {
        throw new Error("sessionId is required.");
      }
      const captureType = asSleepCaptureKind(body.captureType);
      logHttp(
        `assistant capture start uid=${request.authContext!.uid} threadId=${threadId} sessionId=${sessionId} captureType=${captureType} provider=${provider.providerName} model=${provider.modelName}`,
      );
      const clientUserMessageId = asString(
        body.clientUserMessageId,
        randomUUID(),
      );
      const clientAssistantMessageId = asString(
        body.clientAssistantMessageId,
        randomUUID(),
      );
      await repo.ensureAssistantThread(
        request.authContext!.uid,
        threadId,
        asString(
          body.title,
          captureType === "dream" ? "梦记收纳" : "事记收纳",
        ),
      );
      await repo.appendAssistantMessage({
        id: clientUserMessageId,
        threadId,
        role: "user",
        content: prompt,
        createdAt: nowIso(),
        status: "complete",
      });
      const result = await assistantCaptureCallable({
        uid: request.authContext!.uid,
        threadId,
        prompt,
        captureType,
        sessionId,
        repo,
        provider,
      });
      logHttp(
        `assistant capture done uid=${request.authContext!.uid} threadId=${threadId} sessionId=${sessionId} provider=${asString(result.provider)} model=${asString(result.model)} sourceMode=${asString(result.sourceMode)} error=${asString(result.errorMessage)}`,
      );
      await repo.appendAssistantMessage({
        id: clientAssistantMessageId,
        threadId,
        role: "assistant",
        content: asString(result.reply),
        createdAt: nowIso(),
        status: asString(result.sourceMode) === "error" ? "error" : "complete",
        sourceMode: asString(result.sourceMode, "fallbackSuccess"),
        provider: asString(result.provider) || undefined,
        model: asString(result.model) || undefined,
        errorMessage: asString(result.errorMessage) || undefined,
      });
      response.json({
        ...result,
        assistantMessageId: clientAssistantMessageId,
      });
    }),
  );

  app.post(
    "/api/cards/refresh",
    asyncRoute(async (request, response) => {
      const repo = createRepositoryFromEnv();
      const provider = createAIProviderFromEnv();
      response.json(
        await refreshUserCardsCallable({
          uid: request.authContext!.uid,
          surfaces: asMap(request.body).surfaces,
          repo,
          provider,
        }),
      );
    }),
  );

  app.post(
    "/api/auth/recover-phone-account",
    asyncRoute(async (_request, response) => {
      response.status(410).json({
        code: "LEGACY_DISABLED",
        message:
          "手机号恢复旧匿名账号流程已停用，请直接使用手机号验证码登录或注册。",
      });
    }),
  );

  app.post(
    "/api/auth/link-phone",
    asyncRoute(async (_request, response) => {
      response.status(410).json({
        code: "LEGACY_DISABLED",
        message:
          "手机号绑定旧匿名账号流程已停用，请直接使用手机号验证码登录或注册。",
      });
    }),
  );

  app.use(
    (error: unknown, _request: Request, response: Response, _next: unknown) => {
      const message =
        error instanceof Error ? error.message : "Unknown app-api error.";
      response.status(400).json({
        code: "APP_API_ERROR",
        message,
      });
    },
  );

  return app;
}

export function startAppApiServer(): void {
  const port = Number(process.env.PORT ?? "9000") || 9000;
  const app = createAppApiServer();
  app.listen(port, () => {
    // Keep the log concise because CloudBase function logs are noisy already.
    console.log(`app-api listening on ${port}`);
  });
}

if (require.main === module) {
  startAppApiServer();
}
