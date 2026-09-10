# 好好记账开发文档入口

更新时间：2026-09-09

这里是本项目唯一的当前开发文档目录。后续开发、审查和交接先阅读本文件，再按任务进入对应文档。

## 当前文档优先级

1. [CURRENT_STATUS.md](CURRENT_STATUS.md)：当前真实完成度、验证结果和未完成边界。
2. [ARCHITECTURE.md](ARCHITECTURE.md)：项目框架、数据结构、路由、调用链和架构风险。
3. [PRODUCT_LOGIC.md](PRODUCT_LOGIC.md)：账本、自动记账、智能分类和语音记账的产品口径。
4. [UI_HOME_SPEC.md](UI_HOME_SPEC.md)：首页与快速记账的当前 UI 约束。
5. [release/ANDROID_RELEASE.md](release/ANDROID_RELEASE.md)：Android 构建、安装和签名说明。

`archive/` 下的文件只用于追溯历史需求、审计过程和旧方案，不代表当前源码状态；如果历史文档与当前代码冲突，以当前源码、测试结果和 `CURRENT_STATUS.md` 为准。

## 目录约定

```text
docs/development/
├── README.md                 # 本入口和文档规则
├── CURRENT_STATUS.md         # 唯一当前状态基线
├── ARCHITECTURE.md           # 架构与功能全景
├── PRODUCT_LOGIC.md          # 当前产品逻辑
├── UI_HOME_SPEC.md           # 当前首页设计约束
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

截至 2026-09-09，`flutter analyze --no-pub` 无问题，`flutter test --no-pub` 为 120 个测试全部通过，`flutter build apk --release` 通过；`server/` 的 typecheck、真实 HTTP test 和 build 也通过。最新 Android APK 为 72,799,794 bytes，SHA-256 为 `ea4762b9b8964bb6ebb015e4f1e79a6c9bad53747059e2dae878bf17d924d81c`。iOS 因当前机器没有完整 Xcode 未完成可重复构建验证；Android 截图来自 Pixel 7 模拟器，不是物理手机。
