import { randomUUID } from "node:crypto";
import {
  AssistantContext,
  AssistantProfileDoc,
  AssistantMemoryItem,
  AssistantRunDoc,
  AssistantThreadSummaryDoc,
  CardSnapshotDoc,
  ContextAssistantMessage,
  ContextAssistantProfile,
  ContextDorm,
  ContextDormEvent,
  ContextDormMember,
  ContextDreamSummary,
  ContextSleepSessionSummary,
  ContextUserProfile,
  ContextUserSettings,
  DreamAnalysis,
  UserStateDoc,
} from "../shared/types";

type JsonMap = Record<string, unknown>;
type SortDirection = "asc" | "desc";

interface QueryOptions {
  filters?: Record<string, unknown>;
  orderBy?: {
    field: string;
    direction: SortDirection;
  };
  limit?: number;
}

interface DocumentStore {
  get(collection: string, id: string): Promise<JsonMap | null>;
  set(collection: string, id: string, data: JsonMap): Promise<void>;
  merge(collection: string, id: string, patch: JsonMap): Promise<void>;
  delete(collection: string, id: string): Promise<void>;
  query(collection: string, options?: QueryOptions): Promise<JsonMap[]>;
}

interface FileStorage {
  getTemporaryUrl(fileId: string, maxAgeSeconds?: number): Promise<string>;
  uploadBytes(params: {
    fileName: string;
    bytes: Buffer;
    contentType?: string;
  }): Promise<{ fileId: string; url: string }>;
}

interface AppBootstrapPayload {
  data: {
    assistantProfile: JsonMap;
    user: JsonMap;
    settings: JsonMap;
    dorm: JsonMap;
    sleepSessions: JsonMap[];
    dreamEntries: JsonMap[];
    sleepCaptureRecords: JsonMap[];
    notifications: JsonMap[];
    assistantThreads: JsonMap[];
    assistantMessages: Record<string, JsonMap[]>;
    cardSnapshots: Record<string, JsonMap>;
    userState: JsonMap;
  };
}

const Collections = {
  users: "users",
  userSettings: "user_settings",
  userState: "user_state",
  cardSnapshots: "card_snapshots",
  assistantRuns: "assistant_runs",
  assistantProfiles: "assistant_profiles",
  accountMigrations: "account_migrations",
  assistantThreadSummaries: "assistant_thread_summaries",
  assistantMemoryItems: "assistant_memory_items",
  sleepSessions: "sleep_sessions",
  dreamEntries: "dream_entries",
  sleepCaptureRecords: "sleep_capture_records",
  assistantThreads: "assistant_threads",
  assistantMessages: "assistant_messages",
  notifications: "notifications",
  dorms: "dorms",
  dormMembers: "dorm_members",
  dormEvents: "dorm_events",
  dormInvites: "dorm_invites",
} as const;

function nowIso(): string {
  return new Date().toISOString();
}

function logDuration(label: string, startedAt: number): void {
  console.log(`[repo] ${label} durationMs=${Date.now() - startedAt}`);
}

function logRepo(message: string): void {
  console.log(`[repo] ${message}`);
}

function asMap(value: unknown): JsonMap {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return { ...(value as JsonMap) };
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

function asNumber(value: unknown, fallback = 0): number {
  return typeof value === "number" ? value : fallback;
}

function asBoolean(value: unknown, fallback = false): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((item) => String(item).trim())
    .filter((item) => item.length > 0);
}

function toJsonValue(value: unknown): unknown {
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (Array.isArray(value)) {
    return value.map((item) => toJsonValue(item));
  }
  if (value && typeof value === "object") {
    const next: JsonMap = {};
    for (const [key, item] of Object.entries(value as JsonMap)) {
      if (item !== undefined) {
        next[key] = toJsonValue(item);
      }
    }
    return next;
  }
  return value;
}

function isMeaningfulString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function errorMessageOf(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error ?? "");
}

function isMissingCollectionError(
  error: unknown,
  collection?: string,
): boolean {
  const message = errorMessageOf(error).toLowerCase();
  if (!message) {
    return false;
  }
  const looksMissing =
    message.includes("db or table not exist") ||
    message.includes("database_collection_not_exist") ||
    message.includes("resourcenotfound");
  if (!looksMissing) {
    return false;
  }
  return collection ? message.includes(collection.toLowerCase()) : true;
}

function isCollectionAlreadyExistsError(error: unknown): boolean {
  const message = errorMessageOf(error).toLowerCase();
  return (
    message.includes("already exists") ||
    message.includes("duplicate") ||
    message.includes("duplicated")
  );
}

function sanitizeCloudBasePayload(value: JsonMap): JsonMap {
  const payload = asMap(toJsonValue(value));
  delete payload._id;
  return payload;
}

function deepClone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function compareValues(
  a: unknown,
  b: unknown,
  direction: SortDirection,
): number {
  const left = a instanceof Date ? a.toISOString() : String(a ?? "");
  const right = b instanceof Date ? b.toISOString() : String(b ?? "");
  return direction === "asc"
    ? left.localeCompare(right)
    : right.localeCompare(left);
}

function withoutMeta<T extends JsonMap>(value: T): T {
  const next = { ...value };
  delete next._id;
  return next as T;
}

function defaultTimeOfDay(): JsonMap {
  return { hour: 23, minute: 10 };
}

function defaultUserProfile(uid: string, dormId?: string | null): JsonMap {
  const seed = uid.slice(0, 6).toUpperCase();
  return {
    uid,
    displayName: `宿舍成员 ${seed}`,
    tagline: "AI 睡眠陪伴中",
    role: "宿舍睡眠优化成员",
    earnedBadgeIds: ["first-week", "early-sleeper", "sleep-master"],
    equippedBadgeId: null,
    showDormPulseBadge: true,
    selectedDormBadgeId: null,
    dormId: dormId ?? null,
    phoneNumber: null,
    phoneLinkedAt: null,
    avatarUrl: null,
    avatarPath: null,
    avatarStoragePath: null,
    avatarFallbackSeed: `宿舍成员 ${seed}`,
    updatedAt: nowIso(),
  };
}

function defaultUserSettings(): JsonMap {
  return {
    sleepGoalHours: 7.5,
    bedtimeReminderEnabled: true,
    morningReminderEnabled: true,
    dormAlertsEnabled: true,
    bedtimeReminder: defaultTimeOfDay(),
    preferredTrackTitle: "深海海浪",
    smartSuggestionsEnabled: true,
    selectedNightMood: null,
    updatedAt: nowIso(),
  };
}

function defaultAssistantProfile(userId: string): JsonMap {
  return {
    userId,
    assistantName: "小眠",
    identityPrompt:
      "你是小眠，一位温和、低压、不评判的情绪陪伴型睡前助手。你会记住用户给你起的名字、偏好和长期背景，用陪伴而不是说教的方式回应。",
    tone: "温柔、稳定、共情",
    relationshipRole: "情绪陪伴助手",
    updatedAt: nowIso(),
  };
}

function defaultDormRulesSettings(): JsonMap {
  return {
    quietHours: "23:00 - 07:00",
    specialCase: "临时讨论或特殊作息请先在宿舍群里说明。",
    lightsOffTime: "23:30 后关闭主灯",
    personalLighting: "夜间只使用个人台灯，避免打扰舍友。",
    examWeekMode: true,
    blackoutCurtain: true,
    vibrationFirst: true,
    alarmResponseSeconds: 60,
    routineNote: "工作日尽量保持稳定作息。",
    routineTags: ["考试周", "共享宿舍", "睡眠优化"],
    summerTempC: 26,
    winterTempC: 22,
    ventilationWindow: "早晨",
    ventilationMinutes: 30,
  };
}

function buildDormRules(rulesSettings: JsonMap): JsonMap[] {
  return [
    {
      id: "quiet-hours",
      title: `安静时段 ${asString(rulesSettings.quietHours, "23:00 - 07:00")}`,
      detail: asString(
        rulesSettings.specialCase,
        "临时讨论或特殊作息请先在宿舍群里说明。",
      ),
    },
    {
      id: "lights-off",
      title: asString(rulesSettings.lightsOffTime, "23:30 后关闭主灯"),
      detail: asString(
        rulesSettings.personalLighting,
        "夜间只使用个人台灯，避免打扰舍友。",
      ),
    },
  ];
}

function defaultDormDoc(dormId: string): JsonMap {
  const rulesSettings = defaultDormRulesSettings();
  return {
    id: dormId,
    name: `宿舍 ${dormId.slice(-4).toUpperCase()}`,
    overview: "已启用 AI 协同的宿舍，适合共同维护安静入睡环境。",
    noiseDb: 32,
    status: "active",
    archivedAt: null,
    lightLabel: "偏暗",
    quietLabel: "平稳",
    rulesSettings,
    rules: buildDormRules(rulesSettings),
    pendingRuleProposal: null,
    earnedDormBadgeIds: ["no-trouble-room", "no-wake-room"],
    updatedAt: nowIso(),
  };
}

function defaultDormMember(
  uid: string,
  name: string,
  avatarUrl?: string | null,
  displayBadgeId?: string | null,
): JsonMap {
  return {
    uid,
    name,
    status: "quiet",
    sleepModeActive: false,
    lastActiveAt: nowIso(),
    note: "今晚已准备进入睡前流程。",
    avatarUrl: avatarUrl ?? null,
    displayBadgeId: displayBadgeId ?? null,
  };
}

function unboundDormContext(): ContextDorm {
  return {
    id: "",
    name: "未加入宿舍",
    overview: "你还没有加入宿舍，先创建宿舍或使用邀请码加入吧。",
    noiseDb: 0,
    status: "active",
    archivedAt: null,
    lightLabel: "未设置",
    quietLabel: "未加入",
    members: [],
    events: [],
    rules: [],
    invites: [],
    rulesSettings: defaultDormRulesSettings(),
    earnedDormBadgeIds: [],
  };
}

function summarizeSleepSession(doc: JsonMap): ContextSleepSessionSummary {
  const summary = asMap(doc.summary);
  const awakenings = Array.isArray(doc.awakenings) ? doc.awakenings : [];
  return {
    id: asString(doc.id, asString(doc._id)),
    startedAt: asString(doc.startedAt),
    endedAt: asString(doc.endedAt),
    status: asString(doc.status, "drafted"),
    awakeningsCount: awakenings.length,
    totalSleepHours:
      typeof summary.totalSleepHours === "number"
        ? summary.totalSleepHours
        : undefined,
    sleepQuality:
      typeof summary.sleepQuality === "number"
        ? summary.sleepQuality
        : undefined,
    restedLevel:
      typeof summary.restedLevel === "number" ? summary.restedLevel : undefined,
    note: asString(summary.note),
  };
}

class InMemoryDocumentStore implements DocumentStore {
  private readonly collections = new Map<string, Map<string, JsonMap>>();

  async get(collection: string, id: string): Promise<JsonMap | null> {
    return deepClone(this.ensureCollection(collection).get(id) ?? null);
  }

  async set(collection: string, id: string, data: JsonMap): Promise<void> {
    this.ensureCollection(collection).set(id, deepClone({ _id: id, ...data }));
  }

  async merge(collection: string, id: string, patch: JsonMap): Promise<void> {
    const current = (await this.get(collection, id)) ?? {};
    await this.set(collection, id, { ...current, ...patch, _id: id });
  }

  async delete(collection: string, id: string): Promise<void> {
    this.ensureCollection(collection).delete(id);
  }

