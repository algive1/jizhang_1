# 管理控制台交付与接入说明

日期：2026-10-06。仓库已有正式业务服务，本次依据需求第 34 条保留 Node/Fastify/SQLite，新增独立 Arco Web 控制台。不宣称使用 ContiNew、Spring Boot、Sa-Token、MyBatis、MySQL 或 Redis。

## 已实现的管理闭环

| 范围 | 数据库与服务端 | 页面与行为 |
| --- | --- | --- |
| P0 身份与权限 | 独立 scrypt 管理密码、8 小时哈希会话、六类角色、权限逐接口校验、登录记录、操作审计 | 登录/退出、权限菜单、角色调整、管理员创建/禁用/改密/重置；在线会话与撤销；保护最后一个超级管理员 |
| P0 用户 | 引用现有 users；用户状态表、会话最近活跃、设备 heartbeat、现有会员状态 | 搜索、筛选、排序、分页、详情、单个/批量禁用与解禁；批量事务至多 100 人，存在无效目标则整体拒绝 |
| P0 工作台 | 现有 analytics、用户和诊断数据聚合；Asia/Shanghai 日界；缺失回执用 null | 7/30 天用户/记账/自动写库成功率/AI 调用趋势、设备版本与支付来源分布；loading / error / empty |
| P0 版本 | 数据库存草稿、并发修订校验、发布/下线、稳定分桶灰度、语义版本与最低版本校验 | Android/iOS 共用版本列表；独立详情与草稿编辑，发布后内容锁定；灰度不提高全局最低版本；下线回退 |
| P0 配置 | 严格白名单、不可变修订、乐观版本校验、发布指针与上一全量回退 | 新建、编辑、发布、下线、历史、回滚；公开下载 API |
| P1 诊断 | 用户/trace 作用域、毫秒时序、批次事务、事件 ID 幂等、相关事件引用校验、单 trace 200 条上限 | 通知、页面、合并、自动事件、失败案例、时间轴、复制诊断；不存在的阶段标记未上报 |
| P1 规则 | 声明式规则 JSON 严格校验，包名/节点/文本/金额/商户规则/版本范围/优先级 | 版本修订与灰度下载；保持本地核心规则不变 |
| P2 AI | 后台模型路由、备用模型循环校验、Endpoint 精确白名单、环境密钥引用、真实 usage 与失败尝试日志 | 模型配置、Prompt 修订、按日/周/月趋势、模型/功能成本、分页日志与独立调用详情；不存输入输出和密钥 |
| P3 辅助 | 现有备份元数据、脱敏 support tickets、公告表；FAQ/Banner/活动配置表 | 备份存储总量、反馈详情/状态处理、公告发布到既有消息中心、运营配置；不会隐式发送 Push |
| P3 Push | 指定用户草稿、Provider 配置检查、事务入队、任务关联、重复发布幂等；复用原 outbox / Worker | 独立预览、明确发布、投递统计与分页设备任务、停止未发送任务；不暴露 token / 密钥 / 原始错误 |
| 统一基础 | 服务端分页上限 100、排序白名单、查询索引、审计/遥测留存、注销删除关联遥测 | GiTable 搜索/刷新/列设置/固定列/分页/当前页 CSV（防公式注入）、独立详情页、移动端菜单与表格 |

超级管理员默认不拥有 `ledger:transaction:view-sensitive`；目前未建立私密流水浏览接口。账务中心只汇总已同步共享实体，不解包云快照。

## 尚未完成的范围

以下是实际未接入项，不是已经完成的功能。仓库 APP 核心文件本轮未改。

- Flutter/Kotlin heartbeat、统一 trace、诊断同意设置、离线重试/TTL：后台接收 API 可用，APP 不会自动上传新事件。
- Kotlin 远程规则应用、签名/安全正则验证、缓存与本地默认回退：下载 API 可用，但规则未影响 APP 识别。
- Flutter 远程功能门控、FAQ/Banner/活动渲染：接口已持久化，APP 消费需要下一次增量接入。
- 加密备份 v3、客户端密钥/恢复方案、备份任务和恢复结果上报：当前 gzip 是压缩，后台只返回大小、时间、版本、SHA-256，不能据此计算备份成功率。
- OCR / ASR 本地效果回执与 AI 业务识别准确率：上游调用成功不等于账单解析正确，工作台识别成功率仍为未知。
- Prompt 的全场景接入、实验效果分析：后台模型路由已接入 `assistant / insight / natural-language` 场景，既有 System Prompt 约束优先。分类/商户/OCR/ASR 的本地回执尚未接入；灰度按稳定用户分桶，experiment 字段只作元数据，尚无实验效果报表。
- 记账的商户/分类明细分析不启用私密账单采集；账户级明细授权和数据使用授权需另行建设。
- 批量发布、全量导出、菜单/部门/字典/定时任务等通用平台完整管理仍未实现。菜单目前是权限驱动的固定模块目录，当前表格 CSV 只导出当前页可见字段。
- Push 尚无广播分群、定时发送、草稿编辑、设备点击/展示回执。已支持指定用户的正式发布流程；真实供应商凭据与 APP 设备注册需部署方配置。本轮没有向实际用户发送消息或推送。
- MySQL / Redis / Java 框架迁移不在本次实际实现中；容器部署配置尚未在本机运行。

