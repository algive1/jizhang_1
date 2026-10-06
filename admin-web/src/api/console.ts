import { request } from "./client";
import type {
  Admin,
  Dashboard,
  Page,
  User,
  Release,
  ReleaseInput,
  DocumentKind,
  DocumentRow,
  Revision,
  Query,
  Role,
  Administrator,
  AccountingEvent,
  AIModel,
  AIModelInput,
  AIUsage,
  AICall,
  Operation,
  FeedbackDetail,
  LedgerStatistics,
  BackupSummary,
  PushCampaign,
  PushDetail,
  PushJob,
} from "./types";
export const api = {
  login: (username: string, password: string) =>
    request<{ token: string; expiresAt: number }>("/auth/login", {
      method: "POST",
      body: { username, password },
    }),
  me: () => request<Admin>("/auth/me"),
  logout: () => request("/auth/logout", { method: "POST" }),
  changePassword: (currentPassword: string, newPassword: string) =>
    request("/auth/password", {
      method: "POST",
      body: { currentPassword, newPassword },
    }),
  resetAdminPassword: (id: string, password: string) =>
    request(`/administrators/${encodeURIComponent(id)}/password`, {
      method: "POST",
      body: { password },
    }),
  dashboard: (days: number) =>
    request<Dashboard>("/dashboard", { query: { days } }),
  users: (query: Query) => request<Page<User>>("/users", { query }),
  user: (id: string) =>
    request<{ user: User; counts: { books: number } }>(
      `/users/${encodeURIComponent(id)}`,
    ),
  setUserStatus: (id: string, disabled: boolean) =>
    request(`/users/${encodeURIComponent(id)}/status`, {
      method: "PATCH",
      body: { disabled },
    }),
  setUsersStatus: (ids: string[], disabled: boolean) =>
    request("/users/batch-status", { method: "POST", body: { ids, disabled } }),
  releases: (query: Query) => request<Page<Release>>("/releases", { query }),
  createRelease: (body: ReleaseInput) =>
    request("/releases", { method: "POST", body }),
  release: (id: string) =>
    request<Release>(`/releases/${encodeURIComponent(id)}`),
  editRelease: (id: string, body: ReleaseInput & { revision: number }) =>
    request(`/releases/${encodeURIComponent(id)}`, { method: "PUT", body }),
  releaseState: (
    id: string,
    status: "published" | "offline",
    rollout?: number,
  ) =>
    request(`/releases/${id}/state`, {
      method: "PATCH",
      body: { status, rollout },
    }),
  documents: (kind: DocumentKind, query: Query) =>
    request<Page<DocumentRow>>(`/documents/${kind}`, { query }),
  revisions: (kind: DocumentKind, key: string, query: Query) =>
    request<Page<Revision>>(
      `/documents/${kind}/${encodeURIComponent(key)}/history`,
      { query },
    ),
  saveDocument: (
    kind: DocumentKind,
    key: string,
    baseVersion: number,
    payload: unknown,
    note: string,
  ) =>
    request(`/documents/${kind}`, {
      method: "POST",
      body: { key, baseVersion, payload, note },
    }),
  publishDocument: (
    kind: DocumentKind,
    key: string,
    version: number,
    rollout: number,
  ) =>
    request(`/documents/${kind}/${encodeURIComponent(key)}/publish`, {
      method: "POST",
      body: { version, rollout },
    }),
  offlineDocument: (kind: DocumentKind, key: string) =>
    request(`/documents/${kind}/${encodeURIComponent(key)}/publication`, {
      method: "DELETE",
    }),
  roles: () => request<Role[]>("/roles"),
  roleOptions: () => request<Array<Pick<Role, "id" | "name">>>("/role-options"),
  permissions: () => request<Record<string, string>>("/permissions"),
  updateRole: (role: Role) =>
    request(`/roles/${role.id}`, {
      method: "PUT",
      body: { name: role.name, permissions: role.permissions },
    }),
  administrators: (query: Query) =>
    request<Page<Administrator>>("/administrators", { query }),
  createAdministrator: (body: {
    username: string;
    password: string;
    roleId: string;
  }) => request("/administrators", { method: "POST", body }),
  updateAdministrator: (id: string, enabled: boolean, roleId: string) =>
    request(`/administrators/${id}`, {
      method: "PATCH",
      body: { enabled, roleId },
    }),
  events: (query: Query) =>
    request<Page<AccountingEvent>>("/events", { query }),
  models: (query: Query) => request<Page<AIModel>>("/ai/models", { query }),
  saveModel: (id: string | undefined, body: AIModelInput) =>
    request(id ? `/ai/models/${id}` : "/ai/models", {
      method: id ? "PUT" : "POST",
      body,
    }),
  aiUsage: (period: string) =>
    request<AIUsage>("/ai/usage", { query: { period, days: 30 } }),
  aiCalls: (query: Query) => request<Page<AICall>>("/ai/calls", { query }),
  aiCall: (id: string) =>
    request<AICall>(`/ai/calls/${encodeURIComponent(id)}`),
  revokeSession: (id: string) =>
    request(`/sessions/${encodeURIComponent(id)}`, { method: "DELETE" }),
  pushCampaigns: (query: Query) =>
    request<Page<PushCampaign>>("/push/campaigns", { query }),
  createPush: (
    body: Pick<PushCampaign, "userId" | "title" | "body" | "route">,
  ) => request<{ id: string }>("/push/campaigns", { method: "POST", body }),
  pushDetail: (id: string) =>
    request<PushDetail>(`/push/campaigns/${encodeURIComponent(id)}`),
  pushJobs: (id: string, query: Query) =>
    request<Page<PushJob>>(`/push/campaigns/${encodeURIComponent(id)}/jobs`, {
      query,
    }),
  publishPush: (id: string) =>
    request(`/push/campaigns/${encodeURIComponent(id)}/publish`, {
      method: "POST",
      body: { confirmed: true },
    }),
  stopPush: (id: string) =>
    request(`/push/campaigns/${encodeURIComponent(id)}/stop`, {
      method: "POST",
    }),
  ledger: () => request<LedgerStatistics>("/ledger/statistics"),
  backupSummary: () => request<BackupSummary>("/backups/summary"),
  operations: (query: Query) =>
    request<Page<Operation>>("/operations", { query }),
  saveOperation: (
    id: string | undefined,
    body: Omit<Operation, "id" | "updatedAt" | "enabled"> & {
      enabled: boolean;
    },
  ) =>
    request(id ? `/operations/${id}` : "/operations", {
      method: id ? "PUT" : "POST",
      body,
    }),
  announcements: (query: Query) =>
    request<
      Page<{
        id: string;
        title: string;
        body: string;
        publishedAt: number;
        expiresAt: number | null;
      }>
    >("/announcements", { query }),
  publishAnnouncement: (title: string, body: string) =>
    request("/announcements", { method: "POST", body: { title, body } }),
  feedbackDetail: (id: string, query: Query) =>
    request<FeedbackDetail>(`/feedback/${id}`, { query }),
  feedbackStatus: (id: string, status: string) =>
    request(`/feedback/${id}/status`, { method: "PATCH", body: { status } }),
  trace: (userId: string, traceId: string) =>
    request<{
      events: AccountingEvent[];
      observedStages: string[];
      integration: string;
    }>(
      `/events/trace/${encodeURIComponent(userId)}/${encodeURIComponent(traceId)}`,
    ),
  list: <T>(path: string, query: Query) => request<Page<T>>(path, { query }),
  read: <T>(path: string, query?: Query) => request<T>(path, { query }),
};