  async query(
    collection: string,
    options: QueryOptions = {},
  ): Promise<JsonMap[]> {
    let docs = Array.from(this.ensureCollection(collection).values()).map(
      (item) => deepClone(item),
    );
    if (options.filters && Object.keys(options.filters).length > 0) {
      docs = docs.filter((doc) => {
        return Object.entries(options.filters ?? {}).every(([key, value]) => {
          return doc[key] === value;
        });
      });
    }
    if (options.orderBy) {
      docs.sort((a, b) =>
        compareValues(
          a[options.orderBy!.field],
          b[options.orderBy!.field],
          options.orderBy!.direction,
        ),
      );
    }
    if (options.limit && options.limit > 0) {
      docs = docs.slice(0, options.limit);
    }
    return docs;
  }

  private ensureCollection(name: string): Map<string, JsonMap> {
    let existing = this.collections.get(name);
    if (!existing) {
      existing = new Map<string, JsonMap>();
      this.collections.set(name, existing);
    }
    return existing;
  }
}

class CloudBaseNoSqlStore implements DocumentStore {
  private readonly db: any;
  private readonly ensuredCollections = new Set<string>();

  constructor(envId: string) {
    logRepo(`CloudBaseNoSqlStore constructor start env=${envId}`);
    const cloudbase = require("@cloudbase/node-sdk") as any;
    const secretId = process.env.TENCENTCLOUD_SECRETID?.trim() || "";
    const secretKey = process.env.TENCENTCLOUD_SECRETKEY?.trim() || "";
    const sessionToken =
      process.env.TENCENTCLOUD_SESSIONTOKEN?.trim() ||
      process.env.TCB_SESSIONTOKEN?.trim() ||
      "";
    const app =
      secretId && secretKey
        ? cloudbase.init({
            env: envId,
            secretId,
            secretKey,
            ...(sessionToken ? { sessionToken } : {}),
          })
        : cloudbase.init({ env: envId });
    logRepo(`cloudbase.init completed env=${envId}`);
    this.db = app.database();
    logRepo(`app.database completed env=${envId}`);
  }

  async get(collection: string, id: string): Promise<JsonMap | null> {
    logRepo(`db.get start collection=${collection} id=${id}`);
    let result;
    try {
      result = await this.db.collection(collection).doc(id).get();
    } catch (error) {
      if (!isMissingCollectionError(error, collection)) {
        throw error;
      }
      logRepo(`db.get missing collection=${collection}, creating it lazily`);
      await this.ensureCollectionExists(collection);
      return null;
    }
    logRepo(`db.get done collection=${collection} id=${id}`);
    const docs = this.normalizeDocs(result?.data);
    return docs[0] ?? null;
  }

  async set(collection: string, id: string, data: JsonMap): Promise<void> {
    logRepo(`db.set start collection=${collection} id=${id}`);
    try {
      await this.db
        .collection(collection)
        .doc(id)
        .set(sanitizeCloudBasePayload(data));
    } catch (error) {
      if (!isMissingCollectionError(error, collection)) {
        throw error;
      }
      logRepo(`db.set missing collection=${collection}, creating it lazily`);
      await this.ensureCollectionExists(collection);
      await this.db
        .collection(collection)
        .doc(id)
        .set(sanitizeCloudBasePayload(data));
    }
    logRepo(`db.set done collection=${collection} id=${id}`);
  }

  async merge(collection: string, id: string, patch: JsonMap): Promise<void> {
    logRepo(`db.merge start collection=${collection} id=${id}`);
    const current = await this.get(collection, id);
    if (!current) {
      logRepo(
        `db.merge no existing doc, falling back to set collection=${collection} id=${id}`,
      );
      await this.set(collection, id, patch);
      return;
    }
    try {
      await this.db
        .collection(collection)
        .doc(id)
        .update(sanitizeCloudBasePayload(patch));
      logRepo(`db.merge update done collection=${collection} id=${id}`);
      return;
    } catch {
      logRepo(
        `db.merge update missed collection=${collection} id=${id}, falling back to get+set`,
      );
      await this.set(collection, id, { ...current, ...patch });
    }
  }

  async delete(collection: string, id: string): Promise<void> {
    logRepo(`db.delete start collection=${collection} id=${id}`);
    try {
      await this.db.collection(collection).doc(id).remove();
    } catch {
      // Ignore delete misses so higher-level flows can stay idempotent.
    }
    logRepo(`db.delete done collection=${collection} id=${id}`);
  }

  async query(
    collection: string,
    options: QueryOptions = {},
  ): Promise<JsonMap[]> {
    logRepo(
      `db.query start collection=${collection} filters=${JSON.stringify(
        options.filters ?? {},
      )} orderBy=${JSON.stringify(options.orderBy ?? null)} limit=${String(
        options.limit ?? "",
      )}`,
    );
    let ref = this.db.collection(collection);
    if (options.filters && Object.keys(options.filters).length > 0) {
      ref = ref.where(toJsonValue(options.filters) as JsonMap);
    }
    if (options.orderBy) {
      ref = ref.orderBy(options.orderBy.field, options.orderBy.direction);
    }
    if (options.limit && options.limit > 0) {
      ref = ref.limit(options.limit);
    }
    let result;
    try {
      result = await ref.get();
    } catch (error) {
      if (!isMissingCollectionError(error, collection)) {
        throw error;
      }
      logRepo(`db.query missing collection=${collection}, creating it lazily`);
      await this.ensureCollectionExists(collection);
      return [];
    }
    logRepo(`db.query done collection=${collection}`);
    return this.normalizeDocs(result?.data);
  }

  private async ensureCollectionExists(collection: string): Promise<void> {
    if (this.ensuredCollections.has(collection)) {
      return;
    }
    try {
      await this.db.createCollection(collection);
      logRepo(`db.createCollection created collection=${collection}`);
    } catch (error) {
      if (!isCollectionAlreadyExistsError(error)) {
        throw error;
      }
      logRepo(`db.createCollection already exists collection=${collection}`);
    }
    this.ensuredCollections.add(collection);
  }

  private normalizeDocs(value: unknown): JsonMap[] {
    if (Array.isArray(value)) {
      return value.map((item) => asMap(item));
    }
    const map = asMap(value);
    return Object.keys(map).length === 0 ? [] : [map];
  }
}

class CloudBaseFileStorage implements FileStorage {
  private readonly app: any;

  constructor(envId: string) {
    const cloudbase = require("@cloudbase/node-sdk") as any;
    const secretId = process.env.TENCENTCLOUD_SECRETID?.trim() || "";
    const secretKey = process.env.TENCENTCLOUD_SECRETKEY?.trim() || "";
    const sessionToken =
      process.env.TENCENTCLOUD_SESSIONTOKEN?.trim() ||
      process.env.TCB_SESSIONTOKEN?.trim() ||
      "";
    this.app =
      secretId && secretKey
        ? cloudbase.init({
            env: envId,
            secretId,
            secretKey,
            ...(sessionToken ? { sessionToken } : {}),
          })
        : cloudbase.init({ env: envId });
  }

  async getTemporaryUrl(
    fileId: string,
    maxAgeSeconds = 60 * 60 * 24 * 7,
  ): Promise<string> {
    if (!fileId.trim()) {
      return "";
    }
    const result = await this.app.getTempFileURL({
      fileList: [{ fileID: fileId, maxAge: maxAgeSeconds, urlType: "COS_URL" }],
    });
    const file = Array.isArray(result?.fileList) ? result.fileList[0] : null;
    return asString(file?.tempFileURL);
  }

  async uploadBytes(params: {
    fileName: string;
    bytes: Buffer;
    contentType?: string;
  }): Promise<{ fileId: string; url: string }> {
    const cloudPath = `avatars/${Date.now()}-${params.fileName}`;
    const result = await this.app.uploadFile({
      cloudPath,
      fileContent: params.bytes,
    });
    const fileId = asString(result?.fileID);
    const url = fileId ? await this.getTemporaryUrl(fileId) : "";
    return { fileId, url };
  }
}

export interface AssistantDataRepository {
  buildAssistantContext(
    uid: string,
    threadId?: string,
  ): Promise<AssistantContext>;
  getBootstrapPayload(uid: string): Promise<AppBootstrapPayload>;
  diagnoseBootstrap(uid: string): Promise<JsonMap>;
  readAssistantProfile(uid: string): Promise<ContextAssistantProfile>;
  saveAssistantProfile(uid: string, patch: JsonMap): Promise<JsonMap>;
  saveUserProfile(uid: string, patch: JsonMap): Promise<JsonMap>;
  saveUserSettings(uid: string, patch: JsonMap): Promise<JsonMap>;
  saveSleepSession(session: JsonMap): Promise<JsonMap>;
  getSleepSession(sessionId: string): Promise<JsonMap | null>;
  patchSleepSession(sessionId: string, patch: JsonMap): Promise<void>;
  saveDreamEntry(entry: JsonMap): Promise<JsonMap>;
  patchDreamEntry(entryId: string, patch: JsonMap): Promise<void>;
  saveSleepCaptureRecord(uid: string, record: JsonMap): Promise<JsonMap>;
  createAssistantThread(
    uid: string,
    title?: string,
  ): Promise<{ id: string; userId: string; title: string; createdAt: string; updatedAt: string }>;
  renameAssistantThread(
    uid: string,
    threadId: string,
    title: string,
  ): Promise<{ id: string; userId: string; title: string; createdAt: string; updatedAt: string }>;
  deleteAssistantThread(uid: string, threadId: string): Promise<void>;
  ensureAssistantThread(
    uid: string,
    threadId: string,
    title?: string,
  ): Promise<void>;
  appendAssistantMessage(message: JsonMap): Promise<void>;
  recoverPhoneAccount(params: {
    sourceUid: string;
    canonicalUid: string;
    phoneNumber: string;
  }): Promise<JsonMap>;
  updateAvatar(
    uid: string,
    payload: JsonMap,
  ): Promise<JsonMap>;
  createDorm(
    uid: string,
    payload: JsonMap,
  ): Promise<{
    dormId: string;
    name: string;
    createdAt: string;
    memberStatus: string;
  }>;
  writeUserState(uid: string, patch: Partial<UserStateDoc>): Promise<void>;
  writeCardSnapshot(uid: string, snapshot: CardSnapshotDoc): Promise<void>;
  writeAssistantRun(
    uid: string,
    runId: string,
    run: AssistantRunDoc,
  ): Promise<void>;
  setDreamAnalysis(entryId: string, analysis: DreamAnalysis): Promise<void>;
  upsertNotification(
    uid: string,
    notificationId: string,
    payload: JsonMap,
  ): Promise<void>;
  createDormInvite(
    uid: string,
    expiresInHours?: number,
  ): Promise<{
    inviteId: string;
    inviteCode: string;
    dormId: string;
    createdAt: string;
    expiresAt: string;
    memberCountSnapshot: number;
  }>;
  acceptDormInvite(
    uid: string,
    inviteCode: string,
  ): Promise<{ dormId: string; acceptedAt: string }>;
  renameDorm(uid: string, name: string): Promise<JsonMap>;
  leaveDorm(uid: string): Promise<JsonMap>;
  saveDormRules(uid: string, settings: JsonMap): Promise<JsonMap>;
  approveDormRules(
    uid: string,
    proposalId: string,
  ): Promise<{ dormId: string; applied: boolean; approvedAt: string }>;
  rejectDormRules(
    uid: string,
    proposalId: string,
    reason: string,
  ): Promise<{ dormId: string; rejectedAt: string; reason: string }>;
  updateDormMemberStatus(
    uid: string,
    payload: JsonMap,
  ): Promise<JsonMap>;
  buildPendingSleepMemoBanner(
    uid: string,
    sessionId: string,
  ): Promise<JsonMap | null>;
  clearPendingSleepMemoBanner(uid: string): Promise<void>;
  sendGentleDormReminder(
    uid: string,
    targetUid: string,
    anonymous?: boolean,
    message?: string,
  ): Promise<{ targetUid: string; createdAt: string }>;
  writeAssistantThreadSummary(
    uid: string,
    summary: AssistantThreadSummaryDoc,
  ): Promise<void>;
  upsertAssistantMemoryItems(
    uid: string,
    items: AssistantMemoryItem[],
  ): Promise<void>;
}

