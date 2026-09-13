# 自动记账引擎 MVP（2026-09-12）

已接入 Native Kotlin 微信页面识别、规则解析、商户归一化、分类/账户解析接口、去重与置信度模型，并通过 Flutter 后台 entrypoint 复用现有 Drift `QuickBookkeepingService` 保存账单。AccessibilityService 仅监听微信，500ms debounce，原始节点只在内存短暂存在；解析不确定、账户/分类失效或疑似重复时不会静默保存。当前悬浮层只展示识别结果并提供关闭操作，不提供未接通的“修改/记一笔”按钮。

验证：Android unit test/lint 与 Flutter analyze 已通过。真实微信版本、系统权限引导、完整可交互悬浮卡片和共享账本尚未联调。
