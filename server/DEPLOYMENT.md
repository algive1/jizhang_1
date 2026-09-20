# 好好记账服务端部署

## 首次部署
1. 复制 `.env.example` 为 `.env`，至少设置强随机 `ADMIN_TOKEN`、域名及实际启用的支付/推送/AI密钥。
2. 生产环境不要把密钥提交到 Git；AI Provider 后台只保存密钥对应的环境变量名。
3. 执行 `docker compose -f compose.server.yml up -d --build`。
4. 使用 `/ready` 确认服务就绪，再开放流量。

## 升级
升级前备份 `LEDGER_DB_PATH`。SQLite 使用 WAL；备份应使用项目备份脚本或 SQLite backup API，不要在运行时只复制主 db 文件而忽略 WAL。
拉取新版本后重新构建并启动，确认 readiness、后台 system health、数据库 quick_check 后再结束维护窗口。

## 回滚
应用镜像可以回滚，但数据库迁移原则上只向前兼容。重大 schema 变更前必须保留可恢复备份。恢复数据库时先停止 API，恢复完整备份后再启动旧镜像。

## 性能配置
`SQLITE_BUSY_TIMEOUT_MS` 默认 5000；`SQLITE_SYNCHRONOUS` 默认 NORMAL；`SQLITE_WAL_AUTOCHECKPOINT` 默认 1000。单实例 SQLite 适合当前部署；如果写入并发、数据量或多实例需求明显增长，应迁移到支持多写节点的数据库，而不是让多个容器直接共享同一个 SQLite 文件。

## 安全
普通管理员使用 `ADMIN_PRINCIPALS_JSON` 的最小权限角色。具体流水和投资数据只允许超级管理员，并需要先申请 5 分钟临时敏感访问授权；访问原因和读取行为都会写入审计日志。
