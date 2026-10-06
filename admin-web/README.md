# 好好记账 Web 管理控制台

独立 Vue 3 / TypeScript / Vite / Arco 前端，接入现有 Node 服务的 `/api/v1/console`。架构决定和 APP 数据边界见 [分析文档](../docs/admin-backend-analysis.md)，详细验收与未接入项见 [交付说明](../docs/admin-console-delivery.md)。

## 本地启动

Node.js 22.12+。在 `admin-web` 复制 `.env.example` 为 `.env.local`，填入至少 12 位初始化密码；无默认密码，密码不会编译进前端。

```powershell
# 终端一：repo/server
npm ci
node --env-file=../admin-web/.env.local --import tsx src/main.ts

# 终端二：repo/admin-web
npm ci
npm run dev
```

访问 `http://127.0.0.1:5173`。Vite 将 `/api` 同源代理至 8787，可用 `ADMIN_API_TARGET` 调整。首次启动空管理账号表时创建超级管理员；已有账号不会被环境变量重置。

`.env.local` 保持私有。前端只读取 `VITE_` 前缀变量，本工程不使用任何前端密钥变量。初始化后可以删除密码环境变量。

## 独立本地预览

在 `admin-web` 执行 `node scripts/prepare-preview.mjs`，它会生成忽略提交的 `.local/preview.env`，随机初始化密码在该文件中。使用独立空数据库，不添加测试用户或业务样例数据；初始账号为 `admin`。

```powershell
# 终端一：repo/server
node --env-file=../admin-web/.local/preview.env --import tsx src/main.ts

# 终端二：repo/admin-web
$env:ADMIN_API_TARGET='http://127.0.0.1:8792'
npm run dev -- --port 5180 --strictPort
```

访问 `http://127.0.0.1:5180`。预览密码只用于首次创建管理员，后续运行不会重置已修改的密码。此模式关闭 Push Worker；正式环境配置按上一节独立填写。

## 验证

```powershell
# repo/server
npm run typecheck
npm run build
npm test

# repo/admin-web
npm run lint
npm run typecheck
npm run build
npx playwright install chromium
npm test
```

浏览器测试启动独立内存数据库和端口 8790/5178，不访问开发数据库；测试账号和数据仅存在于 `tests/` 中。

## 容器部署

先复制 `server/.env.example` 为 `server/.env` 配置现有服务。在 `admin-web/.env.local` 配置初始化管理员，然后：

```powershell
docker compose --env-file .env.local up --build -d
```

访问 `http://127.0.0.1:8080`。API 不向主机直接暴露，SQLite 位于持久卷。公网使用现有 TLS 网关转发；该 compose 启动新的数据库卷，接入已有生产数据库时必须明确挂载现有数据卷，先备份，不能把空卷误当原业务数据。

当前环境未运行 Docker 验证；前后端构建和真实 HTTP / 浏览器流程已验证。

## Push 管理

后台创建指定用户的草稿，预览标题、正文、设备数量与 Provider 配置后，具有 `operations:push:publish` 权限的管理员才可发布。入队不代表发送成功，详情页显示真实 outbox 状态。停止仅取消尚未投递任务。密钥继续通过原服务的 FCM / APNs / Vendor 环境变量配置，后台不返回它们。

`PUSH_WORKER_ENABLED=false` 可关闭自动投递 Worker；测试和独立本地预览使用该设置。正式部署默认启动原有 Worker。FAQ 和公告的保存不会触发 Push。

## AI 配置

服务端设置 `AI_ENDPOINT_ALLOWLIST`（精确主机名列表）及密钥环境变量，如 `MY_MODEL_API_KEY`。后台模型只保存 `MY_MODEL_API_KEY` 的引用；启用前服务端验证白名单和密钥存在。价格单位为 USD / 百万 Token，成本按配置价格估算。未启用后台模型时继续使用现有 DeepSeek provider。

## APP 增量接入

APP 现有离线记账、原生浮层和本地规则不变。设备、自动记账链路、远程配置/规则、FAQ/Banner 的 APP 消费接入尚未实施，见交付说明中的协议和 TODO。当前云备份仍是 gzip 压缩，后台只查看元数据，不代表已实现端到端加密。
