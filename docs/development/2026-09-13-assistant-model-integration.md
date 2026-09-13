# 记账助手后端模型联调

## 结果

- 新增 `server/src/assistant_ai.ts`，以 `AssistantModelProvider` 抽象模型调用；默认 `DeepSeekCompatibleProvider` 兼容 DeepSeek 和 OpenAI-compatible 中转站。
- 新增 `POST /api/v1/assistant/chat`。请求先经过服务端授权、长度/次数/频率/会员和硬边界检查，再使用数据库中的 `systemPrompt` 调用模型。
- `assistant_requests` 保存授权结果，`assistant_chat_responses` 保存模型结果。两张表都按用户和 `requestId` 做幂等校验，Flutter 的授权和 chat 两步不会重复扣次数。
- 模型输出再次经过硬边界过滤；模型异常返回 503，Flutter 降级为本地规则回复。规则引擎仍负责真实记账、预算和收支查询，模型不能宣称已写入账单。
- `GET/PUT /api/v1/admin/assistant/config` 可在后端调整系统提示词、边界回复、次数、频率和会员功能，公共配置接口不会泄露系统提示词。

## 部署配置

服务端进程通过环境变量读取密钥，禁止把 key 写入仓库、数据库、Flutter 资源或构建参数：

```text
DEEPSEEK_API_KEY=<secret>
DEEPSEEK_BASE_URL=https://api.deepseek.com   # 可选，中转站地址
DEEPSEEK_MODEL=deepseek-chat                # 可选
ASSISTANT_ADMIN_TOKEN=<至少 32 字符>          # 配置管理接口
```

Flutter 构建时只需要后端地址和登录态，不需要模型 key：

```text
--dart-define=SHARED_API_BASE_URL=https://your-api.example.com
```

## 联调与验证

- 使用桌面 `apikey.md` 中的 key 仅注入临时服务进程环境变量，真实调用 `/api/v1/assistant/chat` 成功，返回 `source=deepseek` 和非空消息；服务停止后环境变量失效。
- 服务端 `npm run typecheck`、`npm test` 通过，包含自定义后端提示词注入、模型调用、重放幂等和次数不重复扣减测试。
- Flutter 助手相关 `flutter analyze` 和测试通过。

## 后续接入

替换第三方模型时实现 `AssistantModelProvider.complete` 并在服务端注入即可；前端接口和策略层不需要改动。图片票据识别、语音转文字和多轮上下文仍按后续阶段单独接入。
