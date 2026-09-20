import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Store } from './store.js';

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
});
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
    CREATE TABLE IF NOT EXISTS insight_policy(
      id INTEGER PRIMARY KEY CHECK(id=1),
      policy_json TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    );
  `);
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

export function registerInsightRoutes(
  app: FastifyInstance,
  store: Store,
  authenticate: Authenticate,
) {
  ensureInsightSchema(store);

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
    authenticate(request.headers.authorization);
    const policy = readInsightPolicy(store);
    return {
      homeMinScore: policy.homeMinScore,
      minConfidence: policy.minConfidence,
      cooldownDays: policy.cooldownDays,
      aiEnabled: policy.aiEnabled,
      historyDays: policy.freeHistoryDays,
      promptVersion: policy.promptVersion,
    };
  });

  app.get('/api/v1/insights/feedback/summary', async request => {
    const user = authenticate(request.headers.authorization);
    const rows = store.db.prepare(
      'SELECT action,COUNT(*) AS count FROM insight_feedback '
        + 'WHERE user_id=? GROUP BY action ORDER BY count DESC',
    ).all(user.id);
    return { feedback: rows };
  });
}
