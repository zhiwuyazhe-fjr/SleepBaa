import assert from "node:assert/strict";
import test from "node:test";
import { FirestoreRepository } from "../src/repositories/firestore_repositories";

type JsonMap = Record<string, unknown>;
type SortDirection = "asc" | "desc";

class TestDocumentStore {
  private readonly collections = new Map<string, Map<string, JsonMap>>();

  async get(collection: string, id: string): Promise<JsonMap | null> {
    return this.clone(this.ensureCollection(collection).get(id) ?? null);
  }

  async set(collection: string, id: string, data: JsonMap): Promise<void> {
    this.ensureCollection(collection).set(id, {
      ...this.clone(data),
      _id: id,
    });
  }

  async merge(collection: string, id: string, patch: JsonMap): Promise<void> {
    const current =
      (await this.get(collection, id)) ?? ({ _id: id } as JsonMap);
    await this.set(collection, id, {
      ...current,
      ...this.clone(patch),
      _id: id,
    });
  }

  async delete(collection: string, id: string): Promise<void> {
    this.ensureCollection(collection).delete(id);
  }

  async query(
    collection: string,
    options?: {
      filters?: Record<string, unknown>;
      orderBy?: {
        field: string;
        direction: SortDirection;
      };
      limit?: number;
    },
  ): Promise<JsonMap[]> {
    let docs = Array.from(this.ensureCollection(collection).values()).map(
      (doc) => this.clone(doc),
    );
    if (options?.filters) {
      docs = docs.filter((doc) =>
        Object.entries(options.filters ?? {}).every(
          ([key, expected]) => doc[key] === expected,
        ),
      );
    }
    if (options?.orderBy) {
      const { field, direction } = options.orderBy;
      docs.sort((left, right) => {
        const leftValue = String(left[field] ?? "");
        const rightValue = String(right[field] ?? "");
        return direction === "asc"
          ? leftValue.localeCompare(rightValue)
          : rightValue.localeCompare(leftValue);
      });
    }
    if (typeof options?.limit === "number") {
      docs = docs.slice(0, options.limit);
    }
    return docs;
  }

  private ensureCollection(collection: string): Map<string, JsonMap> {
    if (!this.collections.has(collection)) {
      this.collections.set(collection, new Map<string, JsonMap>());
    }
    return this.collections.get(collection)!;
  }

  private clone<T>(value: T): T {
    return JSON.parse(JSON.stringify(value)) as T;
  }
}

class TestFileStorage {
  async getTemporaryUrl(fileId: string): Promise<string> {
    return `https://cdn.example.com/${fileId}`;
  }

  async uploadBytes(params: {
    fileName: string;
    bytes: Buffer;
    contentType?: string;
  }): Promise<{ fileId: string; url: string }> {
    return {
      fileId: `uploaded-${params.fileName}`,
      url: `https://cdn.example.com/uploaded-${params.fileName}`,
    };
  }
}

class ThrowingTempUrlFileStorage extends TestFileStorage {
  override async getTemporaryUrl(_fileId: string): Promise<string> {
    throw new Error("temp url signing failed");
  }
}

test("createDorm writes current member displayBadgeId", async () => {
  const store = new TestDocumentStore();
  const repo = new FirestoreRepository(store as any, new TestFileStorage());
  const uid = "owner-user";

  await repo.saveUserProfile(uid, {
    displayName: "Owner",
    earnedBadgeIds: ["first-week", "sleep-master"],
    equippedBadgeId: "sleep-master",
  });

  const created = await repo.createDorm(uid, {
    name: "晚安 204",
  });

  const member = await store.get("dorm_members", `${created.dormId}:${uid}`);
  assert.equal(member?.displayBadgeId, "sleep-master");
  assert.equal(member?.presenceStatus, "unknown");
});

test("createDorm marks current member returned when location anchor exists", async () => {
  const store = new TestDocumentStore();
  const repo = new FirestoreRepository(store as any, new TestFileStorage());
  const uid = "owner-with-location";

  await repo.saveUserProfile(uid, {
    displayName: "Owner",
  });

  const created = await repo.createDorm(uid, {
    name: "鏅氬畨 204",
    locationAnchor: {
      latitude: 31.2304,
      longitude: 121.4737,
      radiusMeters: 100,
      recordedAt: "2026-04-22T20:00:00.000Z",
      recordedByUid: uid,
    },
  });

  const member = await store.get("dorm_members", `${created.dormId}:${uid}`);
  assert.equal(member?.presenceStatus, "returned");
});

test("acceptDormInvite writes joined member displayBadgeId", async () => {
  const store = new TestDocumentStore();
  const repo = new FirestoreRepository(store as any, new TestFileStorage());

  await repo.saveUserProfile("owner-user", {
    displayName: "Owner",
    earnedBadgeIds: ["founder-badge"],
    equippedBadgeId: "founder-badge",
  });
  const created = await repo.createDorm("owner-user", {
    name: "晚安 204",
  });
  const invite = await repo.createDormInvite("owner-user");

  await repo.saveUserProfile("roommate-user", {
    displayName: "Roommate",
    earnedBadgeIds: ["latest-earned"],
    equippedBadgeId: null,
  });

  const accepted = await repo.acceptDormInvite(
    "roommate-user",
    invite.inviteCode,
  );
  assert.equal(accepted.dormId, created.dormId);

  const member = await store.get(
    "dorm_members",
    `${created.dormId}:roommate-user`,
  );
  assert.equal(member?.displayBadgeId, "latest-earned");
  assert.equal(member?.presenceStatus, "unknown");
});

