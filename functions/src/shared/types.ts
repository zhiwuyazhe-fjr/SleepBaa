export type SleepPhase =
  | "home_pre_sleep"
  | "sleep_mode"
  | "morning_feedback"
  | "assistant";

export type AssistantIntent =
  | "general_support"
  | "sleep_difficulty"
  | "noise_issue"
  | "dream_reflection"
  | "plan_review"
  | "system_identity";

export type AssistantRunStatus = "success" | "fallback" | "error";
export type AssistantRunSourceMode =
  | "remoteSuccess"
  | "fallbackSuccess"
  | "error";

export type AgentRunStatus =
  | "planned"
  | "running"
  | "success"
  | "partial_success"
  | "failed";

export type AgentToolRisk = "read" | "low" | "write" | "high";

export type AgentStepStatus =
  | "pending"
  | "running"
  | "success"
  | "skipped"
  | "failed";

export type AgentAutonomyMode = "full" | "confirm_required" | "read_only";
export type AgentToolUndoStatus = "applied" | "unavailable";

export type AssistantPromptMode =
  | "chat_reply"
  | "turn_insight_extract"
  | "sleep_capture_dream"
  | "sleep_capture_memo";

export type SurfaceId =
  | "home_pre_sleep"
  | "sleep_mode"
  | "morning_feedback"
  | "profile_report"
  | "assistant_context";

export interface ContextUserProfile {
  uid: string;
  displayName: string;
  tagline: string;
  role: string;
  earnedBadgeIds?: string[];
  equippedBadgeId?: string | null;
  showDormPulseBadge?: boolean;
  selectedDormBadgeId?: string | null;
  dormId?: string | null;
  phoneNumber?: string | null;
  phoneLinkedAt?: string | null;
  avatarUrl?: string | null;
  avatarStoragePath?: string | null;
}

export interface ContextTimeOfDay {
  hour: number;
  minute: number;
}

export interface ContextUserSettings {
  sleepGoalHours: number;
  bedtimeReminderEnabled: boolean;
  morningReminderEnabled: boolean;
  dormAlertsEnabled: boolean;
  bedtimeReminder: ContextTimeOfDay;
  preferredTrackTitle: string;
  smartSuggestionsEnabled: boolean;
  selectedNightMood?: string | null;
  homeQuickActionIds: string[];
}

export interface ContextAssistantProfile {
  userId: string;
  assistantName: string;
  identityPrompt: string;
  tone: string;
  relationshipRole: string;
  updatedAt: string;
}

export interface ContextDormMember {
  uid: string;
  name: string;
  status: string;
  presenceStatus?: string;
  sleepModeActive: boolean;
  appOnline?: boolean;
  appLastSeenAt?: string | null;
  lastActiveAt?: string;
  note?: string;
  avatarUrl?: string;
  displayBadgeId?: string;
}

export interface ContextDormLocationAnchor {
  latitude: number;
  longitude: number;
  radiusMeters: number;
  recordedAt: string;
  recordedByUid: string;
}

export interface ContextDormEvent {
  id: string;
  type: string;
  title: string;
  detail: string;
  createdAt?: string;
  actorUid?: string;
}

export interface ContextDormPendingRuleProposal {
  id: string;
  proposedSettings: Record<string, unknown>;
  proposedRules: Record<string, unknown>[];
  proposerUid: string;
  proposerName: string;
  createdAt: string;
  reviewerUids: string[];
  approvedUids: string[];
  rejectedByUid?: string | null;
  rejectedReason?: string | null;
  resolvedAt?: string | null;
}

export interface ContextDorm {
  id: string;
  name: string;
  overview: string;
  noiseDb: number;
  lightLabel: string;
  quietLabel: string;
  activeMemberCount?: number;
  status?: string;
  archivedAt?: string | null;
  members: ContextDormMember[];
  events: ContextDormEvent[];
  rules?: Record<string, unknown>[];
  invites?: Record<string, unknown>[];
  rulesSettings?: Record<string, unknown>;
  locationAnchor?: ContextDormLocationAnchor | null;
  pendingRuleProposal?: ContextDormPendingRuleProposal | null;
  earnedDormBadgeIds?: string[];
}

export interface ContextSleepSessionSummary {
  id: string;
  sleepDayKey: string;
  startedAt?: string;
  endedAt?: string | null;
  status: string;
  awakeningsCount: number;
  totalSleepHours?: number | null;
  sleepGoalMet?: boolean | null;
  sleepQuality?: number | null;
  restedLevel?: number | null;
  note?: string;
}

export interface ContextDreamSummary {
  id: string;
  title: string;
  body: string;
  emotionLabel?: string | null;
  createdAt?: string;
}

export interface ContextAssistantMessage {
  id: string;
  role: string;
  content: string;
  status?: string;
  sourceMode?: string;
  createdAt?: string;
}

export interface AssistantProfileDoc {
  userId: string;
  assistantName: string;
  identityPrompt: string;
  tone: string;
  relationshipRole: string;
  updatedAt: string;
}