export class FirestoreRepository implements AssistantDataRepository {
  constructor(
    private readonly store: DocumentStore,
    private readonly fileStorage?: FileStorage,
  ) {}

  async getUserProfile(uid: string): Promise<ContextUserProfile> {
    return this.readUserProfile(uid);
  }

  async getUserSettings(uid: string): Promise<ContextUserSettings> {
    return this.readUserSettings(uid);
  }

  async readAssistantProfile(uid: string): Promise<ContextAssistantProfile> {
    await this.ensureUserBootstrap(uid);
    const profile = withoutMeta(
      ((await this.store.get(Collections.assistantProfiles, uid)) ??
        defaultAssistantProfile(uid)) as JsonMap,
    );
    return {
      userId: asString(profile.userId, uid),
      assistantName: asString(profile.assistantName, "小眠"),
      identityPrompt: asString(
        profile.identityPrompt,
        "你是小眠，一位温和、低压、不评判的情绪陪伴型睡前助手。",
      ),
      tone: asString(profile.tone, "温柔、稳定、共情"),
      relationshipRole: asString(profile.relationshipRole, "情绪陪伴助手"),
      updatedAt: asString(profile.updatedAt, nowIso()),
    };
  }

  async saveAssistantProfile(uid: string, patch: JsonMap): Promise<JsonMap> {
    await this.ensureUserBootstrap(uid);
    await this.store.merge(Collections.assistantProfiles, uid, {
      ...patch,
      userId: uid,
      updatedAt: nowIso(),
    });
    return withoutMeta(
      ((await this.store.get(Collections.assistantProfiles, uid)) ??
        defaultAssistantProfile(uid)) as JsonMap,
    );
  }

  async getDorm(
    dormId: string | null | undefined,
    uid = "",
  ): Promise<ContextDorm> {
    const resolvedDormId =
      dormId && dormId.trim().length > 0 ? dormId.trim() : "";
    if (!resolvedDormId) {
      return unboundDormContext();
    }
    const dormDoc = withoutMeta(
      ((await this.store.get(Collections.dorms, resolvedDormId)) ??
        defaultDormDoc(resolvedDormId)) as JsonMap,
    );
    const members = await this.store.query(Collections.dormMembers, {
      filters: { dormId: resolvedDormId },
      orderBy: { field: "lastActiveAt", direction: "desc" },
    });
    const events = await this.store.query(Collections.dormEvents, {
      filters: { dormId: resolvedDormId },
      orderBy: { field: "createdAt", direction: "desc" },
      limit: 8,
    });
    const invites = await this.store.query(Collections.dormInvites, {
      filters: { dormId: resolvedDormId },
      orderBy: { field: "createdAt", direction: "desc" },
      limit: 10,
    });
    const earnedDormBadgeIds = asStringArray(dormDoc.earnedDormBadgeIds);
    return {
      id: asString(dormDoc.id, resolvedDormId),
      name: asString(
        dormDoc.name,
        `宿舍 ${resolvedDormId.slice(-4).toUpperCase()}`,
      ),
      overview: asString(
        dormDoc.overview,
        "已启用 AI 协同的宿舍，适合共同维护安静入睡环境。",
      ),
      noiseDb: asNumber(dormDoc.noiseDb, 32),
      status: asString(dormDoc.status, "active"),
      archivedAt: asString(dormDoc.archivedAt) || null,
      lightLabel: asString(dormDoc.lightLabel, "偏暗"),
      quietLabel: asString(dormDoc.quietLabel, "平稳"),
      members: members.map((doc) => {
        const value = withoutMeta(doc);
        return {
          uid: asString(value.uid),
          name: asString(value.name, "舍友"),
          status: asString(value.status, "quiet"),
          sleepModeActive: asBoolean(value.sleepModeActive, false),
          lastActiveAt: asString(value.lastActiveAt),
          note: asString(value.note),
          avatarUrl: asString(value.avatarUrl) || undefined,
          displayBadgeId: asString(value.displayBadgeId) || undefined,
        } satisfies ContextDormMember;
      }),
      events: events.map((doc) => {
        const value = withoutMeta(doc);
        return {
          id: asString(value.id, asString(value._id)),
          type: asString(value.type, "system"),
          title: asString(value.title, "宿舍动态"),
          detail: asString(value.detail),
          createdAt: asString(value.createdAt),
          actorUid: asString(value.actorUid) || undefined,
        } satisfies ContextDormEvent;
      }),
      ...("rulesSettings" in dormDoc
        ? { rulesSettings: dormDoc.rulesSettings }
        : {}),
      earnedDormBadgeIds:
        earnedDormBadgeIds.length > 0
          ? earnedDormBadgeIds
          : ["no-trouble-room", "no-wake-room"],
      pendingRuleProposal:
        dormDoc.pendingRuleProposal == null
          ? null
          : ((asMap(
              dormDoc.pendingRuleProposal,
            ) as unknown) as ContextDorm["pendingRuleProposal"]),
      rules: (Array.isArray(dormDoc.rules) ? dormDoc.rules : []) as JsonMap[],
      invites: invites.map((doc) => withoutMeta(doc)),
    } as ContextDorm;
  }

  async listRecentSleepSessions(
    uid: string,
    count = 7,
  ): Promise<ContextSleepSessionSummary[]> {
    const docs = await this.store.query(Collections.sleepSessions, {
      filters: { uid },
      orderBy: { field: "startedAt", direction: "desc" },
      limit: count,
    });
    return docs.map((doc) => summarizeSleepSession(withoutMeta(doc)));
  }

  async listRecentDreamEntries(
    uid: string,
    count = 5,
  ): Promise<ContextDreamSummary[]> {
    const docs = await this.store.query(Collections.dreamEntries, {
      filters: { userId: uid },
      orderBy: { field: "createdAt", direction: "desc" },
      limit: count,
    });
    return docs.map((doc) => {
      const value = withoutMeta(doc);
      return {
        id: asString(value.id, asString(value._id)),
        title: asString(value.title, "Dream note"),
        body: asString(value.body),
        emotionLabel: asString(value.emotionLabel),
        createdAt: asString(value.createdAt),
      };
    });
  }

  async listThreadMessages(
    threadId: string | null | undefined,
    count = 20,
  ): Promise<ContextAssistantMessage[]> {
    if (!threadId) {
      return [];
    }
    const docs = await this.store.query(Collections.assistantMessages, {
      filters: { threadId },
      orderBy: { field: "createdAt", direction: "asc" },
      limit: count,
    });
    return docs.map((doc) => {
      const value = withoutMeta(doc);
        return {
          id: asString(value.id, asString(value._id)),
          role: asString(value.role, "assistant"),
          content: asString(value.content),
          status: asString(value.status, "complete"),
          sourceMode: asString(value.sourceMode) || undefined,
          createdAt: asString(value.createdAt),
        };
    });
  }

  async getUserState(uid: string): Promise<UserStateDoc | null> {
    const doc = await this.store.get(Collections.userState, uid);
    return doc ? (withoutMeta(doc) as unknown as UserStateDoc) : null;
  }

  async buildAssistantContext(
    uid: string,
    threadId?: string,
  ): Promise<AssistantContext> {
    const [assistantProfile, user, settings, userState] = await Promise.all([
      this.readAssistantProfile(uid),
      this.readUserProfile(uid),
      this.readUserSettings(uid),
      this.getUserState(uid),
    ]);
    const resolvedThreadId = threadId ?? userState?.latestThreadId ?? null;
    const [
      dorm,
      recentSessions,
      recentDreams,
      recentMessages,
      threadSummary,
      longTermMemory,
    ] =
      await Promise.all([
        this.getDorm(user.dormId, uid),
        this.listRecentSleepSessions(uid),
        this.listRecentDreamEntries(uid),
        this.listThreadMessages(resolvedThreadId),
        this.readAssistantThreadSummary(resolvedThreadId),
        this.listAssistantMemory(uid),
      ]);
    return {
      assistantProfile,
      user,
      settings,
      dorm,
      recentSessions,
      recentDreams,
      recentMessages,
      threadSummary,
      longTermMemory,
      userState,
    };
  }

  async getBootstrapPayload(uid: string): Promise<AppBootstrapPayload> {
    const startedAt = Date.now();
    const assistantProfile = await this.readAssistantProfile(uid);
    logDuration("bootstrap.readAssistantProfile", startedAt);
    const user = await this.readUserProfile(uid);
    logDuration("bootstrap.readUserProfile", startedAt);
    const settings = await this.readUserSettings(uid);
    logDuration("bootstrap.readUserSettings", startedAt);
    const dorm = await this.getDorm(user.dormId, uid);
    logDuration("bootstrap.getDorm", startedAt);
    const [
      sleepSessions,
      dreamEntries,
      sleepCaptureRecords,
      notifications,
      assistantThreads,
      cardSnapshots,
    ] = await Promise.all([
      this.store.query(Collections.sleepSessions, {
        filters: { uid },
        orderBy: { field: "startedAt", direction: "desc" },
        limit: 30,
      }),
      this.store.query(Collections.dreamEntries, {
        filters: { userId: uid },
        orderBy: { field: "createdAt", direction: "desc" },
        limit: 30,
      }),
      this.store.query(Collections.sleepCaptureRecords, {
        filters: { userId: uid },
        orderBy: { field: "createdAt", direction: "desc" },
        limit: 60,
      }),
      this.store.query(Collections.notifications, {
        filters: { ownerUid: uid },
        orderBy: { field: "createdAt", direction: "desc" },
        limit: 40,
      }),
      this.store.query(Collections.assistantThreads, {
        filters: { userId: uid },
        orderBy: { field: "updatedAt", direction: "desc" },
        limit: 20,
      }),
      this.store.query(Collections.cardSnapshots, {
        filters: { uid },
        orderBy: { field: "generatedAt", direction: "desc" },
        limit: 10,
      }),
    ]);
    logDuration("bootstrap.parallelQueries", startedAt);

    const messageMap: Record<string, JsonMap[]> = {};
    for (const thread of assistantThreads) {
      const threadId = asString(thread.id, asString(thread._id));
      const messages = await this.store.query(Collections.assistantMessages, {
        filters: { threadId },
        orderBy: { field: "createdAt", direction: "asc" },
        limit: 80,
      });
      messageMap[threadId] = messages.map((doc) => withoutMeta(doc));
    }
    logDuration("bootstrap.threadMessages", startedAt);

    const snapshotMap: Record<string, JsonMap> = {};
    for (const snapshot of cardSnapshots) {
      const value = withoutMeta(snapshot);
      snapshotMap[asString(value.surfaceId, asString(value._id))] = value;
    }
    logDuration("bootstrap.snapshotMap", startedAt);
    const userState =
      ((await this.getUserState(uid)) as unknown as JsonMap) ?? {};
    logDuration("bootstrap.getUserState", startedAt);

    return {
      data: {
        assistantProfile: assistantProfile as unknown as JsonMap,
        user: user as unknown as JsonMap,
        settings: settings as unknown as JsonMap,
        dorm: dorm as unknown as JsonMap,
        sleepSessions: sleepSessions.map((doc) => withoutMeta(doc)),
        dreamEntries: dreamEntries.map((doc) => withoutMeta(doc)),
        sleepCaptureRecords: sleepCaptureRecords.map((doc) => withoutMeta(doc)),
        notifications: notifications.map((doc) => withoutMeta(doc)),
        assistantThreads: assistantThreads.map((doc) => withoutMeta(doc)),
        assistantMessages: messageMap,
        cardSnapshots: snapshotMap,
        userState,
      },
    };
  }

