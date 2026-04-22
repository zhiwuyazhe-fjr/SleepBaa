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
    const current = (await this.get(collection, id)) ?? ({ _id: id } as JsonMap);
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
    let docs = Array.from(this.ensureCollection(collection).values()).map((doc) =>
      this.clone(doc),
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

  const accepted = await repo.acceptDormInvite("roommate-user", invite.inviteCode);
  assert.equal(accepted.dormId, created.dormId);

  const member = await store.get(
    "dorm_members",
    `${created.dormId}:roommate-user`,
  );
  assert.equal(member?.displayBadgeId, "latest-earned");
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
  assert.equal(roommate?.avatarUrl, "https://images.example.com/new-avatar.png");
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
