# 记账助手页面与策略层

## 已完成

- 首页通知铃铛替换为可复用的 `AssistantEntryButton`，使用本地机器人素材，并将助手消息、待处理账单提醒、支付通知处理错误映射为红点状态。
- 新增 `/assistant` 页面：欢迎气泡、快捷入口、消息持久化、规则记账成功卡片、真实流水修改/详情入口、预算/收支/导出/会员入口，以及图片、附件、语音的真实选择或开发中提示。
- 新增 `AssistantEngine` 接口和 `RuleBasedAssistantEngine`。自然语言记账只在金额、分类、账户都能唯一确认且 `QuickBookkeepingService` 成功落库后显示成功卡片；卡片按真实流水 ID 查询。
- 机器人图标和叶片装饰均为本地资源：`assets/images/assistant-bot-icon.png`、`assets/images/assistant-chat-leaf-decoration.png`。
- 新增后端 `assistant_policy` 模块和 `assets/config/assistant_policy.json`：默认系统提示词、边界回复、单条长度、每日次数、每分钟频率、会员功能列表均可配置。
- 后端提供：
  - `GET /api/v1/assistant/config`：公开运行限制，不返回系统提示词。
  - `GET/PUT /api/v1/admin/assistant/config`：管理员读取/更新完整策略，需要 `ASSISTANT_ADMIN_TOKEN`。
  - `PUT /api/v1/admin/assistant/memberships/:userId`：由受信任的支付/运营服务授予助手会员资格，客户端不能自报支付成功。
  - `POST /api/v1/assistant/authorize`：鉴权、幂等、次数、频率、边界和会员功能授权。
- Flutter 在配置了 `SHARED_API_BASE_URL` 且用户已登录时调用后端授权；离线或本地模式仍使用本地默认边界与每日 30 次限制。语音入口按会员策略检查，未授权时打开统一会员开通弹窗。

## 验证

- `flutter analyze --no-pub lib/features/assistant lib/features/home/presentation/home_page.dart lib/app/router/app_router.dart` 通过。
- `flutter test --no-pub test/assistant_engine_test.dart test/assistant_page_test.dart test/assistant_navigation_test.dart` 通过，覆盖真实流水落库、余额变化、会话持久化、未读、320/393/430 宽度、键盘和会员弹窗。
- `npm test -- --test-name-pattern=助手` 通过，覆盖服务端边界回复、幂等、会员授权、配置管理和提示词不泄露。
- `npm run typecheck` 通过。
- `flutter build apk --debug --no-pub` 通过。

## 当前边界

- 当前已接入后端 OpenAI-compatible 模型适配层：服务端通过 `DEEPSEEK_API_KEY`（以及可选的 `DEEPSEEK_BASE_URL`、`DEEPSEEK_MODEL`）调用模型，Flutter 永不持有 key。未配置 key 或模型不可用时，前端退回确定性的本地规则回复，不伪造模型成功或真实记账结果。
- 图片票据识别、文件上传、语音转文字仍使用已有能力或明确提示开发中；语音入口当前按默认会员策略弹出开通提示。
- 后端会员授权接口需要支付服务或管理员在验证支付后调用，当前本地会员仓库仍是离线 Free 快照。