  async diagnoseBootstrap(uid: string): Promise<JsonMap> {
    const results: JsonMap[] = [];
    const timeoutMs = 4_000;

    const runStage = async <T>(
      label: string,
      work: () => Promise<T>,
    ): Promise<T | null> => {
      const startedAt = Date.now();
      try {
        const value = await Promise.race<T>([
          work(),
          new Promise<T>((_, reject) => {
            setTimeout(() => {
              reject(new Error(`timeout>${timeoutMs}ms`));
            }, timeoutMs);
          }),
        ]);
        results.push({
          label,
          ok: true,
          durationMs: Date.now() - startedAt,
        });
        return value;
      } catch (error) {
        results.push({
          label,
          ok: false,
          durationMs: Date.now() - startedAt,
          error: error instanceof Error ? error.message : String(error),
        });
        return null;
      }
    };

    const user = await runStage("readUserProfile", async () =>
      this.readUserProfile(uid),
    );
    await runStage("readUserSettings", async () => this.readUserSettings(uid));
    await runStage("getDorm", async () =>
      this.getDorm(user?.dormId ? String(user.dormId) : null, uid),
    );
    await runStage("querySleepSessions", async () =>
      this.store.query(Collections.sleepSessions, {
        filters: { uid },
        orderBy: { field: "startedAt", direction: "desc" },
        limit: 30,
      }),
    );
    await runStage("queryDreamEntries", async () =>
      this.store.query(Collections.dreamEntries, {
        filters: { userId: uid },
        orderBy: { field: "createdAt", direction: "desc" },
        limit: 30,
      }),
    );
    await runStage("queryNotifications", async () =>
      this.store.query(Collections.notifications, {
        filters: { ownerUid: uid },
        orderBy: { field: "createdAt", direction: "desc" },
        limit: 40,
      }),
    );
    await runStage("queryAssistantThreads", async () =>
      this.store.query(Collections.assistantThreads, {
        filters: { userId: uid },
        orderBy: { field: "updatedAt", direction: "desc" },
        limit: 20,
      }),
    );
    await runStage("queryCardSnapshots", async () =>
      this.store.query(Collections.cardSnapshots, {
        filters: { uid },
        orderBy: { field: "generatedAt", direction: "desc" },
        limit: 10,
      }),
    );
    await runStage("getUserState", async () => this.getUserState(uid));

    return {
      uid,
      timeoutMs,
      results,
    };
  }

  async saveUserProfile(uid: string, patch: JsonMap): Promise<JsonMap> {
    await this.ensureUserBootstrap(uid);
    await this.store.merge(Collections.users, uid, {
      ...patch,
      uid,
      updatedAt: nowIso(),
    });
    const user = withoutMeta((await this.store.get(Collections.users, uid)) ?? {});
    const dormId = asString(user.dormId);
    if (dormId) {
      const memberId = `${dormId}:${uid}`;
      const member = await this.store.get(Collections.dormMembers, memberId);
      if (member) {
        await this.store.merge(Collections.dormMembers, memberId, {
          name: asString(user.displayName),
          avatarUrl: asString(user.avatarUrl) || null,
          displayBadgeId:
            asString(user.equippedBadgeId) ||
            asStringArray(user.earnedBadgeIds).slice(-1)[0] ||
            null,
          lastActiveAt: nowIso(),
        });
      }
    }
    return user;
  }

  async saveUserSettings(uid: string, patch: JsonMap): Promise<JsonMap> {
    await this.ensureUserBootstrap(uid);
    await this.store.merge(Collections.userSettings, uid, {
      ...patch,
      updatedAt: nowIso(),
    });
    return withoutMeta(
      (await this.store.get(Collections.userSettings, uid)) ?? {},
    );
  }

  async saveSleepSession(session: JsonMap): Promise<JsonMap> {
    const sessionId = asString(session.id, randomUUID());
    const uid = asString(session.uid);
    await this.ensureUserBootstrap(uid);
    await this.store.set(Collections.sleepSessions, sessionId, {
      ...session,
      id: sessionId,
      uid,
      updatedAt: asString(session.updatedAt, nowIso()),
    });
    return withoutMeta(
      (await this.store.get(Collections.sleepSessions, sessionId)) ?? {},
    );
  }

  async updateDormMemberStatus(uid: string, payload: JsonMap): Promise<JsonMap> {
    const user = await this.getUserProfile(uid);
    const dormId = user.dormId ? user.dormId.trim() : "";
    if (!dormId) {
      throw new Error("Create or join a dorm before updating member status.");
    }
    const memberId = `${dormId}:${uid}`;
    const existingMember = await this.store.get(Collections.dormMembers, memberId);
    const nextStatus = asString(payload.status, "quiet");
    const nextSleepModeActive = asBoolean(payload.sleepModeActive, false);
    const nextNote = asString(payload.note, "已更新宿舍状态。");
    const updatedAt = nowIso();
    await this.store.merge(Collections.dormMembers, memberId, {
      dormId,
      ...(existingMember ??
        defaultDormMember(uid, user.displayName, user.avatarUrl)),
      uid,
      name: user.displayName,
      avatarUrl: user.avatarUrl ?? null,
      status: nextStatus,
      sleepModeActive: nextSleepModeActive,
      note: nextNote,
      lastActiveAt: updatedAt,
    });
    await this.store.set(Collections.dormEvents, randomUUID(), {
      id: randomUUID(),
      dormId,
      type: "memberStatus",
      title: "舍友更新了状态",
      detail: nextNote,
      actorUid: uid,
      createdAt: updatedAt,
    });
    return withoutMeta((await this.store.get(Collections.dormMembers, memberId)) ?? {});
  }

  async getSleepSession(sessionId: string): Promise<JsonMap | null> {
    const doc = await this.store.get(Collections.sleepSessions, sessionId);
    return doc ? withoutMeta(doc) : null;
  }

  async patchSleepSession(sessionId: string, patch: JsonMap): Promise<void> {
    await this.store.merge(Collections.sleepSessions, sessionId, patch);
  }

  async saveDreamEntry(entry: JsonMap): Promise<JsonMap> {
    const entryId = asString(entry.id, randomUUID());
    await this.ensureUserBootstrap(asString(entry.userId));
    await this.store.set(Collections.dreamEntries, entryId, {
      ...entry,
      id: entryId,
      createdAt: asString(entry.createdAt, nowIso()),
      updatedAt: nowIso(),
    });
    return withoutMeta(
      (await this.store.get(Collections.dreamEntries, entryId)) ?? {},
    );
  }

  async patchDreamEntry(entryId: string, patch: JsonMap): Promise<void> {
    await this.store.merge(Collections.dreamEntries, entryId, patch);
  }

  async saveSleepCaptureRecord(uid: string, record: JsonMap): Promise<JsonMap> {
    const recordId = asString(record.id, randomUUID());
    await this.ensureUserBootstrap(uid);
    await this.store.set(Collections.sleepCaptureRecords, recordId, {
      ...record,
      id: recordId,
      userId: uid,
      createdAt: asString(record.createdAt, nowIso()),
      updatedAt: nowIso(),
    });
    return withoutMeta(
      (await this.store.get(Collections.sleepCaptureRecords, recordId)) ?? {},
    );
  }

  async createAssistantThread(
    uid: string,
    title?: string,
  ): Promise<{
    id: string;
    userId: string;
    title: string;
    createdAt: string;
    updatedAt: string;
  }> {
    await this.ensureUserBootstrap(uid);
    const createdAt = nowIso();
    const thread = {
      id: randomUUID(),
      userId: uid,
      title: isMeaningfulString(title) ? title.trim() : "鏂扮殑鍔╃湢瀵硅瘽",
      createdAt,
      updatedAt: createdAt,
    };
    await this.store.set(Collections.assistantThreads, thread.id, thread);
    return thread;
  }

  async renameAssistantThread(
    uid: string,
    threadId: string,
    title: string,
  ): Promise<{
    id: string;
    userId: string;
    title: string;
    createdAt: string;
    updatedAt: string;
  }> {
    const existing = await this.store.get(Collections.assistantThreads, threadId);
    if (!existing || asString(existing.userId) != uid) {
      throw new Error(`Assistant thread "${threadId}" was not found.`);
    }
    const next = {
      ...withoutMeta(existing),
      id: threadId,
      userId: uid,
      title: title.trim(),
      createdAt: asString(existing.createdAt, nowIso()),
      updatedAt: nowIso(),
    };
    await this.store.set(Collections.assistantThreads, threadId, next);
    return next;
  }

  async deleteAssistantThread(uid: string, threadId: string): Promise<void> {
    const existing = await this.store.get(Collections.assistantThreads, threadId);
    if (!existing || asString(existing.userId) != uid) {
      return;
    }
    const messages = await this.store.query(Collections.assistantMessages, {
      filters: { threadId },
    });
    await Promise.all(
      messages.map((message) =>
        this.store.delete(
          Collections.assistantMessages,
          asString(message._id, `${threadId}:${asString(message.id)}`),
        ),
      ),
    );
    await this.store.delete(Collections.assistantThreads, threadId);
    await this.store.delete(Collections.assistantThreadSummaries, threadId);
  }

  async ensureAssistantThread(
    uid: string,
    threadId: string,
    title?: string,
  ): Promise<void> {
    await this.ensureUserBootstrap(uid);
    const existing = await this.store.get(
      Collections.assistantThreads,
      threadId,
    );
    if (existing) {
      await this.store.merge(Collections.assistantThreads, threadId, {
        updatedAt: nowIso(),
      });
      return;
    }
    await this.store.set(Collections.assistantThreads, threadId, {
      id: threadId,
      userId: uid,
      title: title ?? "今晚睡前聊聊",
      createdAt: nowIso(),
      updatedAt: nowIso(),
    });
  }

  async appendAssistantMessage(message: JsonMap): Promise<void> {
    const threadId = asString(message.threadId);
    const messageId = asString(message.id, randomUUID());
    if (!threadId) {
      throw new Error("threadId is required for assistant messages.");
    }
    await this.store.set(
      Collections.assistantMessages,
      `${threadId}:${messageId}`,
      {
        ...message,
        id: messageId,
        threadId,
        createdAt: asString(message.createdAt, nowIso()),
      },
    );
    await this.store.merge(Collections.assistantThreads, threadId, {
      updatedAt: nowIso(),
    });
  }

  async recoverPhoneAccount(params: {
    sourceUid: string;
    canonicalUid: string;
    phoneNumber: string;
  }): Promise<JsonMap> {
    await this.ensureUserBootstrap(params.sourceUid);
    await this.ensureUserBootstrap(params.canonicalUid);
    const migrationId = `${params.canonicalUid}:${params.sourceUid}`;
    const existingMigration = await this.store.get(
      Collections.accountMigrations,
      migrationId,
    );
    if (existingMigration) {
      return withoutMeta(existingMigration);
    }

    const migratedAt = nowIso();
    if (params.sourceUid === params.canonicalUid) {
      await this.store.merge(Collections.users, params.canonicalUid, {
        phoneNumber: params.phoneNumber,
        phoneLinkedAt: migratedAt,
        updatedAt: migratedAt,
      });
      const record = {
        id: migrationId,
        sourceUid: params.sourceUid,
        canonicalUid: params.canonicalUid,
        phoneNumber: params.phoneNumber,
        migratedAt,
        status: "noop_same_user",
      };
      await this.store.set(Collections.accountMigrations, migrationId, record);
      return record;
    }

    await this.transferAccountData(
      params.sourceUid,
      params.canonicalUid,
      params.phoneNumber,
      migratedAt,
    );
    const record = {
      id: migrationId,
      sourceUid: params.sourceUid,
      canonicalUid: params.canonicalUid,
      phoneNumber: params.phoneNumber,
      migratedAt,
      status: "completed",
    };
    await this.store.set(Collections.accountMigrations, migrationId, record);
    return record;
  }