test("updateDormMemberStatus preserves fields omitted by presence-only updates", async () => {
  const store = new TestDocumentStore();
  const repo = new FirestoreRepository(store as any, new TestFileStorage());
  const uid = "resident-user";
  const dormId = "dorm-test-204";

  await store.set("dorms", dormId, {
    id: dormId,
    name: "鏅氬畨 204",
  });
  await repo.saveUserProfile(uid, {
    displayName: "Resident",
    dormId,
  });
  await store.set("dorm_members", `${dormId}:${uid}`, {
    dormId,
    uid,
    name: "Resident",
    status: "active",
    presenceStatus: "away",
    sleepModeActive: true,
    note: "Original note",
    lastActiveAt: "2026-04-22T19:30:00.000Z",
  });

  const updated = await repo.updateDormMemberStatus(uid, {
    presenceStatus: "returned",
  });

  assert.equal(updated.status, "active");
  assert.equal(updated.presenceStatus, "returned");
  assert.equal(updated.sleepModeActive, true);
  assert.equal(updated.note, "Original note");
});

test("getDorm backfills avatarUrl and displayBadgeId from latest user profile", async () => {
  const store = new TestDocumentStore();
  const repo = new FirestoreRepository(store as any, new TestFileStorage());
  const dormId = "dorm-test-204";

  await store.set("dorms", dormId, {
    id: dormId,
    name: "晚安 204",
    earnedDormBadgeIds: ["no-trouble-room"],
  });
  await repo.saveUserProfile("roommate-user", {
    displayName: "Roommate",
    dormId,
    avatarUrl: null,
    avatarStoragePath: "avatar-file-1",
    earnedBadgeIds: ["first-week", "latest-earned"],
    equippedBadgeId: null,
  });
  await store.set("dorm_members", `${dormId}:roommate-user`, {
    dormId,
    uid: "roommate-user",
    name: "",
    status: "quiet",
    presenceStatus: "returned",
    sleepModeActive: false,
    lastActiveAt: "2026-04-13T15:00:00.000Z",
    note: "准备休息",
    avatarUrl: "https://old.example.com/expired-member-avatar.png",
    displayBadgeId: null,
  });

  let dorm = await repo.getDorm(dormId, "owner-user");
  let roommate = dorm.members.find((member) => member.uid === "roommate-user");
  assert.ok(roommate);
  assert.equal(roommate?.name, "Roommate");
  assert.equal(roommate?.avatarUrl, "https://cdn.example.com/avatar-file-1");
  assert.equal(roommate?.displayBadgeId, "latest-earned");

  await repo.saveUserProfile("roommate-user", {
    avatarUrl: "https://images.example.com/new-avatar.png",
    avatarStoragePath: null,
    equippedBadgeId: "equipped-badge",
    earnedBadgeIds: ["first-week", "latest-earned", "equipped-badge"],
  });
  await store.merge("dorm_members", `${dormId}:roommate-user`, {
    avatarUrl: "https://old.example.com/stale-member-avatar.png",
  });

  dorm = await repo.getDorm(dormId, "owner-user");
  roommate = dorm.members.find((member) => member.uid === "roommate-user");
  assert.equal(
    roommate?.avatarUrl,
    "https://images.example.com/new-avatar.png",
  );
  assert.equal(roommate?.displayBadgeId, "equipped-badge");

  await store.merge("users", "roommate-user", {
    avatarUrl: null,
    avatarStoragePath: null,
  });
  await store.merge("dorm_members", `${dormId}:roommate-user`, {
    avatarUrl: "https://old.example.com/member-only-avatar.png",
  });

  dorm = await repo.getDorm(dormId, "owner-user");
  roommate = dorm.members.find((member) => member.uid === "roommate-user");
  assert.equal(
    roommate?.avatarUrl,
    "https://old.example.com/member-only-avatar.png",
  );
});

