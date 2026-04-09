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
  dormId?: string | null;
  phoneNumber?: string | null;
  phoneLinkedAt?: string | null;
  avatarUrl?: string | null;
  avatarStoragePath?: string | null;
}

export interface ContextUserSettings {
  sleepGoalHours: number;
  preferredTrackTitle: string;
  smartSuggestionsEnabled: boolean;
  selectedNightMood?: string | null;
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
  sleepModeActive: boolean;
  avatarUrl?: string;
}

export interface ContextDormEvent {
  id: string;
  type: string;
  title: string;
  detail: string;
  createdAt?: string;
}

export interface ContextDorm {
  id: string;
  name: string;
  overview: string;
  noiseDb: number;
  lightLabel: string;
  quietLabel: string;
  status?: string;
  archivedAt?: string | null;
  members: ContextDormMember[];
  events: ContextDormEvent[];
  rules?: Record<string, unknown>[];
  invites?: Record<string, unknown>[];
  rulesSettings?: Record<string, unknown>;
}

export interface ContextSleepSessionSummary {
  id: string;
  startedAt?: string;
  endedAt?: string | null;
  status: string;
  awakeningsCount: number;
  totalSleepHours?: number | null;
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
  sourceThreadId?: string | null;
  salience: number;
  lastUsedAt?: string | null;
  sourceRefs: string[];
  createdAt: string;
  updatedAt: string;
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

export interface UserStateDoc {
  currentPhase: SleepPhase;
  activeSessionId?: string | null;
  latestThreadId?: string | null;
  latestNightMood?: string | null;
  profileSummary: ProfileSummary;
  tonightPlan?: TonightPlan | null;
  feedbackLoop?: FeedbackLoopSummary | null;
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
  createdAt: string;
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

export interface MorningReviewResult {
  reviewSummary: string;
  effectiveActions: string[];
  ineffectiveActions: string[];
  profileSummary: ProfileSummary;
}
