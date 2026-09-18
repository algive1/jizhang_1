# 好好记账开发文档入口

更新时间：2026-09-18

这里是本项目唯一的当前开发文档目录。后续开发、审查和交接先阅读本文件，再按任务进入对应文档。

最新任务：[2026-09-18 账户体系 Phase 1 账户基础层](2026-09-18-account-phase1-foundation.md)：新增 `features/account` 基础层（AccountUser / AccountSession 五态 / Secure Session / AccountSessionController），旧 `SessionRepository` 改为兼容门面，旧 Token 与旧用户无需重新登录；未改页面视觉、未改数据库结构、未开发 Phase 2～7。**本文件第「零」节记录了 Phase 1 源码从被忽略的 `jizhang_app/` 快照正式回落到 Git 根目录的过程，以及随之修掉的“401 后重启会复活被拒绝 Token”缺陷。** `flutter analyze` 无问题，`flutter test` 全量 `+453` 全通过（0 失败），服务端 11 项测试全通过。

上一轮任务：[2026-09-18 Android 自动记账与诊断日志收尾](2026-09-18-android-autobookkeeping-diagnostics.md)：修复首页编辑进入「记一笔」的 modal 层级、备注行和周期账单编辑联动；统一四类 Android 付款应用的待确认自动记账链路，并增加本地脱敏诊断日志与服务端上传。最新 APK 已安装到实体 Android 设备 `145a0a68`。

账号专题：[FEATURE_TREE_AND_GAPS.md](FEATURE_TREE_AND_GAPS.md) 的“账号与身份”章节已按源码复核注册、登录、`/auth/me`、登出、会话安全边界，以及找回密码、改密、联系方式绑定、注销等缺口。

上一轮任务：[2026-09-14 记一笔布局与首页实时流水修复](2026-09-14-entry-layout-and-live-transactions.md)、[2026-09-17 开通会员页原型复刻](2026-09-17-member-open-prototype.md)。

最新补充：[资产详情弹窗布局调整](2026-09-14-asset-detail-popup-layout.md)、[金额右对齐与 Android 卡顿排查](2026-09-14-amount-alignment-and-performance.md)。

源码交付：[源码打包交付（zip）](2026-09-18-source-package-delivery.md)：`./scripts/package_source.sh` 一键生成可交付源码包，已排除构建产物、依赖缓存、运行时数据库与 QA 截图归档，并修复了中文文件名双重编码问题。

## 当前文档优先级

1. [CURRENT_STATUS.md](CURRENT_STATUS.md)：当前真实完成度、验证结果和未完成边界。
2. [ARCHITECTURE.md](ARCHITECTURE.md)：项目框架、数据结构、路由、调用链和架构风险。
3. [PRODUCT_LOGIC.md](PRODUCT_LOGIC.md)：账本、自动记账、智能分类和语音记账的产品口径。
4. [UI_HOME_SPEC.md](UI_HOME_SPEC.md)：首页与快速记账的当前 UI 约束。
5. [release/ANDROID_RELEASE.md](release/ANDROID_RELEASE.md)：Android 构建、安装和签名说明。
6. [ANDROID_LOCAL_RUN.md](ANDROID_LOCAL_RUN.md)：本地 Android 模拟器一键启动、构建、安装和运行。
7. [2026-09-13-quick-add-prototype-redesign.md](2026-09-13-quick-add-prototype-redesign.md)：记一笔页面按原型重构的设计对照、改动、验证与遗留。

`archive/` 下的文件只用于追溯历史需求、审计过程和旧方案，不代表当前源码状态；如果历史文档与当前代码冲突，以当前源码、测试结果和 `CURRENT_STATUS.md` 为准。

## 目录约定

```text
docs/development/
├── README.md                 # 本入口和文档规则
├── CURRENT_STATUS.md         # 唯一当前状态基线
├── ARCHITECTURE.md           # 架构与功能全景
├── PRODUCT_LOGIC.md          # 当前产品逻辑
├── UI_HOME_SPEC.md           # 当前首页设计约束
├── ANDROID_LOCAL_RUN.md      # 本地模拟器一键运行
├── 2026-09-18-source-package-delivery.md  # 源码打包交付与边界
├── release/                  # 发布与安装
└── archive/                  # 历史资料，不作为当前依据
    ├── requirements/         # 阶段 1—13 原始需求
    ├── audits/               # 历史审查与资产审计
    ├── ui/                   # 已完成的 UI 讨论与交接
    ├── plans/                # 已执行的阶段计划
    └── release/              # 旧发布说明
```

## 后续开发规则

- 先确认当前源码和 `CURRENT_STATUS.md`，不要从 `archive/` 的旧数字或旧结论开始开发。
- 修改 Drift 表必须提升 `schemaVersion`、增加 forward-only migration、重新生成 `app_database.g.dart`，并补升级测试。
- 核心记账必须保持 `页面 → Provider → Service → Repository → DAO → SQLite` 的完整链路；不使用固定成功、Mock 数据或吞异常代替真实实现。
- 新功能涉及多账本时，先明确 `bookId`、账户余额和预算的归属口径，再修改 UI。
- 外部 API、支付、云同步、云 AI 和广告接入必须使用安全的运行时配置，不把密钥写入源码或文档。
- 每次完成一项开发任务，更新 `CURRENT_STATUS.md` 或新增带日期的专题文档，并记录实际验证命令与结果。

## 当前验证基线

截至 2026-09-18，`flutter analyze` 无问题，`flutter test --reporter compact` 为 408 个测试全部通过；Android `:app:testDebugUnitTest`、`:app:lintDebug` 和 Release APK 构建通过，APK 已安装并启动于实体设备 `145a0a68`。`server/` 的 typecheck、11 项测试和 build 通过。iOS 因当前机器没有完整 Xcode 未完成可重复构建验证；自动记账的支付 App 文案、无障碍节点、浮窗和后台存活仍需在真机上逐渠道验收。