test("getDorm logs avatar diagnostics when temp-url signing fails or avatar data is missing", async () => {
  const originalConsoleLog = console.log;
  const logs: string[] = [];
  console.log = (...args: unknown[]) => {
    logs.push(args.map((value) => String(value)).join(" "));
  };

  try {
    const store = new TestDocumentStore();
    const repo = new FirestoreRepository(
      store as any,
      new ThrowingTempUrlFileStorage(),
    );
    const dormId = "dorm-avatar-diagnostics";

    await store.set("dorms", dormId, {
      id: dormId,
      name: "Dorm",
    });
    await repo.saveUserProfile("roommate-user", {
      displayName: "Roommate",
      dormId,
      avatarUrl: null,
      avatarStoragePath: "avatar-file-1",
    });
    await store.set("dorm_members", `${dormId}:roommate-user`, {
      dormId,
      uid: "roommate-user",
      name: "Roommate",
      status: "quiet",
      presenceStatus: "returned",
      sleepModeActive: false,
      lastActiveAt: "2026-04-13T15:00:00.000Z",
      note: "resting",
      avatarUrl: null,
    });

    const dorm = await repo.getDorm(dormId, "owner-user");
    const roommate = dorm.members.find((member) => member.uid === "roommate-user");
    assert.equal(roommate?.avatarUrl, undefined);
    assert.ok(
      logs.some((line) =>
        line.includes(
          "[repo] dorm avatar temp-url failed uid=roommate-user storagePath=avatar-file-1",
        ),
      ),
    );
    assert.ok(
      logs.some((line) =>
        line.includes(
          "[repo] dorm avatar missing uid=roommate-user reason=temp_url_failed",
        ),
      ),
    );

    logs.length = 0;
    await store.merge("users", "roommate-user", {
      avatarStoragePath: null,
      avatarUrl: null,
    });

    await repo.getDorm(dormId, "owner-user");
    assert.ok(
      logs.some((line) =>
        line.includes(
          "[repo] dorm avatar missing uid=roommate-user reason=no_avatar_data",
        ),
      ),
    );
  } finally {
    console.log = originalConsoleLog;
  }
});

test("updateDormMemberStatus preserves sleepModeActive when omitted", async () => {
  const store = new TestDocumentStore();
  const repo = new FirestoreRepository(store as any, new TestFileStorage());
  const uid = "sleeping-user";
  const dormId = "dorm-sleep-preserve";

  await store.set("dorms", dormId, { id: dormId, name: "Dorm" });
  await repo.saveUserProfile(uid, { displayName: "Sleeper", dormId });
  await store.set("dorm_members", `${dormId}:${uid}`, {
    dormId,
    uid,
    name: "Sleeper",
    status: "quiet",
    presenceStatus: "returned",
    sleepModeActive: true,
    lastActiveAt: "2026-04-20T23:00:00.000Z",
    note: "asleep",
  });

  const member = await repo.updateDormMemberStatus(uid, {
    presenceStatus: "away",
    note: "location changed",
  });

  assert.equal(member.sleepModeActive, true);
  assert.equal(member.presenceStatus, "away");
});

test("updateDormMemberStatus normalizes legacy sleeping status when sleep mode is off", async () => {
  const store = new TestDocumentStore();
  const repo = new FirestoreRepository(store as any, new TestFileStorage());
  const uid = "sleeping-user";
  const dormId = "dorm-sleep-normalize";

  await store.set("dorms", dormId, { id: dormId, name: "Dorm" });
  await repo.saveUserProfile(uid, { displayName: "Sleeper", dormId });
  await store.set("dorm_members", `${dormId}:${uid}`, {
    dormId,
    uid,
    name: "Sleeper",
    status: "sleeping",
    presenceStatus: "returned",
    sleepModeActive: true,
    lastActiveAt: "2026-04-20T23:00:00.000Z",
    note: "asleep",
  });

  const member = await repo.updateDormMemberStatus(uid, {
    sleepModeActive: false,
    note: "awake now",
  });

  assert.equal(member.sleepModeActive, false);
  assert.equal(member.status, "quiet");
  assert.equal(member.note, "awake now");
});

test("updateDormMemberHeartbeat writes app online fields only", async () => {
  const store = new TestDocumentStore();
  const repo = new FirestoreRepository(store as any, new TestFileStorage());
  const uid = "online-user";
  const dormId = "dorm-heartbeat";
  const originalLastActiveAt = "2026-04-20T23:00:00.000Z";

  await store.set("dorms", dormId, { id: dormId, name: "Dorm" });
  await repo.saveUserProfile(uid, { displayName: "Online", dormId });
  await store.set("dorm_members", `${dormId}:${uid}`, {
    dormId,
    uid,
    name: "Online",
    status: "quiet",
    presenceStatus: "returned",
    sleepModeActive: true,
    lastActiveAt: originalLastActiveAt,
    note: "asleep",
  });

  const online = await repo.updateDormMemberHeartbeat(uid, { online: true });

  assert.equal(online.appOnline, true);
  assert.equal(typeof online.appLastSeenAt, "string");
  assert.equal(online.sleepModeActive, true);
  assert.equal(online.lastActiveAt, originalLastActiveAt);

  const offline = await repo.updateDormMemberHeartbeat(uid, { online: false });
  assert.equal(offline.appOnline, false);
  assert.equal(offline.sleepModeActive, true);
  assert.equal(offline.lastActiveAt, originalLastActiveAt);

  const dorm = await repo.getDorm(dormId, uid);
  const member = dorm.members.find((item) => item.uid === uid);
  assert.equal(member?.appOnline, false);
  assert.equal(typeof member?.appLastSeenAt, "string");
  assert.equal(member?.sleepModeActive, true);
});
