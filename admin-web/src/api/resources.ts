import type { TableColumnData } from "@arco-design/web-vue";
import type { Query, Page } from "./types";
import { api } from "./console";
export type ResourceRow = Record<string, string | number | boolean | null>;
export interface ResourceDefinition {
  title: string;
  description: string;
  permission: string;
  rowKey: string;
  columns: TableColumnData[];
  load: (query: Query) => Promise<Page<ResourceRow>>;
  notice?: string;
}
const columns = (values: Array<[string, string]>): TableColumnData[] =>
  values.map(([dataIndex, title]) => ({
    dataIndex,
    title,
    width: dataIndex.includes("Id") ? 220 : 150,
  }));
export const resources: Record<string, ResourceDefinition> = {
  "/diagnostics": {
    title: "调试日志",
    description:
      "复用现有通用诊断事件；为保护隐私，仅返回事件元数据，不返回 message 和 data_json。",
    permission: "auto-accounting:event:list",
    rowKey: "eventId",
    columns: columns([
      ["userId", "用户 ID"],
      ["eventId", "事件 ID"],
      ["occurredAt", "发生时间"],
      ["level", "级别"],
      ["kind", "事件类型"],
    ]),
    load: (query) => api.list("/diagnostics", query),
  },
  "/devices": {
    title: "用户设备",
    description: "由已登录 APP 上报设备版本与功能状态。缺失字段表示尚未上报。",
    permission: "device:list",
    rowKey: "installationId",
    columns: columns([
      ["userId", "用户 ID"],
      ["installationId", "安装 ID"],
      ["platform", "平台"],
      ["appVersion", "APP 版本"],
      ["androidVersion", "Android 版本"],
      ["brand", "品牌"],
      ["model", "设备型号"],
      ["autoEnabled", "自动记账（1 开 / 0 关）"],
      ["backupEnabled", "云备份（1 开 / 0 关）"],
      ["lastSeenAt", "最近活跃"],
    ]),
    load: (query) => api.list("/devices", query),
  },
  "/audit": {
    title: "操作日志",
    description: "管理员身份、操作、目标与时间。日志不保存请求正文和密钥。",
    permission: "system:audit",
    rowKey: "id",
    columns: columns([
      ["id", "日志 ID"],
      ["actor", "操作人"],
      ["action", "操作"],
      ["target", "目标"],
      ["createdAt", "时间"],
    ]),
    load: (query) => api.list("/audit", query),
  },
  "/backups": {
    title: "云备份",
    description: "查看快照大小、版本和校验值。管理接口不返回备份内容。",
    permission: "backup:status:view",
    rowKey: "datasetId",
    notice:
      "现有备份为 gzip 压缩，尚未端到端加密。加密协议、任务遥测和恢复记录待 APP 接入。",
    columns: columns([
      ["userId", "用户 ID"],
      ["datasetId", "数据集 ID"],
      ["revision", "数据版本"],
      ["hasSnapshot", "快照（1 有 / 0 无）"],
      ["size", "存储字节数"],
      ["checksum", "SHA-256"],
      ["updatedAt", "最近备份"],
    ]),
    load: (query) => api.list("/backups", query),
  },
  "/feedback": {
    title: "用户反馈",
    description: "查看已脱敏反馈，联系方式不会返回管理页面。",
    permission: "feedback:view",
    rowKey: "id",
    columns: [
      ...columns([
        ["subject", "主题"],
        ["userId", "用户 ID"],
        ["status", "状态"],
        ["appVersion", "APP 版本"],
        ["updatedAt", "更新时间"],
      ]),
      { title: "操作", slotName: "actions", fixed: "right", width: 100 },
    ],
    load: (query) => api.list("/feedback", query),
  },
};
