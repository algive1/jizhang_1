import { request } from "./client";
export interface AssistantPolicy {
  enabled: boolean;
  systemPrompt: string;
  boundaryReply: string;
  maxInputLength: number;
  freeDailyLimit: number;
  memberDailyLimit: number;
  requestsPerMinute: number;
  memberFeatures: string[];
  maxTransactions: number;
  maxImageMb: number;
  maxImportFileMb: number;
  maxImportRows: number;
}
export interface AssistantPolicySnapshot {
  policy: AssistantPolicy;
  revision: string;
  assistantHardPrompt: string;
  transactionPrompt: string;
}
export const assistantApi = {
  read: () => request<AssistantPolicySnapshot>("/ai/assistant-policy"),
  save: (revision: string, policy: AssistantPolicy) =>
    request<AssistantPolicySnapshot>("/ai/assistant-policy", {
      method: "PUT",
      body: { revision, policy },
    }),
};