export interface AssistantThreadSummaryDoc {
  threadId: string;
  summary: string;
  keywords: string[];
  updatedAt: string;
}

export interface AssistantMemoryItem {
  id: string;
  kind: string;
  content: string;
  canonicalKey?: string | null;
  keywords?: string[];
  confidence?: number | null;
  sourceThreadId?: string | null;
  sourceMessageId?: string | null;
  salience: number;
  decayScore?: number | null;
  contradictionGroup?: string | null;
  evidenceRefs?: string[];
  sourceActionId?: string | null;
  sourceAgentRunId?: string | null;
  effectivenessScore?: number | null;
  lastUsedAt?: string | null;
  sourceRefs: string[];
  createdAt: string;
  updatedAt: string;
}

export interface AssistantMemoryCandidate {
  kind: string;
  content: string;
  canonicalKey: string;
  keywords: string[];
  confidence: number;
  salience: number;
  sourceThreadId?: string | null;
  sourceMessageId?: string | null;
  sourceRefs: string[];
}

export interface ProfileSummary {
  sleepPatternSummary: string;
  highRiskFactors: string[];
  effectiveActions: string[];
  dreamTrendSummary: string;
  emotionTrendSummary: string;
  lastUpdatedAt: string;
}

export interface InterferenceFactor {
  key: string;
  label: string;
  score: number;
  evidence: string;
  sourceRefs: string[];
}

export interface RecommendedAction {
  id: string;
  title: string;
  subtitle: string;
  type: "audio" | "quickAction";
  priority: number;
  reason: string;
  route: string;
  trackId?: string | null;
  tags: string[];
}

export interface TonightPlan {
  dateKey: string;
  coachSummary: string;
  riskLevel: "low" | "medium" | "high";
  topFactors: InterferenceFactor[];
  recommendedActions: RecommendedAction[];
  generatedAt: string;
  sourceRunId: string;
}

export interface FeedbackLoopSummary {
  lastSessionId?: string | null;
  lastReviewSummary: string;
  effectiveActions: string[];
  ineffectiveActions: string[];
  updatedAt: string;
}

export interface InterferenceSnapshotDoc {
  type: "noise" | "light" | "phoneUsage" | "emotion";
  title: string;
  value: string;
  gradeLabel: string;
  status:
    | "idle"
    | "measuring"
    | "ready"
    | "denied"
    | "unavailable"
    | "unsupported"
    | "error";
  detail: string;
  source: string;
  measuredAt?: string | null;
  numericValue?: number | null;
  score?: number | null;
}

export interface TonightInterferenceStateDoc {
  noise: InterferenceSnapshotDoc;
  light: InterferenceSnapshotDoc;
  phoneUsage: InterferenceSnapshotDoc;
  emotion: InterferenceSnapshotDoc;
  updatedAt: string;
}

export type SleepCaptureKind = "dream" | "memo";

export interface PendingSleepMemoGroupDoc {
  sessionId: string;
  label: string;
  items: string[];
  isCarryover: boolean;
}

export interface PendingSleepMemoBannerDoc {
  title: string;
  subtitle: string;
  groups: PendingSleepMemoGroupDoc[];
  createdAt: string;
}

export interface SleepCaptureStateDoc {
  pendingMemoBanner?: PendingSleepMemoBannerDoc | null;
}

export interface UserStateDoc {
  currentPhase: SleepPhase;
  activeSessionId?: string | null;
  latestThreadId?: string | null;
  latestNightMood?: string | null;
  profileSummary: ProfileSummary;
  tonightPlan?: TonightPlan | null;
  tonightInterference?: TonightInterferenceStateDoc | null;
  feedbackLoop?: FeedbackLoopSummary | null;
  sleepCapture?: SleepCaptureStateDoc | null;
  updatedAt: string;
}

export interface CardSnapshotCard {
  id: string;
  type: string;
  title: string;
  subtitle: string;
  metric?: string | null;
  chipLabel?: string | null;
  actionRoute?: string | null;
  payload?: Record<string, unknown>;
  priority: number;
}

export interface CardSnapshotDoc {
  surfaceId: SurfaceId;
  version: string;
  generatedAt: string;
  headline: string;
  cards: CardSnapshotCard[];
  sourceRefs: string[];
}

export interface AssistantRunDoc {
  eventType: string;
  threadId?: string | null;
  provider: string;
  model: string;
  status: AssistantRunStatus;
  sourceMode: AssistantRunSourceMode;
  inputRefs: string[];
  outputRefs: string[];
  error?: string | null;
  fastPath?: boolean;
  replyContextMs?: number;
  firstDeltaMs?: number | null;
  replyCompletedMs?: number;
  insightMs?: number;
  totalMs?: number;
  createdAt: string;
}

export interface AgentGoalDoc {
  id: string;
  text: string;
  intent: string;
  riskLevel: "low" | "medium" | "high";
  autonomyMode: AgentAutonomyMode;
  createdAt: string;
}

