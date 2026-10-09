import { request } from "./client";
import type { Query, Page } from "./types";
export interface Benefit {
  id: string;
  title: string;
  subtitle: string;
  detail: string;
  iconUrl: string;
  enabled: boolean;
  entitlementKeys?: string[];
}
export interface Plan {
  id: string;
  title: string;
  months: 1 | 3 | 12;
  priceInCents: number;
  description: string;
  recommended: boolean;
  versionId: "pro" | "family";
  originalPriceInCents: number;
  tag: string;
  enabled: boolean;
  sortOrder: number;
  aiDailyLimit?: number;
  rightOverrides: Array<{ benefitId: string; enabled: boolean; value: string }>;
}
export interface Catalog {
  versions: Array<{
    id: "pro" | "family";
    title: string;
    description: string;
    enabled: boolean;
    sortOrder: number;
    benefitIds?: string[];
  }>;
  plans: Plan[];
  benefits: Benefit[];
  benefitIcons: Array<{ id: string; name: string; url: string }>;
  faqs: Array<{ id: string; question: string; answer: string }>;
}
export interface CatalogState {
  catalog: Catalog;
  draft: Catalog;
  revision: number;
  publishedHash: string;
  note: string;
}
export interface MemberSnapshot {
  membership: { plan: string; status: string };
  subscription?: {
    productId: string;
    provider: string;
    startedAt: number;
    expiresAt: number;
  };
  entitlements: Array<{ key: string }>;
  quotas: Array<{ key: string; limit: number; used: number }>;
}
export interface MemberDetail {
  snapshot: MemberSnapshot;
  history: Array<{
    id: string;
    productId: string | null;
    durationDays: number;
    reason: string;
    createdAt: number;
    actor: string;
  }>;
}
export interface Integration {
  provider: string;
  canSaveSecrets: boolean;
  items: Array<{
    name: string;
    secret: boolean;
    value: string;
    configured: boolean;
    readable: boolean;
    source: string;
  }>;
}
export interface Order {
  id: string;
  userId: string;
  username: string;
  productId: string;
  productTitle: string;
  channel: string;
  amountInCents: number;
  status: string;
  providerTradeNo: string | null;
  createdAt: number;
  refundStatus: string | null;
  refundId: string | null;
}
export const commerce = {
  catalog: () => request<CatalogState>("/membership/catalog"),
  saveCatalog: (catalog: Catalog, baseRevision: number, note: string) =>
    request<{ revision: number }>("/membership/catalog", {
      method: "POST",
      body: { catalog, baseRevision, note },
    }),
  publish: (revision: number, publishedHash: string) =>
    request(`/membership/catalog/${revision}/publish`, {
      method: "POST",
      body: { publishedHash },
    }),
  history: (query: Query) =>
    request<
      Page<{ id: number; revision: number; note: string; createdAt: number }>
    >("/membership/history", { query }),
  member: (id: string) =>
    request<MemberDetail>(`/membership/users/${encodeURIComponent(id)}`),
  adjust: (
    id: string,
    productId: string | null,
    durationDays: number,
    reason: string,
  ) =>
    request(`/membership/users/${encodeURIComponent(id)}`, {
      method: "PUT",
      body: { productId, durationDays, reason },
    }),
  integration: (provider: string) =>
    request<Integration>(`/integrations/${provider}`),
  saveIntegration: (provider: string, values: Record<string, string>) =>
    request<Integration>(`/integrations/${provider}`, {
      method: "PUT",
      body: { values },
    }),
  orders: (query: Query) => request<Page<Order>>("/payments/orders", { query }),
  refreshOrder: (id: string) =>
    request(`/payments/orders/${id}/refresh`, { method: "POST" }),
  closeOrder: (id: string) =>
    request(`/payments/orders/${id}/close`, { method: "POST" }),
  refund: (id: string, reason: string) =>
    request(`/payments/orders/${id}/refund`, {
      method: "POST",
      body: { reason, confirmed: true },
    }),
};
export const entitlementLabels: Record<string, string> = {
  automaticBookkeeping: "自动记账",
  cloudSync: "云同步",
  multiDevice: "多设备",
  aiAnalysis: "AI 分析",
  voiceAi: "语音 AI",
  ocr: "账单识别",
  advancedReport: "高级报表",
  familyBook: "共享账本",
  dataExport: "数据导出",
  basicBackup: "备份",
  adFree: "无广告",
  customTheme: "主题",
};
export const orderLabels: Record<string, string> = {
  created: "已创建",
  pending: "待支付",
  paid: "已支付",
  failed: "失败或已关闭",
  refunded: "已退款",
  requested: "退款处理中",
  succeeded: "退款完成",
};