## APP 事件链协议

已登录 APP 使用原有 Bearer 用户令牌；管理账号令牌不能使用这些接口。所有示例字段均为协议示例，不是后台默认业务数据。

```http
POST /api/v1/auto-accounting/events
Authorization: Bearer <APP session>
Content-Type: application/json
```

```json
{
  "diagnosticConsent": true,
  "events": [{
    "eventId": "device-event-uuid",
    "traceId": "payment-journey-uuid",
    "occurredAt": 1791280800000,
    "stage": "matched",
    "status": "success",
    "packageName": "com.example.payment",
    "appVersion": "1.2.0",
    "ruleVersion": 31,
    "metadata": {
      "relatedEventIds": ["notification-event-id", "page-event-id"],
      "confidence": 0.98,
      "durationMs": 450
    }
  }]
}
```

相关事件必须已存在或在同批次中，并属于同一用户和 trace。例中的时刻是格式示例；实际请求使用当前设备毫秒时刻。事件最多回溯 30 天，允许未来 5 分钟时钟偏差，批次最多 100 条/128 KiB。拒绝 userId、merchant、notification、页面文本、聊天、账户、手机号、截图路径等额外字段。

阶段：`notification / page / parsed / matched / candidate / overlay / confirmed / ignored / saved / synced`。

结果：`success / failed / pending`。失败原因是受控代码：`amount_parse_failed / merchant_parse_failed / page_not_matched / notification_missing / duplicate / event_match_failed / overlay_failed / user_ignored / database_write_failed / sync_failed / permission_missing / timeout / unknown`。

可选 metadata：结构 SHA-256、节点类型白名单、规则命中、金额整数分、置信度、耗时、相关事件 ID。不要把原始候选对象直接序列化上传。

## 配置和设备接口

- `POST /api/v1/app/heartbeat`：原用户鉴权，installationId（32 位十六进制）、platform、appVersion，可选 Android/品牌/型号/自动记账与云备份开关；没有上报的开关保存为 null。
- `GET /api/v1/app/config?installationId=...` / `rules`：公开非敏感配置，返回 `{documents:[{key,version,payload}]}`；灰度未命中回退上一全量版本，没有上一版本则不返回该项。
- `GET /api/v1/app/update?platform=android&version=1.2.0&installationId=...`：既有响应格式不变；无 installationId 只命中全量发布，数据库未发布时回退原环境变量。
- `GET /api/v1/app/operations?kind=faq|banner|activity`：只返回启用的运营内容，APP 渲染尚未接入。

客户端应校验 schema 和适用范围、缓存最后可用配置、限制重试、在失败时回退本地默认；不以服务端可达性阻断离线记账。

## 验证与交付

测试命令见 [admin-web README](../admin-web/README.md)。浏览器测试使用独立内存服务，测试数据不进入真实开发库。后端全量 65 项、浏览器 7 项全部通过；前后端 typecheck/build、前端和新增控制台模块 lint 通过。[验收记录和截图](qa/admin-console-2026-10-06/README.md)保留了桌面与 390 px 移动视口证据。

阶段提交：`17660cb`（P0 后端）、`4fedf2e`（P0 前端）、`22c7ac4`（P1）、`d80d432`（AI）、`9322b6b`（备份/反馈/运营）、`9d04f87`（纯格式整理）、`6c146d7`（详情、密码、会话、批量用户和 Push）。部署说明与验收证据单独提交。用户原有未提交的 Flutter/Kotlin/会员/其他改动均保留。

构建仍有 Arco / ECharts 大分包提示（约 862 / 554 KiB，gzip 256 / 190 KiB）；页面按路由懒加载。Docker 本机未安装，容器运行尚未验证。
