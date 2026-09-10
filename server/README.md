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

## API 概览

除注册/登录外的接口使用 `Authorization: Bearer <session>`。金额统一使用整数分，成员身份由会话取得，服务端不接受客户端传入操作者身份。

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| POST | `/api/v1/auth/register` | 注册并返回会话 |
| POST | `/api/v1/auth/login` | 登录并返回会话 |
| POST | `/api/v1/auth/logout` | 撤销当前会话 |
| GET | `/api/v1/auth/me` | 当前用户 |
| GET/POST | `/api/v1/books` | 查看可访问账本 / 创建共享账本并导入初始快照 |
| GET/PATCH | `/api/v1/books/:id/members` | 成员列表、角色变更或移除 |
| GET/POST/DELETE | `/api/v1/books/:id/invitations` | 创建、查看、撤销邀请 |
| POST | `/api/v1/invitations/accept` | 接受一次性七日邀请 |
| GET | `/api/v1/books/:id/snapshot` | 获取完整快照 |
| GET | `/api/v1/books/:id/changes?cursor=N` | 按游标拉取版本变化 |
| POST | `/api/v1/books/:id/mutations` | 提交幂等操作，版本冲突返回 `409` |
| GET | `/api/v1/books/:id/logs` | 查看共享操作日志 |

服务端在同一 SQLite 事务内执行权限检查、`operationId` 幂等判断、账务变更、余额/目标重算、版本递增和变更日志。共享创建限制所有者自建活跃账本数量；受邀加入不占该额度。公网 TLS、生产数据库备份、监控、支付、短信、附件存储和企业报税不在本轮范围。