  async updateAvatar(uid: string, payload: JsonMap): Promise<JsonMap> {
    await this.ensureUserBootstrap(uid);
    let avatarStoragePath = asString(payload.avatarStoragePath);
    let avatarUrl = asString(payload.avatarUrl);
    const avatarBase64 = asString(payload.avatarBase64);
    if (avatarBase64 && this.fileStorage) {
      const uploaded = await this.fileStorage.uploadBytes({
        fileName: asString(payload.fileName, `${uid}.jpg`),
        bytes: Buffer.from(avatarBase64, "base64"),
      });
      avatarStoragePath = uploaded.fileId;
      avatarUrl = uploaded.url;
    } else if (avatarStoragePath && this.fileStorage && !avatarUrl) {
      avatarUrl = await this.fileStorage.getTemporaryUrl(avatarStoragePath);
    }
    await this.store.merge(Collections.users, uid, {
      avatarStoragePath: avatarStoragePath || null,
      avatarUrl: avatarUrl || null,
      avatarPath: asString(payload.avatarPath) || null,
      updatedAt: nowIso(),
    });
    const user = await this.store.get(Collections.users, uid);
    const dormId = asString(user?.dormId);
    if (dormId) {
      const memberId = `${dormId}:${uid}`;
      const member = await this.store.get(Collections.dormMembers, memberId);
      if (member) {
        await this.store.merge(Collections.dormMembers, memberId, {
          avatarUrl: avatarUrl || null,
          lastActiveAt: nowIso(),
        });
      }
    }
    return withoutMeta((await this.store.get(Collections.users, uid)) ?? {});
  }

  async createDorm(
    uid: string,
    payload: JsonMap,
  ): Promise<{
    dormId: string;
    name: string;
    createdAt: string;
    memberStatus: string;
  }> {
    await this.ensureUserBootstrap(uid);
    const name = asString(payload.name).trim();
    if (!name) {
      throw new Error("Dorm name is required.");
    }
    const createdAt = nowIso();
    const dormId = `dorm-${randomUUID().slice(0, 8)}`;
    const rulesSettings = {
      ...defaultDormRulesSettings(),
      ...asMap(payload.rulesSettings),
    };
    const overview = asString(
      payload.overview,
      "新宿舍已经创建，接下来可以邀请舍友加入。",
    );
    await this.store.set(Collections.dorms, dormId, {
      id: dormId,
      name,
      overview,
      noiseDb: 28,
      status: "active",
      archivedAt: null,
      lightLabel: "适中",
      quietLabel: "可优化",
      rulesSettings,
      rules: buildDormRules(rulesSettings),
      createdAt,
      updatedAt: createdAt,
    });
    const user = await this.getUserProfile(uid);
    await this.store.merge(Collections.users, uid, {
      dormId,
      updatedAt: createdAt,
    });
    await this.store.set(Collections.dormMembers, `${dormId}:${uid}`, {
      dormId,
      uid,
      ...defaultDormMember(uid, user.displayName, user.avatarUrl),
      note: "已创建宿舍，等待邀请舍友加入。",
      lastActiveAt: createdAt,
    });
    await this.store.set(Collections.dormEvents, randomUUID(), {
      id: randomUUID(),
      dormId,
      type: "system",
      title: "宿舍已创建",
      detail: "你现在可以生成邀请码并邀请舍友加入。",
      actorUid: uid,
      createdAt,
    });
    return {
      dormId,
      name,
      createdAt,
      memberStatus: "quiet",
    };
  }

  async writeUserState(
    uid: string,
    patch: Partial<UserStateDoc>,
  ): Promise<void> {
    await this.ensureUserBootstrap(uid);
    await this.store.merge(Collections.userState, uid, {
      ...(patch as unknown as JsonMap),
      updatedAt: nowIso(),
    });
  }

  async buildPendingSleepMemoBanner(
    uid: string,
    sessionId: string,
  ): Promise<JsonMap | null> {
    await this.ensureUserBootstrap(uid);
    const records = await this.store.query(Collections.sleepCaptureRecords, {
      filters: { userId: uid, sessionId, type: "memo" },
      orderBy: { field: "createdAt", direction: "desc" },
      limit: 30,
    });
    const currentItems = records
      .map((doc) => asString(withoutMeta(doc).content).replace(/\s+/g, " ").trim())
      .filter((item) => item.length > 0);
    const currentState =
      ((await this.getUserState(uid)) as unknown as JsonMap) ?? {};
    const sleepCaptureState = asMap(currentState.sleepCapture);
    const pendingBanner = asMap(sleepCaptureState.pendingMemoBanner);
    const carryoverGroups = Array.isArray(pendingBanner.groups)
      ? pendingBanner.groups
          .map((item) => asMap(item))
          .filter((group) => Object.keys(group).length > 0)
          .map((group) => ({
            sessionId: asString(group.sessionId),
            label: "上次睡眠模式（未查收）",
            items: Array.isArray(group.items)
              ? group.items.map((item) => asString(item)).filter(Boolean)
              : [],
            isCarryover: true,
          }))
          .filter((group) => group.items.length > 0)
      : [];

    const nextGroups = [
      ...carryoverGroups,
      ...(currentItems.length > 0
        ? [
            {
              sessionId,
              label:
                carryoverGroups.length === 0
                  ? "本次睡眠模式"
                  : "本次睡眠模式（新）",
              items: currentItems,
              isCarryover: false,
            },
          ]
        : []),
    ];

    if (nextGroups.length === 0) {
      return null;
    }

    return {
      title: "事记内容查收",
      subtitle: "点击查看或 30min 后自动消除。",
      groups: nextGroups,
      createdAt: nowIso(),
    };
  }

  async clearPendingSleepMemoBanner(uid: string): Promise<void> {
    await this.writeUserState(uid, {
      sleepCapture: {
        pendingMemoBanner: null,
      },
    } as Partial<UserStateDoc>);
  }

  async writeCardSnapshot(
    uid: string,
    snapshot: CardSnapshotDoc,
  ): Promise<void> {
    await this.ensureUserBootstrap(uid);
    await this.store.set(
      Collections.cardSnapshots,
      `${uid}:${snapshot.surfaceId}`,
      {
        ...(snapshot as unknown as JsonMap),
        uid,
      },
    );
  }

  async writeAssistantRun(
    uid: string,
    runId: string,
    run: AssistantRunDoc,
  ): Promise<void> {
    await this.ensureUserBootstrap(uid);
    await this.store.set(Collections.assistantRuns, `${uid}:${runId}`, {
      ...(run as unknown as JsonMap),
      uid,
      runId,
    });
  }

  async setDreamAnalysis(
    entryId: string,
    analysis: DreamAnalysis,
  ): Promise<void> {
    await this.store.merge(Collections.dreamEntries, entryId, {
      ai: {
        summary: analysis.summary,
        dominantEmotion: analysis.dominantEmotion,
        suggestedFocus: analysis.suggestedFocus,
        sourceRefs: analysis.sourceRefs,
        updatedAt: nowIso(),
      },
    });
  }

  async upsertNotification(
    uid: string,
    notificationId: string,
    payload: JsonMap,
  ): Promise<void> {
    await this.ensureUserBootstrap(uid);
    await this.store.set(
      Collections.notifications,
      `${uid}:${notificationId}`,
      {
        ...payload,
        ownerUid: uid,
        notificationId,
      },
    );
  }

  async createDormInvite(
    uid: string,
    expiresInHours = 72,
  ): Promise<{
    inviteId: string;
    inviteCode: string;
    dormId: string;
    createdAt: string;
    expiresAt: string;
    memberCountSnapshot: number;
  }> {
    const user = await this.getUserProfile(uid);
    const dormId =
      user.dormId && user.dormId.trim().length > 0 ? user.dormId : "";
    if (!dormId) {
      throw new Error("Create or join a dorm before generating invites.");
    }
    await this.ensureDormExists(dormId, uid);
    const inviteId = randomUUID();
    const inviteCode = `DORM-${inviteId.slice(0, 6).toUpperCase()}`;
    const createdAt = nowIso();
    const expiresAt = new Date(
      Date.now() + Math.max(1, expiresInHours) * 60 * 60 * 1000,
    ).toISOString();
    const members = await this.store.query(Collections.dormMembers, {
      filters: { dormId },
    });
    await this.store.set(Collections.dormInvites, inviteId, {
      id: inviteId,
      dormId,
      code: inviteCode,
      createdByUid: uid,
      createdAt,
      expiresAt,
      status: "pending",
    });
    await this.store.set(Collections.dormEvents, randomUUID(), {
      id: randomUUID(),
      dormId,
      type: "invite",
      title: "已生成邀请码",
      detail: `邀请码 ${inviteCode} 已准备好，可以分享给舍友。`,
      actorUid: uid,
      createdAt,
    });
    return {
      inviteId,
      inviteCode,
      dormId,
      createdAt,
      expiresAt,
      memberCountSnapshot: members.length,
    };
  }

  async acceptDormInvite(
    uid: string,
    inviteCode: string,
  ): Promise<{ dormId: string; acceptedAt: string }> {
    const matches = await this.store.query(Collections.dormInvites, {
      filters: { code: inviteCode },
      limit: 1,
    });
    if (matches.length === 0) {
      throw new Error(`Invite code "${inviteCode}" was not found.`);
    }
    const invite = matches[0];
    const dormId = asString(invite.dormId);
    if (!dormId) {
      throw new Error("Invite is missing dormId.");
    }
    if (asString(invite.status, "pending") !== "pending") {
      throw new Error("Invite has already been used or closed.");
    }
    if (Date.parse(asString(invite.expiresAt, nowIso())) < Date.now()) {
      throw new Error("Invite has expired.");
    }
    const acceptedAt = nowIso();
    const user = await this.getUserProfile(uid);
    await this.store.merge(Collections.dormInvites, asString(invite._id), {
      status: "accepted",
      acceptedByUid: uid,
      acceptedAt,
    });
    await this.store.merge(Collections.users, uid, {
      dormId,
      updatedAt: acceptedAt,
    });
    await this.store.set(Collections.dormMembers, `${dormId}:${uid}`, {
      dormId,
      uid,
      ...defaultDormMember(uid, user.displayName, user.avatarUrl),
      note: "已通过邀请码加入宿舍。",
      lastActiveAt: acceptedAt,
    });
    await this.store.set(Collections.dormEvents, randomUUID(), {
      id: randomUUID(),
      dormId,
      type: "invite",
      title: "舍友已加入宿舍",
      detail: `邀请码 ${inviteCode} 已被成功使用。`,
      actorUid: uid,
      createdAt: acceptedAt,
    });
    return { dormId, acceptedAt };
  }

  async renameDorm(uid: string, name: string): Promise<JsonMap> {
    const user = await this.getUserProfile(uid);
    const dormId = user.dormId ? user.dormId.trim() : "";
    if (!dormId) {
      throw new Error("Create or join a dorm before renaming it.");
    }
    await this.store.merge(Collections.dorms, dormId, {
      name: name.trim(),
      updatedAt: nowIso(),
    });
    return withoutMeta((await this.store.get(Collections.dorms, dormId)) ?? {});
  }

