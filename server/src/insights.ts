import { createHash, randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Store } from './store.js';
import { ApiError, requireCondition as check } from './contract.js';
import { outOfScope } from './assistant_policy.js';
import {
  AssistantModelUnavailable,
  DeepSeekCompatibleProvider,
  type AssistantModelProvider,
} from './assistant_ai.js';
import {
  analyzeInsightContext,
  insightContextSchema,
  type InsightFeedbackProfile,
  type InsightProfile,
} from './insight_analysis.js';

type AuthUser = { id: string; username: string; displayName: string | null };
type Authenticate = (header: string | undefined) => AuthUser;

const intentValues = [
  'controlSpending',
  'understandSpending',
  'saveForGoal',
  'optimizeFinances',
  'familyFinances',
  'improveHabits',
  'recordLife',
] as const;
const focusValues = [
  'dining',
  'shopping',
  'travel',
  'healthHabits',
  'savings',
  'credit',
  'family',
  'learning',
] as const;
const toneValues = ['strict', 'balanced', 'quiet'] as const;
const feedbackValues = [
  'helpful',
  'inaccurate',
  'notRelevant',
  'dismissed',
  'specialExpense',
  'reimbursable',
  'confirmed',
  'rejected',
] as const;

export const insightPolicySchema = z.strictObject({
  homeMinScore: z.number().min(0).max(100).default(70),
  minConfidence: z.number().min(0).max(1).default(0.55),
  cooldownDays: z.number().int().min(1).max(90).default(7),
  aiEnabled: z.boolean().default(false),
  freeHistoryDays: z.number().int().min(30).max(3650).default(90),
  proHistoryDays: z.number().int().min(90).max(3650).default(730),
  promptVersion: z.string().trim().min(1).max(64).default('financial-insight-v1'),
}).refine(
  value => value.proHistoryDays >= value.freeHistoryDays,
  '会员历史范围不能短于免费用户',
);
export type InsightPolicy = z.infer<typeof insightPolicySchema>;

const profileSchema = z.strictObject({
  intents: z.array(z.enum(intentValues)).max(intentValues.length),
  focus: z.array(z.enum(focusValues)).max(focusValues.length),
  tone: z.enum(toneValues),
  configured: z.boolean(),
});
const feedbackSchema = z.strictObject({
  action: z.enum(feedbackValues),
  kind: z.string().trim().min(1).max(40).optional(),
  metadata: z
    .record(
      z.string(),
      z.union([z.string(), z.number(), z.boolean(), z.null()]),
    )
    .optional(),
});

const defaultPolicy: InsightPolicy = {
  homeMinScore: 70,
  minConfidence: 0.55,
  cooldownDays: 7,
  aiEnabled: false,
  freeHistoryDays: 90,
  proHistoryDays: 730,
  promptVersion: 'financial-insight-v1',
};

