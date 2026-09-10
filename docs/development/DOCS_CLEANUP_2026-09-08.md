# 开发文档整理记录

整理日期：2026-09-08

## 整理目标

统一开发文档入口，移除当前开发区中的历史状态冲突，避免后续开发继续引用过时的 schema、测试数量、APK hash 或已修复问题。

## 当前有效文档

- `README.md`：项目根入口，只保留项目简介、常用命令和开发文档链接。
- `docs/development/README.md`：开发文档唯一入口和维护规则。
- `docs/development/CURRENT_STATUS.md`：当前完成度、真实验证结果和未完成边界。
- `docs/development/ARCHITECTURE.md`：架构、功能、路由、数据结构和调用链全景。
- `docs/development/PRODUCT_LOGIC.md`：当前账本、自动记账、智能分类和语音记账逻辑。
- `docs/development/UI_HOME_SPEC.md`：首页与快速记账 UI 规范。
- `docs/development/release/ANDROID_RELEASE.md`：Android 构建、安装和签名规则。

## 文件处理结果

### 已移入当前开发目录

- 架构总览 → `ARCHITECTURE.md`
- 产品逻辑 → `PRODUCT_LOGIC.md`
- 首页 UI 规范 → `UI_HOME_SPEC.md`
- Android 发布说明 → `release/ANDROID_RELEASE.md`

### 已归档，不作为当前依据

- 阶段 1—13 原始需求 → `archive/requirements/`
- 旧审计、旧状态和旧资产审查 → `archive/audits/`
- 已完成的首页讨论/交接 → `archive/ui/`
- 已执行的资产分析计划 → `archive/plans/`
- 旧 Android 交付与打包说明 → `archive/release/`

### 已移出 App 开发文档体系

AiCoin 策略交接资料已移至 `docs/reference/aicoin/`，因为它与 Flutter App 的运行时、数据库和发布链路无关。

## 当前文档规则

历史文件可以用于追溯，但不能用来判断当前完成度。后续开发只从 `docs/development/README.md` 进入；每个任务完成后更新 `CURRENT_STATUS.md` 或新增带日期的专题文档，并记录实际验证命令和结果。

本次没有删除历史需求和审计正文：项目根目录没有 Git，直接删除会丢失不可恢复的上下文。它们已经从当前开发路径中隔离；如果未来确认不再需要历史追溯，可以在明确列出文件后再删除 `archive/` 中对应内容。

## 验证

- 根目录开发文档已清空，仅保留 `README.md`。
- 当前开发文档集中在 `docs/development/`。
- 参考资料集中在 `docs/reference/`。
- 已修正源码注释和当前文档中的旧路径引用。
- 文档整理不改变业务逻辑；后续仍以当前源码、测试和 `CURRENT_STATUS.md` 为准。