  async leaveDorm(uid: string): Promise<JsonMap> {
    const user = await this.getUserProfile(uid);
    const dormId = user.dormId ? user.dormId.trim() : "";
    if (!dormId) {
      return { dormId: null, archived: false };
    }
    const memberId = `${dormId}:${uid}`;
    await this.store.delete(Collections.dormMembers, memberId);
    await this.store.merge(Collections.users, uid, {
      dormId: null,
      updatedAt: nowIso(),
    });
    const remainingMembers = await this.store.query(Collections.dormMembers, {
      filters: { dormId },
    });
    if (remainingMembers.length === 0) {
      await this.store.merge(Collections.dorms, dormId, {
        status: "archived",
        archivedAt: nowIso(),
        updatedAt: nowIso(),
      });
      const invites = await this.store.query(Collections.dormInvites, {
        filters: { dormId },
      });
      await Promise.all(
        invites.map((invite) =>
          this.store.merge(Collections.dormInvites, asString(invite._id), {
            status: "revoked",
          }),
        ),
      );
      return { dormId, archived: true };
    }
    return { dormId, archived: false };
  }

  async saveDormRules(uid: string, settings: JsonMap): Promise<JsonMap> {
    const user = await this.getUserProfile(uid);
    const dormId = user.dormId ? user.dormId.trim() : "";
    if (!dormId) {
      throw new Error("Create or join a dorm before updating rules.");
    }
    const dormDoc = withoutMeta(
      ((await this.store.get(Collections.dorms, dormId)) ??
        defaultDormDoc(dormId)) as JsonMap,
    );
    if (dormDoc.pendingRuleProposal) {
      throw new Error("There is already a pending dorm rule proposal.");
    }
    const members = await this.store.query(Collections.dormMembers, {
      filters: { dormId },
      orderBy: { field: "lastActiveAt", direction: "desc" },
    });
    const nextSettings = {
      ...defaultDormRulesSettings(),
      ...asMap(settings),
    };
    const proposedRules = buildDormRules(nextSettings);
    const reviewerUids = members.map((member) => asString(member.uid)).filter(Boolean);
    const proposerName =
      asString(
        members.find((member) => asString(member.uid) == uid)?.name,
        user.displayName,
      ) || "舍友";
    const createdAt = nowIso();
    const proposalId = randomUUID();
    const proposal = {
      id: proposalId,
      proposedSettings: nextSettings,
      proposedRules,
      proposerUid: uid,
      proposerName,
      createdAt,
      reviewerUids,
      approvedUids: [uid],
      rejectedByUid: null,
      rejectedReason: null,
      resolvedAt: null,
    };
    const pendingReviewers = reviewerUids.filter((memberUid) => memberUid && memberUid !== uid);
    if (pendingReviewers.length === 0) {
      await this.store.merge(Collections.dorms, dormId, {
        rulesSettings: nextSettings,
        rules: proposedRules,
        pendingRuleProposal: null,
        updatedAt: createdAt,
      });
      await this.store.set(Collections.dormEvents, randomUUID(), {
        id: randomUUID(),
        dormId,
        type: "ruleUpdate",
        title: "宿舍公约已更新",
        detail: `当前作息标签：${asStringArray(nextSettings.routineTags).join("、") || "未设置"}`,
        actorUid: uid,
        createdAt,
      });
    } else {
      await this.store.merge(Collections.dorms, dormId, {
        pendingRuleProposal: proposal,
        updatedAt: createdAt,
      });
      await this.store.set(Collections.dormEvents, randomUUID(), {
        id: randomUUID(),
        dormId,
        type: "ruleUpdate",
        title: "有新宿舍公约待确认",
        detail: `${proposerName} 提交了新的宿舍规则，等待室友确认。`,
        actorUid: uid,
        createdAt,
      });
      await Promise.all(
        pendingReviewers.map((targetUid) =>
          this.store.set(Collections.notifications, `${targetUid}:dorm-rule-${proposalId}`, {
            id: `dorm-rule-${proposalId}`,
            category: "dorm",
            title: "宿舍公约有新规则待确认",
            body: `${proposerName} 更新了宿舍公约，等你确认后才会正式生效。`,
            route: "/dorm/rules?review=1",
            createdAt,
            ownerUid: targetUid,
            readAt: null,
          }),
        ),
      );
    }
    return withoutMeta((await this.store.get(Collections.dorms, dormId)) ?? {});
  }

  async approveDormRules(
    uid: string,
    proposalId: string,
  ): Promise<{ dormId: string; applied: boolean; approvedAt: string }> {
    const user = await this.getUserProfile(uid);
    const dormId = user.dormId ? user.dormId.trim() : "";
    if (!dormId) {
      throw new Error("Create or join a dorm before approving rules.");
    }
    const dormDoc = withoutMeta(
      ((await this.store.get(Collections.dorms, dormId)) ??
        defaultDormDoc(dormId)) as JsonMap,
    );
    const proposal = asMap(dormDoc.pendingRuleProposal);
    if (asString(proposal.id) !== proposalId || !proposalId.trim()) {
      throw new Error("Dorm rule proposal was not found.");
    }
    const reviewerUids = asStringArray(proposal.reviewerUids);
    if (!reviewerUids.includes(uid)) {
      throw new Error("You are not a reviewer of this dorm rule proposal.");
    }
    const approvedUids = new Set(asStringArray(proposal.approvedUids));
    approvedUids.add(uid);
    const approvedAt = nowIso();
    const proposedSettings = {
      ...defaultDormRulesSettings(),
      ...asMap(proposal.proposedSettings),
    };
    const proposedRules = Array.isArray(proposal.proposedRules)
      ? proposal.proposedRules.map((item) => asMap(item))
      : buildDormRules(proposedSettings);
    const actorName =
      asString(
        (
          await this.store.get(Collections.dormMembers, `${dormId}:${uid}`)
        )?.name,
        user.displayName,
      ) || "舍友";
    const allApproved = reviewerUids.every((reviewerUid) => approvedUids.has(reviewerUid));
    if (allApproved) {
      await this.store.merge(Collections.dorms, dormId, {
        rulesSettings: proposedSettings,
        rules: proposedRules,
        pendingRuleProposal: null,
        updatedAt: approvedAt,
      });
      await this.store.set(Collections.dormEvents, randomUUID(), {
        id: randomUUID(),
        dormId,
        type: "ruleUpdate",
        title: "新宿舍公约已生效",
        detail: "全部室友已同意，新的宿舍公约开始执行。",
        actorUid: uid,
        createdAt: approvedAt,
      });
      return { dormId, applied: true, approvedAt };
    }
    await this.store.merge(Collections.dorms, dormId, {
      pendingRuleProposal: {
        ...proposal,
        approvedUids: Array.from(approvedUids),
      },
      updatedAt: approvedAt,
    });
    await this.store.set(Collections.dormEvents, randomUUID(), {
      id: randomUUID(),
      dormId,
      type: "ruleUpdate",
      title: "室友已同意新公约",
      detail: `${actorName} 已同意这次规则调整。`,
      actorUid: uid,
      createdAt: approvedAt,
    });
    return { dormId, applied: false, approvedAt };
  }

  async rejectDormRules(
    uid: string,
    proposalId: string,
    reason: string,
  ): Promise<{ dormId: string; rejectedAt: string; reason: string }> {
    const user = await this.getUserProfile(uid);
    const dormId = user.dormId ? user.dormId.trim() : "";
    if (!dormId) {
      throw new Error("Create or join a dorm before rejecting rules.");
    }
    const trimmedReason = reason.trim();
    if (!trimmedReason) {
      throw new Error("Rejection reason is required.");
    }
    const dormDoc = withoutMeta(
      ((await this.store.get(Collections.dorms, dormId)) ??
        defaultDormDoc(dormId)) as JsonMap,
    );
    const proposal = asMap(dormDoc.pendingRuleProposal);
    if (asString(proposal.id) !== proposalId || !proposalId.trim()) {
      throw new Error("Dorm rule proposal was not found.");
    }
    const reviewerUids = asStringArray(proposal.reviewerUids);
    if (!reviewerUids.includes(uid)) {
      throw new Error("You are not a reviewer of this dorm rule proposal.");
    }
    const rejectedAt = nowIso();
    const actorName =
      asString(
        (
          await this.store.get(Collections.dormMembers, `${dormId}:${uid}`)
        )?.name,
        user.displayName,
      ) || "舍友";
    await this.store.merge(Collections.dorms, dormId, {
      pendingRuleProposal: null,
      updatedAt: rejectedAt,
    });
    await this.store.set(Collections.dormEvents, randomUUID(), {
      id: randomUUID(),
      dormId,
      type: "ruleUpdate",
      title: "新宿舍公约未通过",
      detail: `${actorName} 提出异议：${trimmedReason}`,
      actorUid: uid,
      createdAt: rejectedAt,
    });
    const proposerUid = asString(proposal.proposerUid);
    if (proposerUid && proposerUid !== uid) {
      await this.store.set(
        Collections.notifications,
        `${proposerUid}:dorm-rule-rejected-${proposalId}`,
        {
          id: `dorm-rule-rejected-${proposalId}`,
          category: "dorm",
          title: "你的宿舍公约提案未通过",
          body: `${actorName} 提出了异议：${trimmedReason}`,
          route: "/dorm/status",
          createdAt: rejectedAt,
          ownerUid: proposerUid,
          readAt: null,
        },
      );
    }
    return { dormId, rejectedAt, reason: trimmedReason };
  }

  async sendGentleDormReminder(
    uid: string,
    targetUid: string,
    anonymous = true,
    message = "",
  ): Promise<{ targetUid: string; createdAt: string }> {
    const user = await this.getUserProfile(uid);
    const dormId = user.dormId ? user.dormId.trim() : "";
    if (!dormId) {
      throw new Error("Create or join a dorm before sending reminders.");
    }
    if (!targetUid || targetUid.trim() === uid) {
      throw new Error("Select a roommate before sending the reminder.");
    }
    const trimmedMessage = message.trim();
    if (!trimmedMessage) {
      throw new Error("Select or enter a reminder before sending.");
    }
    const targetMember = await this.store.get(
      Collections.dormMembers,
      `${dormId}:${targetUid}`,
    );
    if (!targetMember) {
      throw new Error("The selected roommate was not found in the current dorm.");
    }
    const actorMember =
      (await this.store.get(Collections.dormMembers, `${dormId}:${uid}`)) ??
      defaultDormMember(uid, user.displayName, user.avatarUrl);
    const createdAt = nowIso();
    const senderName = anonymous
      ? "您的舍友"
      : asString(actorMember.name, user.displayName || "舍友");
    await this.store.set(Collections.notifications, `${targetUid}:gentle-${createdAt}`, {
      id: `gentle-${createdAt}`,
      category: "dorm",
      title: "舍友提醒你稍微放轻一点",
      body: `${senderName} 给你发来一条温和提醒：${trimmedMessage}`,
      route: "/dorm",
      createdAt,
      ownerUid: targetUid,
      readAt: null,
    });
    await this.store.set(Collections.dormEvents, randomUUID(), {
      id: randomUUID(),
      dormId,
      type: "notification",
      title: "已发送委婉提醒",
      detail: `已向 ${asString(targetMember.name, "舍友")} 发送站内提醒。`,
      actorUid: uid,
      createdAt,
    });
    return { targetUid, createdAt };
  }

  async writeAssistantThreadSummary(
    uid: string,
    summary: AssistantThreadSummaryDoc,
  ): Promise<void> {
    await this.ensureUserBootstrap(uid);
    await this.store.set(
      Collections.assistantThreadSummaries,
      summary.threadId,
      summary as unknown as JsonMap,
    );
  }