export function ensureInsightSchema(store: Store) {
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS insight_profiles(
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      intents_json TEXT NOT NULL,
      focus_json TEXT NOT NULL,
      tone TEXT NOT NULL,
      configured INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS insight_feedback(
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      insight_id TEXT NOT NULL,
      action TEXT NOT NULL,
      kind TEXT,
      metadata_json TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_insight_feedback_user_time
      ON insight_feedback(user_id,created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_insight_feedback_user_insight
      ON insight_feedback(user_id,insight_id);
    CREATE TABLE IF NOT EXISTS insight_ai_cache(
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      insight_id TEXT NOT NULL,
      prompt_version TEXT NOT NULL,
      body_hash TEXT NOT NULL,
      result_text TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY(user_id,insight_id,prompt_version,body_hash)
    );
    CREATE INDEX IF NOT EXISTS idx_insight_ai_cache_user_time
      ON insight_ai_cache(user_id,created_at DESC);
    CREATE TABLE IF NOT EXISTS insight_confirmed_items(
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      insight_id TEXT NOT NULL,
      body_hash TEXT NOT NULL,
      confirmed_at INTEGER NOT NULL,
      PRIMARY KEY(user_id,insight_id,body_hash)
    );
    CREATE INDEX IF NOT EXISTS idx_insight_confirmed_user_time
      ON insight_confirmed_items(user_id,confirmed_at DESC);
    CREATE TABLE IF NOT EXISTS insight_policy(
      id INTEGER PRIMARY KEY CHECK(id=1),
      policy_json TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    );
  `);
  const confirmedColumns = store.db.prepare(
    'PRAGMA table_info(insight_confirmed_items)',
  ).all() as Array<{ name: string; pk: number }>;
  const confirmedPrimaryKey = confirmedColumns
    .filter(column => column.pk > 0)
    .sort((a, b) => a.pk - b.pk)
    .map(column => column.name)
    .join(',');
  if (confirmedPrimaryKey !== 'user_id,insight_id,body_hash') {
    store.db.exec(`
      DROP TABLE IF EXISTS insight_confirmed_items;
      CREATE TABLE insight_confirmed_items(
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        insight_id TEXT NOT NULL,
        body_hash TEXT NOT NULL,
        confirmed_at INTEGER NOT NULL,
        PRIMARY KEY(user_id,insight_id,body_hash)
      );
      CREATE INDEX idx_insight_confirmed_user_time
        ON insight_confirmed_items(user_id,confirmed_at DESC);
    `);
  }

  const exists = store.db.prepare(
    'SELECT 1 FROM insight_policy WHERE id=1',
  ).get();
  if (!exists) {
    store.db.prepare(
      'INSERT INTO insight_policy(id,policy_json,updated_at) VALUES(1,?,?)',
    ).run(JSON.stringify(defaultPolicy), store.now());
  }
}

export function readInsightPolicy(store: Store): InsightPolicy {
  ensureInsightSchema(store);
  const row = store.db.prepare(
    'SELECT policy_json FROM insight_policy WHERE id=1',
  ).get() as { policy_json: string } | undefined;
  if (!row) return defaultPolicy;
  try {
    return insightPolicySchema.parse(JSON.parse(row.policy_json));
  } catch {
    return defaultPolicy;
  }
}

export function writeInsightPolicy(
  store: Store,
  input: unknown,
): InsightPolicy {
  ensureInsightSchema(store);
  const policy = insightPolicySchema.parse(input);
  store.db.prepare(
    'UPDATE insight_policy SET policy_json=?,updated_at=? WHERE id=1',
  ).run(JSON.stringify(policy), store.now());
  return policy;
}

function readProfile(store: Store, userId: string): InsightProfile {
  const row = store.db.prepare(
    'SELECT intents_json,focus_json,tone FROM insight_profiles WHERE user_id=?',
  ).get(userId) as {
    intents_json: string;
    focus_json: string;
    tone: 'strict' | 'balanced' | 'quiet';
  } | undefined;
  if (!row) return { intents: [], focus: [], tone: 'balanced' };
  return {
    intents: JSON.parse(row.intents_json) as string[],
    focus: JSON.parse(row.focus_json) as string[],
    tone: row.tone,
  };
}

function readFeedbackProfile(
  store: Store,
  userId: string,
): InsightFeedbackProfile {
  const rows = store.db.prepare(
    'WITH ranked AS ('
      + 'SELECT insight_id AS insightId,action,kind,'
      + 'ROW_NUMBER() OVER (PARTITION BY insight_id '
      + 'ORDER BY created_at DESC,rowid DESC) AS rn '
      + 'FROM insight_feedback WHERE user_id=?'
      + ') SELECT insightId,action,kind FROM ranked WHERE rn=1',
  ).all(userId) as Array<{
    insightId: string;
    action: string;
    kind: string | null;
  }>;
  const dismissedIds = new Set<string>();
  const kindAdjustments: Record<string, number> = {};
  for (const row of rows) {
    if (row.action === 'dismissed') dismissedIds.add(row.insightId);
    if (!row.kind) continue;
    const delta =
      row.action === 'helpful'
        ? 2
        : row.action === 'inaccurate'
          ? -4
          : row.action === 'notRelevant'
            ? -3
            : 0;
    kindAdjustments[row.kind] = Math.max(
      -12,
      Math.min(12, (kindAdjustments[row.kind] ?? 0) + delta),
    );
  }
  return { dismissedIds, kindAdjustments };
}

function hasActivePaidInsightMembership(
  store: Store,
  userId: string,
): boolean {
  const now = store.now();
  try {
    if (store.db.prepare(
      'SELECT 1 FROM membership_subscriptions WHERE user_id=? AND expires_at>?',
    ).get(userId, now)) return true;
    if (store.db.prepare(
      'SELECT 1 FROM apple_transactions WHERE user_id=? '
        + 'AND revoked_at IS NULL AND expires_at>?',
    ).get(userId, now)) return true;
  } catch {
    // Isolated tests may not initialize every payment table.
  }
  return false;
}

function hasActiveAssistantGrant(
  store: Store,
  userId: string,
): boolean {
  try {
    return Boolean(store.db.prepare(
      'SELECT 1 FROM assistant_memberships WHERE user_id=? AND expires_at>?',
    ).get(userId, store.now()));
  } catch {
    return false;
  }
}

function hasInsightAiAccess(store: Store, userId: string): boolean {
  return (
    hasActivePaidInsightMembership(store, userId) ||
    hasActiveAssistantGrant(store, userId)
  );
}

function readSharedAiQuota(
  store: Store,
  userId: string,
): { limit: number; used: number; remaining: number; day: string } | null {
  try {
    const row = store.db.prepare(
      'SELECT data_json FROM assistant_policy WHERE id=1',
    ).get() as { data_json: string } | undefined;
    if (!row) return null;
    const policy = JSON.parse(row.data_json) as {
      memberDailyLimit?: number;
    };
    const limit = Number(policy.memberDailyLimit ?? 0);
    if (!Number.isInteger(limit) || limit < 0) return null;
    const now = store.now();
    const day = new Date((now + 8 * 3600) * 1000)
      .toISOString()
      .slice(0, 10);
    const used =
      (store.db.prepare(
        'SELECT used FROM assistant_usage WHERE user_id=? AND day=?',
      ).get(userId, day) as { used: number } | undefined)?.used ?? 0;
    return {
      limit,
      used,
      remaining: Math.max(0, limit - used),
      day,
    };
  } catch {
    return null;
  }
}

function consumeSharedAiQuota(store: Store, userId: string) {
  return store.db.transaction(() => {
    const quota = readSharedAiQuota(store, userId);
    if (!quota) return null;
    check(quota.used < quota.limit, '今日 AI 分析次数已用完', 429);
    store.db.prepare(
      'INSERT INTO assistant_usage(user_id,day,used) VALUES(?,?,1) '
        + 'ON CONFLICT(user_id,day) DO UPDATE SET used=used+1',
    ).run(userId, quota.day);
    return { ...quota, used: quota.used + 1, remaining: quota.remaining - 1 };
  })();
}

function interpretationBodyHash(input: {
  insightId: string;
  kind: string;
  title: string;
  summary: string;
  analysis: string;
  meaning: string;
  suggestion?: string | null;
  evidence: Array<{
    label: string;
    value: number;
    baselineValue?: number | null;
    unit?: string | null;
  }>;
}) {
  return createHash('sha256')
    .update(JSON.stringify({
      insightId: input.insightId,
      kind: input.kind,
      title: input.title,
      summary: input.summary,
      analysis: input.analysis,
      meaning: input.meaning,
      suggestion: input.suggestion ?? null,
      evidence: input.evidence.map(value => ({
        label: value.label,
        value: value.value,
        baselineValue: value.baselineValue ?? null,
        unit: value.unit ?? null,
      })),
    }))
    .digest('hex');
}

const interpretationSchema = z.strictObject({
  insightId: z.string().trim().min(1).max(180),
  kind: z.enum([
    'financial',
    'behavior',
    'risk',
    'goal',
    'discovery',
    'positive',
    'life',
  ]),
  title: z.string().trim().min(1).max(160),
  summary: z.string().trim().min(1).max(1000),
  analysis: z.string().trim().min(1).max(1600),
  meaning: z.string().trim().min(1).max(1600),
  suggestion: z.string().trim().max(1000).nullable().optional(),
  evidence: z.array(z.strictObject({
    label: z.string().trim().min(1).max(100),
    value: z.number().finite(),
    baselineValue: z.number().finite().nullable().optional(),
    unit: z.string().trim().max(20).nullable().optional(),
  })).max(12),
});

export function registerInsightRoutes(
  app: FastifyInstance,
  store: Store,
  authenticate: Authenticate,
  modelProvider: AssistantModelProvider = new DeepSeekCompatibleProvider(),
) {
  ensureInsightSchema(store);

  app.post(
    '/api/v1/insights/analyze',
    { config: { rateLimit: { max: 30, timeWindow: '1 minute' } } },
    async request => {
      const user = authenticate(request.headers.authorization);
      const context = insightContextSchema.parse(request.body);
      const policy = readInsightPolicy(store);
      const profile = context.preferences ?? readProfile(store, user.id);
      const feedback = readFeedbackProfile(store, user.id);
      const paidMember = hasActivePaidInsightMembership(store, user.id);
      const historyDays = paidMember
        ? policy.proHistoryDays
        : policy.freeHistoryDays;
      const result = analyzeInsightContext(
        context,
        profile,
        feedback,
        policy,
        historyDays,
      );

      const now = store.now();
      const upsert = store.db.prepare(
        'INSERT INTO insight_confirmed_items('
          + 'user_id,insight_id,body_hash,confirmed_at'
          + ') VALUES(?,?,?,?) '
          + 'ON CONFLICT(user_id,insight_id,body_hash) DO UPDATE SET '
          + 'confirmed_at=excluded.confirmed_at',
      );
      store.db.transaction(() => {
        for (const item of result.items) {
          upsert.run(
            user.id,
            item.id,
            interpretationBodyHash({
              insightId: item.id,
              kind: item.kind,
              title: item.title,
              summary: item.summary,
              analysis: item.analysis,
              meaning: item.meaning,
              suggestion: item.suggestion ?? null,
              evidence: item.evidence.map(value => ({
                label: value.label,
                value: value.value,
                baselineValue: value.baselineValue ?? null,
                unit: value.unit ?? null,
              })),
            }),
            now,
          );
        }
        store.db.prepare(
          'DELETE FROM insight_confirmed_items '
            + 'WHERE user_id=? AND confirmed_at<?',
        ).run(user.id, now - 2 * 86400);
        store.db.prepare(
          'DELETE FROM insight_ai_cache '
            + 'WHERE user_id=? AND created_at<?',
        ).run(user.id, now - 30 * 86400);
      })();
      return result;
    },
  );

  app.get('/api/v1/insights/profile', async request => {
    const user = authenticate(request.headers.authorization);
    const row = store.db.prepare(
      'SELECT intents_json AS intents,focus_json AS focus,tone,configured,'
        + 'updated_at AS updatedAt FROM insight_profiles WHERE user_id=?',
    ).get(user.id) as
      | {
          intents: string;
          focus: string;
          tone: string;
          configured: number;
          updatedAt: number;
        }
      | undefined;
    if (!row) {
      return {
        intents: [],
        focus: [],
        tone: 'balanced',
        configured: false,
        updatedAt: null,
      };
    }
    return {
      intents: JSON.parse(row.intents),
      focus: JSON.parse(row.focus),
      tone: row.tone,
      configured: row.configured === 1,
      updatedAt: row.updatedAt,
    };
  });

  app.put('/api/v1/insights/profile', async request => {
    const user = authenticate(request.headers.authorization);
    const profile = profileSchema.parse(request.body);
    const now = store.now();
    store.db.prepare(`
      INSERT INTO insight_profiles(
        user_id,intents_json,focus_json,tone,configured,updated_at
      ) VALUES(?,?,?,?,?,?)
      ON CONFLICT(user_id) DO UPDATE SET
        intents_json=excluded.intents_json,
        focus_json=excluded.focus_json,
        tone=excluded.tone,
        configured=excluded.configured,
        updated_at=excluded.updated_at
    `).run(
      user.id,
      JSON.stringify([...new Set(profile.intents)]),
      JSON.stringify([...new Set(profile.focus)]),
      profile.tone,
      profile.configured ? 1 : 0,
      now,
    );
    return { ...profile, updatedAt: now };
  });

  app.post('/api/v1/insights/:insightId/feedback', async (request, reply) => {
    const user = authenticate(request.headers.authorization);
    const { insightId } = z
      .object({ insightId: z.string().trim().min(1).max(180) })
      .parse(request.params);
    const feedback = feedbackSchema.parse(request.body);
    const id = randomUUID();
    const createdAt = store.now();
    store.db.prepare(
      'INSERT INTO insight_feedback('
        + 'id,user_id,insight_id,action,kind,metadata_json,created_at'
        + ') VALUES(?,?,?,?,?,?,?)',
    ).run(
      id,
      user.id,
      insightId,
      feedback.action,
      feedback.kind ?? null,
      JSON.stringify(feedback.metadata ?? {}),
      createdAt,
    );
    return reply.code(201).send({
      id,
      insightId,
      ...feedback,
      createdAt,
    });
  });

  app.get('/api/v1/insights/policy', async request => {
    const user = authenticate(request.headers.authorization);
    const policy = readInsightPolicy(store);
    const paidMember = hasActivePaidInsightMembership(store, user.id);
    const aiAccess = hasInsightAiAccess(store, user.id);
    const aiQuota = aiAccess ? readSharedAiQuota(store, user.id) : null;
    return {
      homeMinScore: policy.homeMinScore,
      minConfidence: policy.minConfidence,
      cooldownDays: policy.cooldownDays,
      aiEnabled: policy.aiEnabled,
      aiAvailable: policy.aiEnabled && aiAccess,
      aiRemaining: aiQuota?.remaining ?? null,
      historyDays: paidMember ? policy.proHistoryDays : policy.freeHistoryDays,
      promptVersion: policy.promptVersion,
    };
  });

  app.post(
    '/api/v1/insights/interpret',
    { config: { rateLimit: { max: 20, timeWindow: '1 minute' } } },
    async request => {
      const user = authenticate(request.headers.authorization);
      const policy = readInsightPolicy(store);
      check(policy.aiEnabled, 'AI 深度解读暂未开启', 503);
      check(
        hasInsightAiAccess(store, user.id),
        'AI 深度解读需要有效会员或 AI 权限',
        403,
      );
      const body = interpretationSchema.parse(request.body);
      const bodyHash = interpretationBodyHash(body);
      const confirmed = store.db.prepare(
        'SELECT confirmed_at AS confirmedAt FROM insight_confirmed_items '
          + 'WHERE user_id=? AND insight_id=? AND body_hash=?',
      ).get(user.id, body.insightId, bodyHash) as
        | { confirmedAt: number }
        | undefined;
      check(
        confirmed && confirmed.confirmedAt >= store.now() - 2 * 86400,
        '请先刷新这条洞察后再进行 AI 解读',
        409,
      );
      const explainableText = [
        body.title,
        body.summary,
        body.analysis,
        body.meaning,
        body.suggestion ?? '',
      ].join('\n');
      check(
        !outOfScope(explainableText),
        '这条内容不适合进行 AI 财务解读',
        400,
      );
      const cached = store.db.prepare(
        'SELECT result_text FROM insight_ai_cache '
          + 'WHERE user_id=? AND insight_id=? AND prompt_version=? '
          + 'AND body_hash=?',
      ).get(
        user.id,
        body.insightId,
        policy.promptVersion,
        bodyHash,
      ) as { result_text: string } | undefined;
      if (cached) {
        return {
          message: cached.result_text,
          source: 'cache',
          promptVersion: policy.promptVersion,
        };
      }

      consumeSharedAiQuota(store, user.id);

      const systemPrompt = [
        '你是“好好记账”的财务洞察解释器。',
        '只能解释服务端已经计算并提供的事实，不得新增金额、次数、日期或因果结论。',
        '不得根据消费推断性别、外貌、疾病、职业、阶层或其他敏感身份。',
        '不得制造焦虑、羞辱用户或把正常生活消费道德化。',
        '如果证据不足，明确说证据有限；如果是积极变化，可以自然肯定，但不要夸张。',
        '建议必须可选、可执行，并与用户现有目标一致；不要替用户做财务决定。',
        '输出 2-4 段简短中文纯文本，不要 Markdown 标题，不要 JSON。',
        `策略版本：${policy.promptVersion}`,
      ].join('\n');
      const userText = JSON.stringify({
        kind: body.kind,
        title: body.title,
        summary: body.summary,
        analysis: body.analysis,
        meaning: body.meaning,
        suggestion: body.suggestion ?? null,
        evidence: body.evidence,
      });
      let message: string;
      try {
        message = await modelProvider.complete({ systemPrompt, userText });
      } catch (error) {
        if (error instanceof AssistantModelUnavailable) {
          throw new ApiError(503, '模型服务暂时不可用，请稍后重试');
        }
        throw error;
      }
      message = message.trim().slice(0, 1600);
      check(message.length > 0, '模型没有返回有效解读', 502);
      store.db.prepare(
        'INSERT INTO insight_ai_cache('
          + 'user_id,insight_id,prompt_version,body_hash,result_text,created_at'
          + ') VALUES(?,?,?,?,?,?) '
          + 'ON CONFLICT(user_id,insight_id,prompt_version,body_hash) '
          + 'DO UPDATE SET result_text=excluded.result_text,'
          + 'created_at=excluded.created_at',
      ).run(
        user.id,
        body.insightId,
        policy.promptVersion,
        bodyHash,
        message,
        store.now(),
      );
      return {
        message,
        source: 'model',
        promptVersion: policy.promptVersion,
      };
    },
  );

  app.get('/api/v1/insights/feedback/summary', async request => {
    const user = authenticate(request.headers.authorization);
    const rows = store.db.prepare(
      'SELECT action,COUNT(*) AS count FROM insight_feedback '
        + 'WHERE user_id=? GROUP BY action ORDER BY count DESC',
    ).all(user.id);
    return { feedback: rows };
  });
}
