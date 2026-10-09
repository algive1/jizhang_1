export type Query = Record<string, string | number | boolean | undefined>;
export interface Page<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}
export interface Menu {
  path: string;
  title: string;
  group: string;
  permission: string;
}
export interface Admin {
  id: string;
  username: string;
  roleId: string;
  permissions: string[];
  menus: Menu[];
}
export interface User {
  id: string;
  username: string;
  displayName: string | null;
  createdAt: number;
  accountDisabled: number;
  lastSeenAt: number | null;
  appVersion: string | null;
  androidVersion: string | null;
  brand: string | null;
  model: string | null;
  autoEnabled: number | null;
  backupEnabled: number | null;
  member: number;
}
export interface Release {
  id: string;
  platform: "android" | "ios";
  versionName: string;
  versionCode: number;
  minimumVersion: string;
  downloadUrl: string;
  changelog: string;
  rollout: number;
  status: "draft" | "published" | "offline";
  createdAt: number;
  publishedAt: number | null;
  revision: number;
  updatedAt: number;
  updatedBy: string | null;
}
export type ReleaseInput = Pick<
  Release,
  | "platform"
  | "versionName"
  | "versionCode"
  | "minimumVersion"
  | "downloadUrl"
  | "changelog"
  | "rollout"
>;
export type DocumentKind = "config" | "rule" | "prompt";
export interface DocumentRow {
  key: string;
  version: number;
  payloadJson: string;
  note: string;
  createdAt: number;
  createdBy: string;
  publishedVersion: number | null;
  rollout: number | null;
}
export interface Revision {
  version: number;
  payloadJson: string;
  note: string;
  createdAt: number;
  createdBy: string;
}
export interface Role {
  id: string;
  name: string;
  permissions: string[];
}
export interface Administrator {
  id: string;
  username: string;
  roleId: string;
  enabled: number;
  createdAt: number;
}
export interface Trend {
  day: string;
  users: number;
  active: number;
  bookkeeping: number;
  autoSaved: number;
  autoSuccessRate: number | null;
  aiCalls: number;
}
export interface Dashboard {
  generatedAt: number;
  timezone: string;
  days: number;
  metrics: Record<string, number | string | null>;
  trends: Trend[];
  versions: Array<{ name: string; value: number }>;
  sources: Array<{ name: string; value: number }>;
  integration: Record<string, string>;
}
export interface AccountingEvent {
  userId: string;
  eventId: string;
  traceId: string;
  occurredAt: number;
  stage: string;
  status: string;
  packageName: string;
  appVersion: string;
  ruleVersion: number | null;
  reason: string | null;
  metadataJson: string;
}
export interface AIModel {
  id: string;
  name: string;
  provider: string;
  model: string;
  endpoint: string;
  keyRef: string;
  keyConfigured: boolean;
  endpointAllowed: boolean;
  inputPrice: number;
  outputPrice: number;
  maxTokens: number;
  timeoutMs: number;
  enabled: boolean;
  priority: number;
  fallbackId: string | null;
  scenes: string[];
  dailyBudgetUsd: number | null;
}
export type AIModelInput = Omit<
  AIModel,
  "id" | "keyConfigured" | "endpointAllowed"
>;
export interface AIUsage {
  totals: {
    calls: number;
    successes: number | null;
    inputTokens: number | null;
    outputTokens: number | null;
    costMicroUsd: number | null;
    pricedCalls: number;
    averageDurationMs: number | null;
    users: number;
    averageUserCostMicroUsd: number | null;
    averageBookkeepingCostMicroUsd: number | null;
  };
  period: string;
  currency: string;
  priceUnit: string;
  integration: string;
  trend: Array<{
    period: string;
    calls: number;
    inputTokens: number | null;
    outputTokens: number | null;
    costMicroUsd: number | null;
  }>;
  byModel: Array<{
    model: string;
    calls: number;
    pricedCalls: number;
    costMicroUsd: number | null;
  }>;
  byFeature: Array<{
    feature: string;
    calls: number;
    pricedCalls: number;
    costMicroUsd: number | null;
  }>;
}
export interface AICall {
  id: string;
  userId: string | null;
  feature: string;
  model: string;
  status: "success" | "failed";
  inputTokens: number | null;
  outputTokens: number | null;
  durationMs: number;
  costMicroUsd: number | null;
  createdAt: number;
}
export interface Operation {
  id: string;
  kind: "faq" | "banner" | "activity";
  title: string;
  body: string;
  enabled: number;
  updatedAt: number;
}
export interface FeedbackDetail {
  ticket: {
    id: string;
    subject: string;
    status: string;
    appVersion: string | null;
  };
  messages: Page<{
    id: string;
    authorType: string;
    body: string;
    createdAt: number;
  }>;
}
export interface LedgerStatistics {
  scope: string;
  books: Array<{ type: string; count: number }>;
  entities: Array<{ kind: string; count: number }>;
  transactionSources: Array<{ source: string; count: number }>;
}
export interface BackupSummary {
  storage: { datasets: number; snapshots: number | null; bytes: number };
  encryption: string;
  integration: string;
}
export interface PushCampaign {
  id: string;
  userId: string;
  title: string;
  body: string;
  route: "/profile/messages" | "/profile" | "/" | null;
  state: "draft" | "queued" | "stopped";
  deviceCount: number;
  createdAt: number;
  publishedAt: number | null;
}
export interface PushDetail {
  campaign: PushCampaign;
  providers: Array<{ provider: string; devices: number; configured: boolean }>;
  delivery: Array<{ status: string; count: number }>;
}
export interface PushJob {
  id: string;
  platform: string;
  provider: string;
  status: string;
  attempts: number;
  createdAt: number;
  sentAt: number | null;
}