  async upsertAssistantMemoryItems(
    uid: string,
    items: AssistantMemoryItem[],
  ): Promise<void> {
    await this.ensureUserBootstrap(uid);
    for (const item of items) {
      await this.store.set(Collections.assistantMemoryItems, item.id, {
        ...(item as unknown as JsonMap),
        userId: uid,
      });
    }
  }

  private async transferAccountData(
    sourceUid: string,
    canonicalUid: string,
    phoneNumber: string,
    migratedAt: string,
  ): Promise<void> {
    const sourceUser =
      (await this.store.get(Collections.users, sourceUid)) ??
      defaultUserProfile(sourceUid, null);
    const canonicalUser =
      (await this.store.get(Collections.users, canonicalUid)) ??
      defaultUserProfile(canonicalUid, null);
    const sourceDefaults = defaultUserProfile(sourceUid, null);
    const canonicalDefaults = defaultUserProfile(canonicalUid, null);
    const mergedDormId =
      this.preferString(
        canonicalUser.dormId,
        sourceUser.dormId,
        canonicalDefaults.dormId,
      ) || null;

    await this.store.set(Collections.users, canonicalUid, {
      ...withoutMeta(canonicalUser),
      uid: canonicalUid,
      displayName: this.preferString(
        canonicalUser.displayName,
        sourceUser.displayName,
        canonicalDefaults.displayName,
      ),
      tagline: this.preferString(
        canonicalUser.tagline,
        sourceUser.tagline,
        canonicalDefaults.tagline,
      ),
      role: this.preferString(
        canonicalUser.role,
        sourceUser.role,
        canonicalDefaults.role,
      ),
      dormId: mergedDormId,
      phoneNumber,
      phoneLinkedAt: migratedAt,
      avatarUrl: this.preferString(
        canonicalUser.avatarUrl,
        sourceUser.avatarUrl,
        canonicalDefaults.avatarUrl,
      ),
      avatarStoragePath: this.preferString(
        canonicalUser.avatarStoragePath,
        sourceUser.avatarStoragePath,
        canonicalDefaults.avatarStoragePath,
      ),
      avatarPath: this.preferString(
        canonicalUser.avatarPath,
        sourceUser.avatarPath,
        canonicalDefaults.avatarPath,
      ),
      avatarFallbackSeed: this.preferString(
        canonicalUser.avatarFallbackSeed,
        sourceUser.avatarFallbackSeed,
        canonicalDefaults.avatarFallbackSeed,
      ),
      updatedAt: migratedAt,
    });
    await this.store.merge(Collections.users, sourceUid, {
      mergedIntoUid: canonicalUid,
      mergedAt: migratedAt,
      dormId: null,
      updatedAt: migratedAt,
    });

    const sourceSettings =
      (await this.store.get(Collections.userSettings, sourceUid)) ??
      defaultUserSettings();
    const canonicalSettings =
      (await this.store.get(Collections.userSettings, canonicalUid)) ??
      defaultUserSettings();
    const defaultSettings = defaultUserSettings();
    await this.store.set(Collections.userSettings, canonicalUid, {
      ...withoutMeta(canonicalSettings),
      sleepGoalHours: this.preferNumber(
        canonicalSettings.sleepGoalHours,
        sourceSettings.sleepGoalHours,
        defaultSettings.sleepGoalHours,
      ),
      bedtimeReminderEnabled: this.preferBoolean(
        canonicalSettings.bedtimeReminderEnabled,
        sourceSettings.bedtimeReminderEnabled,
        defaultSettings.bedtimeReminderEnabled,
      ),
      morningReminderEnabled: this.preferBoolean(
        canonicalSettings.morningReminderEnabled,
        sourceSettings.morningReminderEnabled,
        defaultSettings.morningReminderEnabled,
      ),
      dormAlertsEnabled: this.preferBoolean(
        canonicalSettings.dormAlertsEnabled,
        sourceSettings.dormAlertsEnabled,
        defaultSettings.dormAlertsEnabled,
      ),
      bedtimeReminder: this.preferMap(
        canonicalSettings.bedtimeReminder,
        sourceSettings.bedtimeReminder,
        defaultSettings.bedtimeReminder,
      ),
      preferredTrackTitle: this.preferString(
        canonicalSettings.preferredTrackTitle,
        sourceSettings.preferredTrackTitle,
        defaultSettings.preferredTrackTitle,
      ),
      smartSuggestionsEnabled: this.preferBoolean(
        canonicalSettings.smartSuggestionsEnabled,
        sourceSettings.smartSuggestionsEnabled,
        defaultSettings.smartSuggestionsEnabled,
      ),
      selectedNightMood: this.preferString(
        canonicalSettings.selectedNightMood,
        sourceSettings.selectedNightMood,
        defaultSettings.selectedNightMood,
      ),
      updatedAt: migratedAt,
    });

    const sourceAssistantProfile =
      (await this.store.get(Collections.assistantProfiles, sourceUid)) ??
      defaultAssistantProfile(sourceUid);
    const canonicalAssistantProfile =
      (await this.store.get(Collections.assistantProfiles, canonicalUid)) ??
      defaultAssistantProfile(canonicalUid);
    const defaultAssistant = defaultAssistantProfile(canonicalUid);
    await this.store.set(Collections.assistantProfiles, canonicalUid, {
      ...withoutMeta(canonicalAssistantProfile),
      userId: canonicalUid,
      assistantName: this.preferString(
        canonicalAssistantProfile.assistantName,
        sourceAssistantProfile.assistantName,
        defaultAssistant.assistantName,
      ),
      identityPrompt: this.preferString(
        canonicalAssistantProfile.identityPrompt,
        sourceAssistantProfile.identityPrompt,
        defaultAssistant.identityPrompt,
      ),
      tone: this.preferString(
        canonicalAssistantProfile.tone,
        sourceAssistantProfile.tone,
        defaultAssistant.tone,
      ),
      relationshipRole: this.preferString(
        canonicalAssistantProfile.relationshipRole,
        sourceAssistantProfile.relationshipRole,
        defaultAssistant.relationshipRole,
      ),
      updatedAt: migratedAt,
    });

    const sourceState =
      (await this.store.get(Collections.userState, sourceUid)) ??
      null;
    const canonicalState =
      (await this.store.get(Collections.userState, canonicalUid)) ??
      null;
    if (!canonicalState && sourceState) {
      await this.store.set(Collections.userState, canonicalUid, {
        ...withoutMeta(sourceState),
        updatedAt: migratedAt,
      });
    }

    await this.transferSessions(sourceUid, canonicalUid, migratedAt);
    await this.transferDreamEntries(sourceUid, canonicalUid, migratedAt);
    await this.transferNotifications(sourceUid, canonicalUid, migratedAt);
    await this.transferCardSnapshots(sourceUid, canonicalUid, migratedAt);
    const threadIdMap = await this.transferAssistantThreads(
      sourceUid,
      canonicalUid,
      migratedAt,
    );
    await this.transferAssistantMessages(threadIdMap, migratedAt);
    await this.transferThreadSummaries(threadIdMap);
    await this.transferAssistantMemory(sourceUid, canonicalUid, migratedAt);
    if (mergedDormId) {
      await this.transferDormMembership(
        sourceUid,
        canonicalUid,
        mergedDormId,
        migratedAt,
      );
    }
  }

  private async transferSessions(
    sourceUid: string,
    canonicalUid: string,
    migratedAt: string,
  ): Promise<void> {
    const sessions = await this.store.query(Collections.sleepSessions, {
      filters: { uid: sourceUid },
    });
    for (const session of sessions) {
      const sessionId = asString(session._id, asString(session.id));
      const canonicalExisting = await this.store.get(
        Collections.sleepSessions,
        sessionId,
      );
      if (canonicalExisting) {
        continue;
      }
      await this.store.set(Collections.sleepSessions, sessionId, {
        ...withoutMeta(session),
        id: asString(session.id, sessionId),
        uid: canonicalUid,
        updatedAt: migratedAt,
      });
    }
  }

  private async transferDreamEntries(
    sourceUid: string,
    canonicalUid: string,
    migratedAt: string,
  ): Promise<void> {
    const entries = await this.store.query(Collections.dreamEntries, {
      filters: { userId: sourceUid },
    });
    for (const entry of entries) {
      const entryId = asString(entry._id, asString(entry.id));
      const canonicalExisting = await this.store.get(
        Collections.dreamEntries,
        entryId,
      );
      if (canonicalExisting) {
        continue;
      }
      await this.store.set(Collections.dreamEntries, entryId, {
        ...withoutMeta(entry),
        id: asString(entry.id, entryId),
        userId: canonicalUid,
        updatedAt: migratedAt,
      });
    }
  }

  private async transferNotifications(
    sourceUid: string,
    canonicalUid: string,
    migratedAt: string,
  ): Promise<void> {
    const notifications = await this.store.query(Collections.notifications, {
      filters: { ownerUid: sourceUid },
    });
    for (const notification of notifications) {
      const originalId = asString(notification.id, asString(notification._id));
      const nextId =
        (await this.store.get(Collections.notifications, `${canonicalUid}:${originalId}`)) ==
        null
            ? originalId
            : `${originalId}-${sourceUid.slice(0, 6)}`;
      await this.store.set(
        Collections.notifications,
        `${canonicalUid}:${nextId}`,
        {
          ...withoutMeta(notification),
          id: nextId,
          ownerUid: canonicalUid,
          createdAt: asString(notification.createdAt, migratedAt),
        },
      );
    }
  }

  private async transferCardSnapshots(
    sourceUid: string,
    canonicalUid: string,
    migratedAt: string,
  ): Promise<void> {
    const snapshots = await this.store.query(Collections.cardSnapshots, {
      filters: { uid: sourceUid },
    });
    for (const snapshot of snapshots) {
      const surfaceId = asString(snapshot.surfaceId);
      if (!surfaceId) {
        continue;
      }
      const existing = await this.store.get(
        Collections.cardSnapshots,
        `${canonicalUid}:${surfaceId}`,
      );
      if (existing) {
        continue;
      }
      await this.store.set(Collections.cardSnapshots, `${canonicalUid}:${surfaceId}`, {
        ...withoutMeta(snapshot),
        uid: canonicalUid,
        generatedAt: asString(snapshot.generatedAt, migratedAt),
      });
    }
  }

  private async transferAssistantThreads(
    sourceUid: string,
    canonicalUid: string,
    migratedAt: string,
  ): Promise<Map<string, string>> {
    const threads = await this.store.query(Collections.assistantThreads, {
      filters: { userId: sourceUid },
    });
    const threadIdMap = new Map<string, string>();
    for (const thread of threads) {
      const oldId = asString(thread._id, asString(thread.id));
      let nextId = oldId;
      if (await this.store.get(Collections.assistantThreads, nextId)) {
        nextId = `${oldId}-${sourceUid.slice(0, 6)}`;
      }
      threadIdMap.set(oldId, nextId);
      await this.store.set(Collections.assistantThreads, nextId, {
        ...withoutMeta(thread),
        id: nextId,
        userId: canonicalUid,
        updatedAt: migratedAt,
      });
    }
    return threadIdMap;
  }

  private async transferAssistantMessages(
    threadIdMap: Map<string, string>,
    migratedAt: string,
  ): Promise<void> {
    for (const [oldThreadId, newThreadId] of threadIdMap.entries()) {
      const messages = await this.store.query(Collections.assistantMessages, {
        filters: { threadId: oldThreadId },
      });
      for (const message of messages) {
        const messageId = asString(message.id, randomUUID());
        await this.store.set(
          Collections.assistantMessages,
          `${newThreadId}:${messageId}`,
          {
            ...withoutMeta(message),
            id: messageId,
            threadId: newThreadId,
            createdAt: asString(message.createdAt, migratedAt),
          },
        );
      }
    }
  }