export interface AgentToolDefinitionDoc {
  name: string;
  title: string;
  description: string;
  risk: AgentToolRisk;
  inputSchema: Record<string, unknown>;
  outputSchema?: Record<string, unknown>;
  undoable: boolean;
  requiresHardConfirm: boolean;
}

export interface AgentStepDoc {
  id: string;
  title: string;
  toolName: string;
  input: Record<string, unknown>;
  status: AgentStepStatus;
  risk: AgentToolRisk;
  dependsOn: string[];
}

export interface AgentPlanDoc {
  id: string;
  runId: string;
  userId: string;
  threadId?: string | null;
  goal: AgentGoalDoc;
  steps: AgentStepDoc[];
  status: AgentRunStatus;
  createdAt: string;
  updatedAt: string;
}

export interface AgentToolCallDoc {
  id: string;
  runId: string;
  planId: string;
  stepId: string;
  userId: string;
  threadId?: string | null;
  toolName: string;
  risk: AgentToolRisk;
  status: AgentStepStatus;
  committed?: boolean;
  input: Record<string, unknown>;
  output?: Record<string, unknown> | null;
  error?: string | null;
  undoPayload?: Record<string, unknown> | null;
  undoStatus?: AgentToolUndoStatus | null;
  undoAppliedAt?: string | null;
  undoResult?: Record<string, unknown> | null;
  undoError?: string | null;
  startedAt: string;
  finishedAt?: string | null;
  durationMs?: number | null;
}

export interface AgentRunDoc {
  id: string;
  userId: string;
  threadId?: string | null;
  goal: AgentGoalDoc;
  planId?: string | null;
  status: AgentRunStatus;
  autonomyMode: AgentAutonomyMode;
  summary?: string | null;
  provider: string;
  model: string;
  sourceMode: AssistantRunSourceMode;
  toolCallCount: number;
  memorySyncedCount: number;
  updatedSurfaces: SurfaceId[];
  error?: string | null;
  startedAt: string;
  completedAt?: string | null;
  durationMs?: number | null;
}

export interface AgentExecutionResult {
  runId: string;
  planId: string;
  reply: string;
  status: AgentRunStatus;
  goal: AgentGoalDoc;
  plan: AgentPlanDoc;
  toolCalls: AgentToolCallDoc[];
  updatedSurfaces: SurfaceId[];
  memorySyncedCount: number;
  provider: string;
  model: string;
  sourceMode: AssistantRunSourceMode;
  errorMessage?: string | null;
  surfacePatch?: AssistantSurfacePatchDoc | null;
}

export interface AssistantContext {
  assistantProfile: ContextAssistantProfile;
  user: ContextUserProfile;
  settings: ContextUserSettings;
  dorm: ContextDorm;
  recentSessions: ContextSleepSessionSummary[];
  recentDreams: ContextDreamSummary[];
  recentMessages: ContextAssistantMessage[];
  threadSummary?: AssistantThreadSummaryDoc | null;
  longTermMemory?: AssistantMemoryItem[];
  userState?: UserStateDoc | null;
}

export interface StructuredAssistantReply {
  reply: string;
  intent: AssistantIntent;
  recommendedActions: RecommendedAction[];
  updateTonightPlan: boolean;
  updatedSurfaces: SurfaceId[];
}

export interface DreamAnalysis {
  summary: string;
  dominantEmotion: string;
  suggestedFocus: string;
  sourceRefs: string[];
}

export interface TurnInsightExtraction {
  interferenceSignals: InterferenceSnapshotDoc[];
  actionSuggestions: RecommendedAction[];
  memoryCandidates: AssistantMemoryCandidate[];
  shouldRefreshPlan: boolean;
  updatedSurfaces: SurfaceId[];
}

export interface SleepCaptureRecordDoc {
  id: string;
  userId: string;
  type: SleepCaptureKind;
  sessionId: string;
  createdAt: string;
  title: string;
  outline: string;
  content: string;
}

export interface SleepCaptureDraft {
  type: SleepCaptureKind;
  title: string;
  outline: string;
  content: string;
  reply: string;
}

export interface AssistantSurfacePatchDoc {
  userState?: Partial<UserStateDoc> | null;
  cardSnapshots?: Partial<Record<SurfaceId, CardSnapshotDoc>>;
  sleepCaptureRecords?: SleepCaptureRecordDoc[];
}

export interface MorningReviewResult {
  reviewSummary: string;
  effectiveActions: string[];
  ineffectiveActions: string[];
  profileSummary: ProfileSummary;
}

export type AssistantSseEventName =
  | "ack"
  | "planning_started"
  | "tool_started"
  | "tool_completed"
  | "tool_failed"
  | "action_committed"
  | "memory_updated"
  | "message_delta"
  | "message_completed"
  | "surface_patch"
  | "capture_record"
  | "memory_synced"
  | "agent_done"
  | "done"
  | "error";

export interface AssistantSseEvent<T = Record<string, unknown>> {
  event: AssistantSseEventName;
  data: T;
}
