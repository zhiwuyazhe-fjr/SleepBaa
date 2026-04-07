type JsonMap = Record<string, unknown>;

export type AutomationOrigin = "app-api" | "db-trigger" | "manual";

export interface AutomationState {
  origin?: string;
  syncProcessingRequested?: boolean;
  syncRequestedAt?: string;
  lastDerivedAt?: string;
  lastDerivedBy?: string;
  lastHandledStatus?: string | null;
}

function isPlainObject(value: unknown): value is JsonMap {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

export function asMap(value: unknown): JsonMap {
  return isPlainObject(value) ? { ...(value as JsonMap) } : {};
}

export function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
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

export function readAutomationState(value: unknown): AutomationState {
  const automation = asMap(value);
  return {
    origin: asString(automation.origin),
    syncProcessingRequested: asBoolean(
      automation.syncProcessingRequested,
      false,
    ),
    syncRequestedAt: asString(automation.syncRequestedAt),
    lastDerivedAt: asString(automation.lastDerivedAt),
    lastDerivedBy: asString(automation.lastDerivedBy),
    lastHandledStatus:
      automation.lastHandledStatus === null
        ? null
        : asString(automation.lastHandledStatus),
  };
}

export function buildRequestedAutomation(
  origin: AutomationOrigin,
  requestedAt: string,
): AutomationState {
  return {
    origin,
    syncProcessingRequested: true,
    syncRequestedAt: requestedAt,
  };
}

export function buildCompletedAutomation(input: {
  previous?: unknown;
  derivedAt: string;
  derivedBy: "app-api" | "db-trigger";
  lastHandledStatus?: string | null;
}): AutomationState {
  const previous = readAutomationState(input.previous);
  const origin =
    previous.origin && previous.origin.trim().length > 0
      ? previous.origin
      : input.derivedBy;
  return {
    origin,
    syncProcessingRequested: false,
    syncRequestedAt: previous.syncRequestedAt || input.derivedAt,
    lastDerivedAt: input.derivedAt,
    lastDerivedBy: input.derivedBy,
    ...(input.lastHandledStatus !== undefined
      ? { lastHandledStatus: input.lastHandledStatus }
      : {}),
  };
}

function collectUpdatedFieldPaths(
  value: unknown,
  prefix = "",
  result: string[] = [],
): string[] {
  if (!isPlainObject(value)) {
    if (prefix) {
      result.push(prefix);
    }
    return result;
  }
  const entries = Object.entries(value);
  if (entries.length === 0) {
    if (prefix) {
      result.push(prefix);
    }
    return result;
  }
  for (const [key, nestedValue] of entries) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (key.includes(".")) {
      result.push(key);
      continue;
    }
    if (isPlainObject(nestedValue)) {
      collectUpdatedFieldPaths(nestedValue, path, result);
      continue;
    }
    result.push(path);
  }
  return result;
}

export function collectChangedFieldPaths(input: {
  updatedFields?: unknown;
  removedFields?: unknown;
}): string[] {
  const updatedPaths = collectUpdatedFieldPaths(input.updatedFields);
  const removedPaths = asStringArray(input.removedFields);
  return Array.from(new Set([...updatedPaths, ...removedPaths]));
}

function isInternalPath(path: string): boolean {
  return (
    path === "_automation" ||
    path.startsWith("_automation.") ||
    path === "ai" ||
    path.startsWith("ai.")
  );
}

export function changedPathsAreInternalOnly(input: {
  updatedFields?: unknown;
  removedFields?: unknown;
}): boolean {
  const paths = collectChangedFieldPaths(input);
  return paths.length > 0 && paths.every((path) => isInternalPath(path));
}

export function wasSyncProcessingRecentlyRequested(
  automationValue: unknown,
  nowMs = Date.now(),
  thresholdMs = 60_000,
): boolean {
  const automation = readAutomationState(automationValue);
  if (!automation.syncProcessingRequested || !automation.syncRequestedAt) {
    return false;
  }
  const requestedMs = Date.parse(automation.syncRequestedAt);
  if (Number.isNaN(requestedMs)) {
    return false;
  }
  return nowMs - requestedMs >= 0 && nowMs - requestedMs < thresholdMs;
}