  private async transferThreadSummaries(
    threadIdMap: Map<string, string>,
  ): Promise<void> {
    for (const [oldThreadId, newThreadId] of threadIdMap.entries()) {
      const summary = await this.store.get(
        Collections.assistantThreadSummaries,
        oldThreadId,
      );
      if (!summary) {
        continue;
      }
      await this.store.set(Collections.assistantThreadSummaries, newThreadId, {
        ...withoutMeta(summary),
        threadId: newThreadId,
      });
    }
  }

  private async transferAssistantMemory(
    sourceUid: string,
    canonicalUid: string,
    migratedAt: string,
  ): Promise<void> {
    const items = await this.store.query(Collections.assistantMemoryItems, {
      filters: { userId: sourceUid },
    });
    for (const item of items) {
      const nextId = randomUUID();
      await this.store.set(Collections.assistantMemoryItems, nextId, {
        ...withoutMeta(item),
        id: nextId,
        userId: canonicalUid,
        updatedAt: migratedAt,
      });
    }
  }

  private async transferDormMembership(
    sourceUid: string,
    canonicalUid: string,
    dormId: string,
    migratedAt: string,
  ): Promise<void> {
    const sourceMemberId = `${dormId}:${sourceUid}`;
    const sourceMember = await this.store.get(Collections.dormMembers, sourceMemberId);
    if (sourceMember) {
      await this.store.set(Collections.dormMembers, `${dormId}:${canonicalUid}`, {
        ...withoutMeta(sourceMember),
        uid: canonicalUid,
        lastActiveAt: migratedAt,
      });
      await this.store.delete(Collections.dormMembers, sourceMemberId);
    }
    const invites = await this.store.query(Collections.dormInvites, {
      filters: { dormId },
    });
    for (const invite of invites) {
      const patch: JsonMap = {};
      if (asString(invite.createdByUid) == sourceUid) {
        patch.createdByUid = canonicalUid;
      }
      if (asString(invite.acceptedByUid) == sourceUid) {
        patch.acceptedByUid = canonicalUid;
      }
      if (Object.keys(patch).length > 0) {
        await this.store.merge(Collections.dormInvites, asString(invite._id), patch);
      }
    }
  }

  private preferString(
    primary: unknown,
    fallback: unknown,
    defaultValue: unknown,
  ): string | null {
    const primaryValue = asString(primary).trim();
    const fallbackValue = asString(fallback).trim();
    const defaultString = asString(defaultValue).trim();
    if (primaryValue && primaryValue !== defaultString) {
      return primaryValue;
    }
    if (fallbackValue) {
      return fallbackValue;
    }
    return primaryValue || defaultString || null;
  }

  private preferNumber(
    primary: unknown,
    fallback: unknown,
    defaultValue: unknown,
  ): number {
    const primaryValue = asNumber(primary, asNumber(defaultValue));
    if (primaryValue !== asNumber(defaultValue)) {
      return primaryValue;
    }
    const fallbackValue = asNumber(fallback, primaryValue);
    return fallbackValue;
  }

  private preferBoolean(
    primary: unknown,
    fallback: unknown,
    defaultValue: unknown,
  ): boolean {
    const primaryValue = asBoolean(primary, asBoolean(defaultValue));
    if (primaryValue !== asBoolean(defaultValue)) {
      return primaryValue;
    }
    return asBoolean(fallback, primaryValue);
  }

  private preferMap(
    primary: unknown,
    fallback: unknown,
    defaultValue: unknown,
  ): JsonMap {
    const primaryValue = asMap(primary);
    if (JSON.stringify(primaryValue) !== JSON.stringify(asMap(defaultValue))) {
      return primaryValue;
    }
    const fallbackValue = asMap(fallback);
    return Object.keys(fallbackValue).length > 0 ? fallbackValue : primaryValue;
  }

  private async readAssistantThreadSummary(
    threadId: string | null | undefined,
  ): Promise<AssistantThreadSummaryDoc | null> {
    if (!threadId) {
      return null;
    }
    const doc = await this.store.get(Collections.assistantThreadSummaries, threadId);
    if (!doc) {
      return null;
    }
    const value = withoutMeta(doc);
    return {
      threadId: asString(value.threadId, threadId),
      summary: asString(value.summary),
      keywords: asStringArray(value.keywords),
      updatedAt: asString(value.updatedAt, nowIso()),
    };
  }

  private async listAssistantMemory(uid: string): Promise<AssistantMemoryItem[]> {
    const docs = await this.store.query(Collections.assistantMemoryItems, {
      filters: { userId: uid },
      orderBy: { field: "updatedAt", direction: "desc" },
      limit: 20,
    });
    return docs.map((doc) => {
      const value = withoutMeta(doc);
      return {
        id: asString(value.id, asString(value._id)),
        kind: asString(value.kind, "profile"),
        content: asString(value.content),
        sourceThreadId: asString(value.sourceThreadId) || null,
        salience: asNumber(value.salience, 0.5),
        lastUsedAt: asString(value.lastUsedAt) || null,
        sourceRefs: asStringArray(value.sourceRefs),
        createdAt: asString(value.createdAt, nowIso()),
        updatedAt: asString(value.updatedAt, nowIso()),
      };
    });
  }

  private async ensureUserBootstrap(uid: string): Promise<void> {
    if (!uid) {
      return;
    }
    const existingUser = await this.store.get(Collections.users, uid);
    let resolvedDormId = asString(existingUser?.dormId);
    if (!existingUser) {
      await this.store.set(
        Collections.users,
        uid,
        defaultUserProfile(uid, null),
      );
      resolvedDormId = "";
    } else if (
      resolvedDormId &&
      (await this.shouldTreatDormAsUnbound(uid, resolvedDormId))
    ) {
      await this.store.merge(Collections.users, uid, {
        dormId: null,
        updatedAt: nowIso(),
      });
      resolvedDormId = "";
    }
    const existingSettings = await this.store.get(
      Collections.userSettings,
      uid,
    );
    if (!existingSettings) {
      await this.store.set(
        Collections.userSettings,
        uid,
        defaultUserSettings(),
      );
    }
    const existingAssistantProfile = await this.store.get(
      Collections.assistantProfiles,
      uid,
    );
    if (!existingAssistantProfile) {
      await this.store.set(
        Collections.assistantProfiles,
        uid,
        defaultAssistantProfile(uid),
      );
    }
    if (resolvedDormId) {
      await this.ensureDormExists(resolvedDormId, uid);
    }
  }

  private async ensureDormExists(dormId: string, uid: string): Promise<void> {
    if (!dormId) {
      return;
    }
    const user =
      (await this.store.get(Collections.users, uid)) ??
      defaultUserProfile(uid, dormId);
    const dorm = await this.store.get(Collections.dorms, dormId);
    if (!dorm) {
      await this.store.set(Collections.dorms, dormId, defaultDormDoc(dormId));
    }
    const memberId = `${dormId}:${uid}`;
    const member = await this.store.get(Collections.dormMembers, memberId);
    if (!member) {
      await this.store.set(Collections.dormMembers, memberId, {
        dormId,
        ...defaultDormMember(
          uid,
          asString(user.displayName, "宿舍成员"),
          asString(user.avatarUrl),
          asString(user.equippedBadgeId) ||
              asStringArray(user.earnedBadgeIds).slice(-1)[0] ||
              null,
        ),
      });
    }
  }

  private async shouldTreatDormAsUnbound(
    uid: string,
    dormId: string,
  ): Promise<boolean> {
    if (!dormId || dormId !== this.defaultDormId(uid)) {
      return false;
    }
    const [dormDoc, members, invites] = await Promise.all([
      this.store.get(Collections.dorms, dormId),
      this.store.query(Collections.dormMembers, { filters: { dormId } }),
      this.store.query(Collections.dormInvites, {
        filters: { dormId },
        limit: 5,
      }),
    ]);
    const fallbackDorm = defaultDormDoc(dormId);
    const hasSingleMember =
      members.length <= 1 &&
      members.every((member) => asString(member.uid) == uid);
    const hasInviteHistory = invites.length > 0;
    const looksLikeSystemDorm =
      asString(dormDoc?.name) == asString(fallbackDorm.name) &&
      asString(dormDoc?.overview) == asString(fallbackDorm.overview);
    return hasSingleMember && !hasInviteHistory && looksLikeSystemDorm;
  }

  private async readUserProfile(uid: string): Promise<ContextUserProfile> {
    const doc = withoutMeta(
      (await this.store.get(Collections.users, uid)) ?? {},
    );
    const dormId = asString(doc.dormId);
    const avatarStoragePath = asString(doc.avatarStoragePath) || null;
    let avatarUrl = asString(doc.avatarUrl) || null;
    if (avatarStoragePath && this.fileStorage) {
      try {
        avatarUrl = await this.fileStorage.getTemporaryUrl(avatarStoragePath);
      } catch {
        avatarUrl = avatarUrl || null;
      }
    }
    return {
      uid,
      displayName: asString(doc.displayName, "宿舍成员"),
      tagline: asString(doc.tagline, "AI 睡眠陪伴中"),
      role: asString(doc.role, "宿舍睡眠优化成员"),
      earnedBadgeIds: asStringArray(doc.earnedBadgeIds),
      equippedBadgeId: asString(doc.equippedBadgeId) || null,
      showDormPulseBadge: asBoolean(doc.showDormPulseBadge, true),
      selectedDormBadgeId: asString(doc.selectedDormBadgeId) || null,
      dormId: dormId || null,
      phoneNumber: asString(doc.phoneNumber) || null,
      phoneLinkedAt: asString(doc.phoneLinkedAt) || null,
      avatarUrl,
      avatarStoragePath,
    };
  }

  private async readUserSettings(uid: string): Promise<ContextUserSettings> {
    const doc = withoutMeta(
      (await this.store.get(Collections.userSettings, uid)) ?? {},
    );
    return {
      sleepGoalHours: asNumber(doc.sleepGoalHours, 7.5),
      preferredTrackTitle: asString(doc.preferredTrackTitle, "深海海浪"),
      smartSuggestionsEnabled: asBoolean(doc.smartSuggestionsEnabled, true),
      selectedNightMood: asString(doc.selectedNightMood),
      bedtimeReminderEnabled: asBoolean(doc.bedtimeReminderEnabled, true),
      morningReminderEnabled: asBoolean(doc.morningReminderEnabled, true),
      dormAlertsEnabled: asBoolean(doc.dormAlertsEnabled, true),
      bedtimeReminder: asMap(doc.bedtimeReminder),
    } as unknown as ContextUserSettings;
  }

  private defaultDormId(uid: string): string {
    const suffix = uid.slice(0, 8).toLowerCase() || "guest";
    return `dorm-${suffix}`;
  }
}

let sharedMemoryRepository: FirestoreRepository | null = null;

export function createRepositoryFromEnv(
  env: NodeJS.ProcessEnv = process.env,
): FirestoreRepository {
  const envId =
    env.CLOUDBASE_ENV_ID?.trim() ||
    env.TCB_ENV?.trim() ||
    env.SCF_NAMESPACE?.trim() ||
    "";
  if (envId) {
    logRepo(`createRepositoryFromEnv using CloudBase env=${envId}`);
    return new FirestoreRepository(
      new CloudBaseNoSqlStore(envId),
      new CloudBaseFileStorage(envId),
    );
  }
  if (!sharedMemoryRepository) {
    logRepo("createRepositoryFromEnv using in-memory store");
    sharedMemoryRepository = new FirestoreRepository(
      new InMemoryDocumentStore(),
    );
  }
  return sharedMemoryRepository;
}
