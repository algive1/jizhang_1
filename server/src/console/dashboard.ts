import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "../store.js";
import { authorize } from "./auth.js";

export function registerDashboard(app: FastifyInstance, store: Store) {
  const count = (sql: string, ...args: unknown[]) =>
    (store.db.prepare(sql).get(...args) as { n: number }).n;
  app.get("/dashboard", async (request) => {
    authorize(store, request, "dashboard:view");
    const { days } = z
      .object({
        days: z.coerce
          .number()
          .pipe(z.union([z.literal(7), z.literal(30)]))
          .default(7),
      })
      .parse(request.query);
    const today =
      Math.floor((store.now() + 8 * 3600) / 86400) * 86400 - 8 * 3600;
    const since = today - (days - 1) * 86400;
    const autoCounts = store.db
      .prepare(
        "SELECT COUNT(DISTINCT CASE WHEN stage='candidate' THEN user_id||':'||trace_id END) AS candidates,COUNT(DISTINCT CASE WHEN stage='saved' AND status='success' THEN user_id||':'||trace_id END) AS saved,COUNT(DISTINCT CASE WHEN stage='candidate' AND EXISTS(SELECT 1 FROM console_events result WHERE result.user_id=console_events.user_id AND result.trace_id=console_events.trace_id AND result.stage='saved' AND result.status='success') THEN user_id||':'||trace_id END) AS converted FROM console_events WHERE occurred_at>=? AND occurred_at<?",
      )
      .get(today * 1000, (today + 86400) * 1000) as {
      candidates: number;
      saved: number;
      converted: number;
    };
    return {
      generatedAt: store.now(),
      timezone: "Asia/Shanghai",
      days,
      metrics: {
        totalUsers: count(
          "SELECT COUNT(*) AS n FROM users WHERE username NOT LIKE 'deleted_%'",
        ),
        newUsers: count(
          "SELECT COUNT(*) AS n FROM users WHERE created_at>=? AND username NOT LIKE 'deleted_%'",
          today,
        ),
        dau: count(
          "SELECT COUNT(DISTINCT installation_id) AS n FROM analytics_events WHERE occurred_at>=? AND occurred_at<?",
          today,
          today + 86400,
        ),
        mau: count(
          "SELECT COUNT(DISTINCT installation_id) AS n FROM analytics_events WHERE occurred_at>=? AND occurred_at<?",
          today - 29 * 86400,
          today + 86400,
        ),
        bookkeeping: count(
          "SELECT COUNT(*) AS n FROM analytics_events WHERE event_name='bookkeeping_saved' AND occurred_at>=? AND occurred_at<?",
          today,
          today + 86400,
        ),
        autoSaved: autoCounts.saved,
        autoSuccessRate: autoCounts.candidates
          ? autoCounts.converted / autoCounts.candidates
          : null,
        aiCalls: count(
          "SELECT COUNT(*) AS n FROM console_ai_calls WHERE created_at>=?",
          today,
        ),
        aiSuccessRate: null,
        backupSuccessRate: null,
        errors:
          count(
            "SELECT COUNT(*) AS n FROM diagnostic_events WHERE level='error' AND created_at>=?",
            today,
          ) +
          count(
            "SELECT COUNT(*) AS n FROM console_events WHERE status='failed' AND occurred_at>=? AND occurred_at<?",
            today * 1000,
            (today + 86400) * 1000,
          ),
        latestVersion:
          (
            store.db
              .prepare(
                "SELECT version_name AS version FROM console_releases WHERE platform='android' AND status='published' AND rollout=100 ORDER BY version_code DESC LIMIT 1",
              )
              .get() as { version: string } | undefined
          )?.version ?? null,
      },
      trends: store.db
        .prepare(
          `WITH RECURSIVE dates(day) AS (SELECT date(:since,'unixepoch','+8 hours') UNION ALL SELECT date(day,'+1 day') FROM dates WHERE day<date(:today,'unixepoch','+8 hours')),
        registrations AS (SELECT date(created_at,'unixepoch','+8 hours') AS day,COUNT(*) AS n FROM users WHERE created_at>=:since AND created_at<:until AND username NOT LIKE 'deleted_%' GROUP BY day),
        activity AS (SELECT date(occurred_at,'unixepoch','+8 hours') AS day,COUNT(DISTINCT installation_id) AS active,SUM(CASE WHEN event_name='bookkeeping_saved' THEN 1 ELSE 0 END) AS bookkeeping FROM analytics_events WHERE occurred_at>=:since AND occurred_at<:until GROUP BY day),
        automatic AS (SELECT date(occurred_at/1000,'unixepoch','+8 hours') AS day,
          COUNT(DISTINCT CASE WHEN stage='saved' AND status='success' THEN user_id||':'||trace_id END) AS saved,
          COUNT(DISTINCT CASE WHEN stage='candidate' THEN user_id||':'||trace_id END) AS candidates,
          COUNT(DISTINCT CASE WHEN stage='candidate' AND EXISTS(SELECT 1 FROM console_events result WHERE result.user_id=console_events.user_id AND result.trace_id=console_events.trace_id AND result.stage='saved' AND result.status='success') THEN user_id||':'||trace_id END) AS converted
          FROM console_events WHERE occurred_at>=:since*1000 AND occurred_at<:until*1000 GROUP BY day),
        ai AS (SELECT date(created_at,'unixepoch','+8 hours') AS day,COUNT(*) AS calls FROM console_ai_calls WHERE created_at>=:since AND created_at<:until GROUP BY day)
        SELECT dates.day,COALESCE(registrations.n,0) AS users,COALESCE(activity.active,0) AS active,COALESCE(activity.bookkeeping,0) AS bookkeeping,COALESCE(automatic.saved,0) AS autoSaved,
          CASE WHEN automatic.candidates>0 THEN 1.0*automatic.converted/automatic.candidates ELSE NULL END AS autoSuccessRate,COALESCE(ai.calls,0) AS aiCalls
        FROM dates LEFT JOIN registrations USING(day) LEFT JOIN activity USING(day) LEFT JOIN automatic USING(day) LEFT JOIN ai USING(day) ORDER BY dates.day`,
        )
        .all({ since, today, until: today + 86400 }),
      versions: store.db
        .prepare(
          "SELECT app_version AS name,COUNT(*) AS value FROM console_devices WHERE last_seen_at>=? GROUP BY app_version ORDER BY value DESC LIMIT 30",
        )
        .all(today - 29 * 86400),
      sources: store.db
        .prepare(
          "SELECT package_name AS name,COUNT(DISTINCT user_id||':'||trace_id) AS value FROM console_events WHERE stage='candidate' AND occurred_at>=? GROUP BY package_name ORDER BY value DESC LIMIT 30",
        )
        .all(since * 1000),
      integration: {
        devices: "需 APP heartbeat 上报",
        autoAccounting:
          "需 APP 统一事件链上报；成功率按今日候选事件链最终写库结果统计",
        ai: "上游调用次数已记录；legacy provider 无 usage 时 Token/成本未知；业务识别成功率仍需回执",
        backup: "TODO：暂无备份任务结果遥测；已有快照元数据可查看",
      },
    };
  });
  app.get("/ledger/statistics", async (request) => {
    authorize(store, request, "transaction:statistics");
    return {
      scope: "仅服务端已同步的共享账本；私人本地账单与云备份正文不读取",
      books: store.db
        .prepare(
          "SELECT type,COUNT(*) AS count FROM books WHERE is_archived=0 GROUP BY type",
        )
        .all(),
      entities: store.db
        .prepare(
          "SELECT kind,COUNT(*) AS count FROM entities WHERE deleted=0 GROUP BY kind",
        )
        .all(),
      transactionSources: store.db
        .prepare(
          "SELECT COALESCE(json_extract(data_json,'$.source'),'unknown') AS source,COUNT(*) AS count FROM entities WHERE kind='transactions' AND deleted=0 GROUP BY source",
        )
        .all(),
    };
  });
}
