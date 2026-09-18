# 本地共享账本服务

这是家庭/企业账本的本地联调后端，不包含公网部署配置，也不读取或写入任何 API key。

## 启动与检查

```bash
cd /Users/algive/jizhang_01/server
npm install
npm run typecheck
npm test
npm run build
npm run dev
```

默认监听 `127.0.0.1:8787`，SQLite 文件为 `server/data/shared-ledger.sqlite`。可以用 `PORT` 和 `LEDGER_DB_PATH` 指定端口与数据库路径；服务启动时会创建/迁移本地数据库表。Android 模拟器联调前执行 `adb reverse tcp:8787 tcp:8787`。

会员支付启用前，将微信商户号/证书和支付宝应用私钥、公钥通过运行时环境变量或受限文件注入；完整变量清单见 [会员中心支付审计记录](../docs/development/2026-09-13-membership-visual-payment-audit.md)。密钥不应写入仓库或 App，两个支付回调地址必须是公网 HTTPS。

## API 概览

除注册/登录外的接口使用 `Authorization: Bearer <session>`。金额统一使用整数分，成员身份由会话取得，服务端不接受客户端传入操作者身份。注册用户名会规范化为小写并限制为 3–40 位字母/数字/下划线，密码限制为 10–128 位；密码使用异步 scrypt 加盐哈希，session 有效期 30 天，服务端只保存 token 的 SHA-256 哈希。

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| POST | `/api/v1/auth/register` | 注册并返回会话 |
| POST | `/api/v1/auth/login` | 登录并返回会话 |
| POST | `/api/v1/auth/logout` | 撤销当前会话 |
| GET | `/api/v1/auth/me` | 当前用户 |
| POST | `/api/v1/diagnostics/events` | 已登录用户上传脱敏诊断事件（批量、按 `event_id` 幂等） |
| GET/POST | `/api/v1/books` | 查看可访问账本 / 创建共享账本并导入初始快照 |
| GET/PATCH | `/api/v1/books/:id/members` | 成员列表、角色变更或移除 |
| GET/POST/DELETE | `/api/v1/books/:id/invitations` | 创建、查看、撤销邀请 |
| POST | `/api/v1/invitations/accept` | 接受一次性七日邀请 |
| GET | `/api/v1/books/:id/snapshot` | 获取完整快照 |
| GET | `/api/v1/books/:id/changes?cursor=N` | 按游标拉取版本变化 |
| POST | `/api/v1/books/:id/mutations` | 提交幂等操作，版本冲突返回 `409` |
| GET | `/api/v1/books/:id/logs` | 查看共享操作日志 |
| GET | `/api/v1/membership/catalog` | 获取可编辑的套餐、权益和 FAQ 配置 |
| PUT | `/api/v1/admin/membership/catalog` | 使用 `MEMBERSHIP_ADMIN_TOKEN` 更新会员配置 |
| POST/GET | `/api/v1/membership/orders` | 按服务端 catalog 创建或查询会员支付订单 |
| GET | `/api/v1/membership/orders/:id` | 查询单笔会员订单状态 |
| GET | `/api/v1/membership/current` | 查询服务端确认后的会员有效期与权益 |
| POST | `/api/v1/payments/wechat/notify` | 微信支付回调验签、解密和入账 |
| POST | `/api/v1/payments/alipay/notify` | 支付宝异步通知验签和入账 |

服务端在同一 SQLite 事务内执行权限检查、`operationId` 幂等判断、账务变更、余额/目标重算、版本递增和变更日志。支付订单金额只从 `assets/config/membership_catalog.json` 或后台 catalog 读取；必须配置真实商户证书和公网 HTTPS 回调后才会向支付平台下单。公网 TLS、生产数据库备份、监控、短信、附件存储和企业报税仍需按部署环境配置。

当前账号边界：客户端登录/注册入口仍位于共享账本页，个人本地账本不强制登录；服务端尚未实现手机号/邮箱验证码、找回密码、修改密码、账号注销、第三方登录或多设备会话管理。诊断上传接口只接受有限 primitive 字段，并拒绝包含 token、密码、通知、账户、卡号、手机号、路径和堆栈等敏感键；本地诊断日志不等同于公网 Crashlytics/Sentry 监控。
