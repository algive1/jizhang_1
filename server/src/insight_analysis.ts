import { z } from 'zod';
import type { InsightPolicy } from './insights.js';

const nullableText = z.string().trim().max(300).nullable().optional();
const transactionType = z.enum([
  'expense',
  'income',
  'transfer',
  'refund',
  'reimbursement',
  'borrow',
  'lend',
  'repayment',
  'assetPurchase',
  'assetSale',
  'adjustment',
]);
const transactionSource = z.enum(['manual', 'voice', 'ocr', 'auto', 'import']);

const transactionSchema = z.strictObject({
  id: z.string().min(1).max(600),
  type: transactionType,
  amount: z.number().finite().nonnegative(),
  currency: z.string().regex(/^[A-Z]{3}$/),
  categoryId: nullableText,
  categoryName: nullableText,
  merchant: nullableText,
  note: z.string().max(2000).nullable().optional(),
  occurredAt: z.number().int().nonnegative(),
  source: transactionSource,
  aiConfidence: z.number().min(0).max(1).nullable().optional(),
  userCorrected: z.boolean().default(false),
  duplicateConfidence: z.number().min(0).max(1).nullable().optional(),
  reimbursementStatus: z
    .enum(['none', 'pending', 'reimbursed', 'partial'])
    .default('none'),
  reimbursementAmount: z.number().finite().nonnegative().nullable().optional(),
  refundAmount: z.number().finite().nonnegative().nullable().optional(),
  isRecurring: z.boolean().default(false),
});

const accountSchema = z.strictObject({
  id: z.string().min(1).max(600),
  name: z.string().trim().min(1).max(120),
  type: z.enum([
    'cash',
    'wechat',
    'alipay',
    'debitCard',
    'creditCard',
    'other',
    'liability',
  ]),
  balance: z.number().finite(),
  currency: z.string().regex(/^[A-Z]{3}$/),
  assetForm: z
    .enum([
      'unspecified',
      'cash',
      'walletBalance',
      'demandDeposit',
      'termDeposit',
      'investment',
      'other',
    ])
    .default('unspecified'),
  isArchived: z.boolean().default(false),
});

const budgetSchema = z.strictObject({
  id: z.string().min(1).max(600),
  monthKey: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/),
  categoryId: nullableText,
  amount: z.number().finite().positive(),
});

const goalSchema = z.strictObject({
  id: z.string().min(1).max(600),
  name: z.string().trim().min(1).max(120),
  targetAmount: z.number().finite().positive(),
  currentAmount: z.number().finite().nonnegative(),
  createdAt: z.number().int().nonnegative(),
  targetDate: z.number().int().nonnegative(),
  status: z.enum(['active', 'completed', 'paused', 'archived']),
  monthlyReservation: z.number().finite().nonnegative().default(0),
});

const recurringSchema = z.strictObject({
  id: z.string().min(1).max(600),
  name: z.string().trim().min(1).max(160),
  type: z.enum([
    'membership',
    'mortgage',
    'rent',
    'carLoan',
    'insurance',
    'subscription',
    'mobilePlan',
    'income',
    'other',
  ]),
  amount: z.number().finite().positive(),
  cycle: z.enum([
    'daily',
    'weekly',
    'monthly',
    'quarterly',
    'halfYear',
    'yearly',
    'custom',
  ]),
  nextDate: z.number().int().nonnegative(),
  status: z.enum(['active', 'paused', 'ended']),
});

export const insightContextSchema = z.strictObject({
  bookId: z.string().trim().min(1).max(600),
  currency: z.string().regex(/^[A-Z]{3}$/).default('CNY'),
  generatedAt: z.number().int().nonnegative(),
  timezoneOffsetMinutes: z.number().int().min(-720).max(840).default(0),
  transactions: z.array(transactionSchema).max(12000),
  accounts: z.array(accountSchema).max(500),
  budgets: z.array(budgetSchema).max(1000),
  goals: z.array(goalSchema).max(300),
  recurringBills: z.array(recurringSchema).max(1000),
});
export type InsightAnalysisContext = z.infer<typeof insightContextSchema>;

export type InsightProfile = {
  intents: string[];
  focus: string[];
  tone: 'strict' | 'balanced' | 'quiet';
};

export type InsightFeedbackProfile = {
  dismissedIds: Set<string>;
  kindAdjustments: Record<string, number>;
};

type Confidence = {
  data: number;
  completeness: number;
  classification: number;
  baseline: number;
};

type Evidence = {
  label: string;
  value: number;
  baselineValue?: number;
  unit?: string;
  note?: string;
  transactionIds?: string[];
};

type InsightItem = {
  id: string;
  kind:
    | 'financial'
    | 'behavior'
    | 'risk'
    | 'goal'
    | 'discovery'
    | 'positive'
    | 'life';
  priority: 'info' | 'attention' | 'important' | 'critical';
  title: string;
  summary: string;
  analysis: string;
  meaning: string;
  response: 'notice' | 'advice' | 'encouragement' | 'record';
  score: number;
  confidence: Confidence;
  generatedAt: number;
  suggestion?: string;
  actionLabel?: string;
  actionRoute?: string;
  categoryId?: string;
  amount?: number;
  changePercent?: number;
  evidence: Evidence[];
  relatedTransactionIds: string[];
};

type Tx = z.infer<typeof transactionSchema>;

function clamp(value: number, min = 0, max = 1) {
  return Math.max(min, Math.min(max, value));
}

function median(values: number[]) {
  if (!values.length) return 0;
  const ordered = [...values].sort((a, b) => a - b);
  const middle = Math.floor(ordered.length / 2);
  return ordered.length % 2
    ? ordered[middle]!
    : (ordered[middle - 1]! + ordered[middle]!) / 2;
}

function percentile(values: number[], ratio: number) {
  if (!values.length) return 0;
  const ordered = [...values].sort((a, b) => a - b);
  return ordered[Math.round((ordered.length - 1) * ratio)]!;
}

function netExpense(tx: Tx) {
  if (tx.type !== 'expense' && tx.type !== 'lend') return 0;
  const afterRefund = Math.max(0, tx.amount - (tx.refundAmount ?? 0));
  const reimbursable =
    tx.reimbursementStatus === 'none'
      ? 0
      : tx.reimbursementAmount ??
        (tx.reimbursementStatus === 'pending' ||
        tx.reimbursementStatus === 'reimbursed'
          ? afterRefund
          : 0);
  return Math.max(0, afterRefund - reimbursable);
}

function localDateParts(timestamp: number, timezoneOffsetMinutes: number) {
  const date = new Date(timestamp + timezoneOffsetMinutes * 60_000);
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth(),
    day: date.getUTCDate(),
    hour: date.getUTCHours(),
  };
}

function localBoundary(
  year: number,
  month: number,
  day: number,
  timezoneOffsetMinutes: number,
) {
  return (
    Date.UTC(year, month, day) - timezoneOffsetMinutes * 60_000
  );
}

function comparisonRange(
  nowTimestamp: number,
  timezoneOffsetMinutes: number,
) {
  const now = localDateParts(nowTimestamp, timezoneOffsetMinutes);
  const currentStart = localBoundary(
    now.year,
    now.month,
    1,
    timezoneOffsetMinutes,
  );
  const currentEnd = nowTimestamp + 1;
  const previousStart = localBoundary(
    now.year,
    now.month - 1,
    1,
    timezoneOffsetMinutes,
  );
  const previousMonthLast = new Date(
    Date.UTC(now.year, now.month, 0),
  ).getUTCDate();
  const comparableDay = Math.min(now.day, previousMonthLast);
  const previousEnd =
    localBoundary(
      now.year,
      now.month - 1,
      comparableDay + 1,
      timezoneOffsetMinutes,
    ) - 1;
  return { currentStart, currentEnd, previousStart, previousEnd };
}

function quality(
  transactions: Tx[],
  now: Date,
  timezoneOffsetMinutes: number,
): Confidence {
  const recentStart = now.getTime() - 90 * 86400000;
  const recent = transactions.filter(
    tx => tx.occurredAt >= recentStart && netExpense(tx) > 0,
  );
  if (!recent.length) {
    return {
      data: 0.2,
      completeness: 0.1,
      classification: 0.2,
      baseline: 0.1,
    };
  }
  const monthCounts = new Map<string, number>();
  for (const tx of recent) {
    const date = localDateParts(tx.occurredAt, timezoneOffsetMinutes);
    const key = `${date.year}-${date.month}`;
    monthCounts.set(key, (monthCounts.get(key) ?? 0) + 1);
  }
  const coveredMonths = [...monthCounts.values()].filter(count => count >= 4)
    .length;
  const completeness = clamp(
    0.55 * Math.min(1, recent.length / 45) +
      0.45 * Math.min(1, coveredMonths / 3),
  );
  let classificationTotal = 0;
  let dataTotal = 0;
  for (const tx of recent) {
    classificationTotal += tx.userCorrected
      ? 1
      : tx.aiConfidence ??
        (tx.categoryName?.trim() || tx.categoryId?.trim() ? 0.9 : 0.5);
    dataTotal += clamp(1 - (tx.duplicateConfidence ?? 0) * 0.65, 0.2, 1);
  }
  const classification = clamp(classificationTotal / recent.length);
  const data = clamp(dataTotal / recent.length);
  const baseline = clamp(
    0.45 * Math.min(1, recent.length / 40) +
      0.55 * Math.min(1, coveredMonths / 3),
  );
  return { data, completeness, classification, baseline };
}

function overallConfidence(value: Confidence) {
  return clamp(
    value.data * 0.3 +
      value.completeness * 0.25 +
      value.classification * 0.2 +
      value.baseline * 0.25,
  );
}

function intentBoost(kind: InsightItem['kind'], profile: InsightProfile) {
  let boost = 0;
  for (const intent of profile.intents) {
    const value =
      intent === 'controlSpending'
        ? ['behavior', 'risk'].includes(kind)
          ? 12
          : 0
        : intent === 'understandSpending'
          ? ['behavior', 'discovery'].includes(kind)
            ? 8
            : 0
          : intent === 'saveForGoal'
            ? ['risk', 'positive', 'goal'].includes(kind)
              ? 12
              : 0
            : intent === 'optimizeFinances'
              ? ['financial', 'risk', 'discovery'].includes(kind)
                ? 12
                : 0
              : intent === 'familyFinances'
                ? ['life', 'financial'].includes(kind)
                  ? 12
                  : 0
                : intent === 'improveHabits'
                  ? ['behavior', 'life'].includes(kind)
                    ? 10
                    : 0
                  : intent === 'recordLife'
                    ? ['life', 'positive'].includes(kind)
                      ? 12
                      : 0
                    : 0;
    boost = Math.max(boost, value);
  }
  return boost;
}

function focusBoost(text: string, profile: InsightProfile) {
  const rules: Record<string, RegExp> = {
    dining: /餐饮|外卖|吃|夜/,
    shopping: /购物|淘宝|拼多多|京东|美妆/,
    travel: /旅行|出行|交通|住宿/,
    healthHabits: /健康|健身|餐饮|夜|美妆/,
    savings: /预算|储蓄|支出下降|目标/,
    credit: /信用|月付|负债|还款/,
    family: /家庭|家人|父母|爸|妈/,
    learning: /学习|教育|课程|书/,
  };
  return profile.focus.some(value => rules[value]?.test(text)) ? 10 : 0;
}

function item(
  input: Omit<InsightItem, 'score' | 'confidence' | 'generatedAt'> & {
    baseScore: number;
    confidence: Confidence;
    profile: InsightProfile;
    feedback: InsightFeedbackProfile;
    generatedAt: number;
  },
): InsightItem {
  let score =
    input.baseScore +
    intentBoost(input.kind, input.profile) +
    focusBoost(`${input.title} ${input.summary}`, input.profile) +
    (input.feedback.kindAdjustments[input.kind] ?? 0) +
    (overallConfidence(input.confidence) - 0.5) * 16;
  if (input.profile.tone === 'quiet') score -= 7;
  if (
    input.profile.tone === 'strict' &&
    (input.kind === 'risk' || input.kind === 'behavior')
  ) {
    score += 4;
  }
  const {
    baseScore: _baseScore,
    profile: _profile,
    feedback: _feedback,
    ...rest
  } = input;
  return {
    ...rest,
    score: clamp(score, 0, 100),
    evidence: input.evidence ?? [],
    relatedTransactionIds: input.relatedTransactionIds ?? [],
  };
}

function friendlyBudget(value: number) {
  const step = value >= 1000 ? 50 : 10;
  return Math.max(step, Math.round(value / step) * step);
}

function budgetRecommendation(
  expenses: Tx[],
  now: Date,
  timezoneOffsetMinutes: number,
  profile: InsightProfile,
) {
  const totals: number[] = [];
  for (let offset = 1; offset <= 3; offset++) {
    const localNow = localDateParts(now.getTime(), timezoneOffsetMinutes);
    const target = new Date(
      Date.UTC(localNow.year, localNow.month - offset, 1),
    );
    const year = target.getUTCFullYear();
    const month = target.getUTCMonth();
    const rows = expenses.filter(tx => {
      const date = localDateParts(tx.occurredAt, timezoneOffsetMinutes);
      return (
        date.year === year &&
        date.month === month &&
        netExpense(tx) > 0
      );
    });
    if (rows.length >= 4) {
      totals.push(rows.reduce((sum, tx) => sum + netExpense(tx), 0));
    }
  }
  if (totals.length < 2) return null;
  const base = median(totals);
  const maintain = friendlyBudget(Math.max(base, percentile(totals, 0.75)));
  const moderate = friendlyBudget(base * 0.9);
  const active = friendlyBudget(base * 0.8);
  const recommended = profile.intents.includes('saveForGoal')
    ? active
    : profile.intents.includes('controlSpending')
      ? moderate
      : maintain;
  const spread = Math.max(...totals) - Math.min(...totals);
  const stability = base <= 0 ? 0 : 1 - clamp(spread / base);
  return {
    recommended,
    maintain,
    moderate,
    active,
    median: base,
    confidence: clamp(0.55 + 0.15 * (totals.length / 3) + 0.3 * stability),
  };
}

function categoryChanges(
  expenses: Tx[],
  now: Date,
  timezoneOffsetMinutes: number,
  confidence: Confidence,
  profile: InsightProfile,
  feedback: InsightFeedbackProfile,
) {
  const range = comparisonRange(now.getTime(), timezoneOffsetMinutes);
  type Bucket = {
    id?: string;
    name: string;
    currentAmount: number;
    previousAmount: number;
    currentCount: number;
    previousCount: number;
    currentIds: string[];
    familyAmount: number;
  };
  const buckets = new Map<string, Bucket>();
  const familyPattern = /爸爸|妈妈|父母|爸妈|家人|家里/;
  for (const tx of expenses) {
    const value = netExpense(tx);
    if (value <= 0) continue;
    const name = tx.categoryName?.trim() || '未分类';
    const key = tx.categoryId?.trim() || `name:${name}`;
    const bucket =
      buckets.get(key) ??
      {
        id: tx.categoryId ?? undefined,
        name,
        currentAmount: 0,
        previousAmount: 0,
        currentCount: 0,
        previousCount: 0,
        currentIds: [],
        familyAmount: 0,
      };
    if (
      tx.occurredAt >= range.currentStart &&
      tx.occurredAt <= range.currentEnd
    ) {
      bucket.currentAmount += value;
      bucket.currentCount++;
      bucket.currentIds.push(tx.id);
      if (familyPattern.test(`${tx.note ?? ''} ${tx.merchant ?? ''}`)) {
        bucket.familyAmount += value;
      }
    } else if (
      tx.occurredAt >= range.previousStart &&
      tx.occurredAt <= range.previousEnd
    ) {
      bucket.previousAmount += value;
      bucket.previousCount++;
    }
    buckets.set(key, bucket);
  }

  const results: InsightItem[] = [];
  for (const bucket of buckets.values()) {
    if (bucket.previousAmount < 100) continue;
    const delta = bucket.currentAmount - bucket.previousAmount;
    const percent = delta / bucket.previousAmount;
    if (
      bucket.name.includes('社交') &&
      bucket.currentAmount > 0 &&
      bucket.familyAmount / bucket.currentAmount >= 0.5
    ) {
      continue;
    }
    if (delta >= 100 && percent >= 0.3) {
      const previousTicket =
        bucket.previousCount <= 0
          ? 0
          : bucket.previousAmount / bucket.previousCount;
      const currentTicket =
        bucket.currentCount <= 0
          ? 0
          : bucket.currentAmount / bucket.currentCount;
      const countGrowth =
        bucket.previousCount <= 0
          ? 0
          : bucket.currentCount / bucket.previousCount - 1;
      const ticketGrowth =
        previousTicket <= 0 ? 0 : currentTicket / previousTicket - 1;
      const reason =
        countGrowth > ticketGrowth + 0.15
          ? '增长主要由消费次数增加带来，单次金额不是主要原因。'
          : ticketGrowth > countGrowth + 0.15
            ? '增长主要由单次消费金额变高带来。'
            : '消费次数和单次金额都在推动本期增长。';
      results.push(
        item({
          id: `server:category:${bucket.id ?? bucket.name}:increase`,
          kind: 'behavior',
          priority: percent >= 0.7 ? 'important' : 'attention',
          title: `${bucket.name}支出明显增加`,
          summary: `本期比上一可比周期多 ¥${delta.toFixed(0)}。`,
          analysis: reason,
          meaning: '这是一项相对你自己的可比历史变化，不是拿你和其他用户比较。',
          response: 'notice',
          suggestion: profile.intents.includes('controlSpending')
            ? '先确认变化来自次数还是单次金额，再决定是否调整这个分类的预算。'
            : undefined,
          actionLabel: '查看趋势',
          actionRoute: '/analysis',
          categoryId: bucket.id,
          amount: bucket.currentAmount,
          changePercent: percent * 100,
          evidence: [
            {
              label: bucket.name,
              value: bucket.currentAmount,
              baselineValue: bucket.previousAmount,
              unit: 'CNY',
              transactionIds: bucket.currentIds,
            },
            {
              label: '消费次数',
              value: bucket.currentCount,
              baselineValue: bucket.previousCount,
              unit: '次',
            },
          ],
          relatedTransactionIds: bucket.currentIds,
          baseScore: percent >= 0.7 ? 77 : 66,
          confidence,
          profile,
          feedback,
          generatedAt: now.getTime(),
        }),
      );
    } else if (
      bucket.currentAmount <= bucket.previousAmount * 0.75 &&
      bucket.previousAmount - bucket.currentAmount >= 100
    ) {
      const drop = bucket.previousAmount - bucket.currentAmount;
      results.push(
        item({
          id: `server:category:${bucket.id ?? bucket.name}:positive`,
          kind: 'positive',
          priority: 'info',
          title: `${bucket.name}支出有所下降`,
          summary: `和上一可比周期相比少了约 ¥${drop.toFixed(0)}。`,
          analysis:
            bucket.currentCount < bucket.previousCount
              ? '变化主要伴随着消费次数减少。'
              : '消费次数变化不大，单次金额下降更明显。',
          meaning: '这是相对你自己历史习惯出现的积极变化。',
          response: 'encouragement',
          suggestion:
            profile.intents.includes('controlSpending') ||
            profile.intents.includes('saveForGoal')
              ? '这个变化和你当前的记账目标方向一致。'
              : undefined,
          actionLabel: '查看趋势',
          actionRoute: '/analysis',
          categoryId: bucket.id,
          amount: bucket.currentAmount,
          changePercent: -(drop / bucket.previousAmount) * 100,
          evidence: [
            {
              label: bucket.name,
              value: bucket.currentAmount,
              baselineValue: bucket.previousAmount,
              unit: 'CNY',
            },
          ],
          relatedTransactionIds: bucket.currentIds,
          baseScore: 50,
          confidence,
          profile,
          feedback,
          generatedAt: now.getTime(),
        }),
      );
    }
  }
  return results.sort((a, b) => b.score - a.score).slice(0, 4);
}

function behaviorPatternInsight(
  expenses: Tx[],
  now: Date,
  timezoneOffsetMinutes: number,
  confidence: Confidence,
  profile: InsightProfile,
  feedback: InsightFeedbackProfile,
  kind: 'delivery' | 'lateNight',
) {
  const range = comparisonRange(now.getTime(), timezoneOffsetMinutes);
  const isMatch = (tx: Tx) => {
    if (kind === 'lateNight') {
      const hour = localDateParts(tx.occurredAt, timezoneOffsetMinutes).hour;
      return hour >= 22 || hour < 6;
    }
    return /美团|饿了么|外卖|delivery/i.test(
      `${tx.merchant ?? ''} ${tx.note ?? ''} ${tx.categoryName ?? ''}`,
    );
  };
  const current = expenses.filter(
    tx =>
      tx.occurredAt >= range.currentStart &&
      tx.occurredAt <= range.currentEnd &&
      netExpense(tx) > 0 &&
      isMatch(tx),
  );
  const previous = expenses.filter(
    tx =>
      tx.occurredAt >= range.previousStart &&
      tx.occurredAt <= range.previousEnd &&
      netExpense(tx) > 0 &&
      isMatch(tx),
  );
  if (
    current.length < Math.max(4, previous.length + 3) ||
    (previous.length > 0 && current.length < previous.length * 1.5)
  ) {
    return null;
  }
  const currentAmount = current.reduce((sum, tx) => sum + netExpense(tx), 0);
  const previousAmount = previous.reduce((sum, tx) => sum + netExpense(tx), 0);
  const isDelivery = kind === 'delivery';
  return item({
    id: `server:behavior:${kind}`,
    kind: 'behavior',
    priority: current.length >= previous.length + 6 ? 'important' : 'attention',
    title: isDelivery ? '最近外卖次数明显增加' : '最近深夜消费变多了',
    summary: `本期 ${current.length} 次，上一可比周期 ${previous.length} 次。`,
    analysis: isDelivery
      ? '变化主要来自外卖频率；系统同时保留金额证据，避免把“次数多”和“单次变贵”混在一起。'
      : '增加主要集中在 22:00 以后到清晨的消费次数。',
    meaning: profile.intents.includes('improveHabits')
      ? '这与你当前关注的生活习惯直接相关，因此会提高展示优先级。'
      : '这是消费时间或方式发生的变化，是否需要调整取决于你的记账目标。',
    response: 'notice',
    suggestion: profile.intents.includes('controlSpending')
      ? isDelivery
        ? '如果希望控制消费，可以先尝试恢复到过去的外卖频率。'
        : '可以先查看这些消费发生在哪几天，再决定是否需要调整。'
      : undefined,
    actionLabel: '查看相关流水',
    actionRoute: '/transactions',
    amount: currentAmount,
    changePercent:
      previousAmount > 0
        ? ((currentAmount - previousAmount) / previousAmount) * 100
        : undefined,
    evidence: [
      {
        label: isDelivery ? '外卖次数' : '深夜消费次数',
        value: current.length,
        baselineValue: previous.length,
        unit: '次',
        transactionIds: current.map(tx => tx.id),
      },
      {
        label: '涉及金额',
        value: currentAmount,
        baselineValue: previousAmount,
        unit: 'CNY',
      },
    ],
    relatedTransactionIds: current.map(tx => tx.id),
    baseScore: current.length >= previous.length + 6 ? 78 : 67,
    confidence,
    profile,
    feedback,
    generatedAt: now.getTime(),
  });
}

export function analyzeInsightContext(
  input: InsightAnalysisContext,
  profile: InsightProfile,
  feedback: InsightFeedbackProfile,
  policy: InsightPolicy,
  historyDays: number,
) {
  const now = new Date(input.generatedAt);
  const timezoneOffsetMinutes = input.timezoneOffsetMinutes;
  const historyStart = input.generatedAt - historyDays * 86400000;
  const currency = input.currency.toUpperCase();
  const transactions = input.transactions.filter(
    tx =>
      tx.currency.toUpperCase() === currency &&
      tx.occurredAt <= now.getTime() &&
      tx.occurredAt >= historyStart,
  );
  const expenses = transactions.filter(tx => netExpense(tx) > 0);
  const confidence = quality(transactions, now, timezoneOffsetMinutes);
  const results: InsightItem[] = [];

  if (confidence.baseline >= 0.35) {
    results.push(
      ...categoryChanges(
        expenses,
        now,
        timezoneOffsetMinutes,
        confidence,
        profile,
        feedback,
      ),
    );
    for (const pattern of ['delivery', 'lateNight'] as const) {
      const insight = behaviorPatternInsight(
        expenses,
        now,
        timezoneOffsetMinutes,
        confidence,
        profile,
        feedback,
        pattern,
      );
      if (insight) results.push(insight);
    }
  }

  const localNow = localDateParts(input.generatedAt, timezoneOffsetMinutes);
  const currentMonthKey =
    `${localNow.year}-${String(localNow.month + 1).padStart(2, '0')}`;
  const totalBudget = input.budgets.find(
    budget => budget.monthKey === currentMonthKey && !budget.categoryId,
  );
  const currentMonthStart = localBoundary(
    localNow.year,
    localNow.month,
    1,
    timezoneOffsetMinutes,
  );
  const currentSpend = expenses
    .filter(tx => tx.occurredAt >= currentMonthStart)
    .reduce((sum, tx) => sum + netExpense(tx), 0);
  if (totalBudget) {
    const days = new Date(
      Date.UTC(localNow.year, localNow.month + 1, 0),
    ).getUTCDate();
    const timeProgress = clamp(localNow.day / days, 0.03, 1);
    const usage = currentSpend / totalBudget.amount;
    const forecast = currentSpend / timeProgress;
    const overspend = forecast - totalBudget.amount;
    if (
      usage - timeProgress >= 0.12 ||
      overspend > totalBudget.amount * 0.05
    ) {
      const important =
        usage > 1 || overspend > totalBudget.amount * 0.25;
      results.push(
        item({
          id: `server:budget:${currentMonthKey}:total`,
          kind: 'risk',
          priority: important ? 'important' : 'attention',
          title: usage > 1 ? '本月预算已经超出' : '本月预算消耗有点快',
          summary:
            usage > 1
              ? `本月支出已经超过预算 ¥${totalBudget.amount.toFixed(0)}。`
              : `本月过去 ${Math.round(timeProgress * 100)}%，预算已使用 ${Math.round(usage * 100)}%。`,
          analysis:
            `按目前消费速度，月底预计约 ¥${forecast.toFixed(0)}` +
            (overspend > 0
              ? `，比预算高约 ¥${overspend.toFixed(0)}。`
              : '。'),
          meaning: '预算控制看的是消费速度和时间进度，而不是等月底超支后才提醒。',
          response: 'advice',
          suggestion: '打开预算查看剩余额度和日均可用金额，再决定接下来的消费节奏。',
          actionLabel: '查看预算',
          actionRoute: '/profile/budgets',
          amount: currentSpend,
          changePercent: (usage - timeProgress) * 100,
          evidence: [
            { label: '预算已使用', value: usage * 100, unit: '%' },
            { label: '月份已过去', value: timeProgress * 100, unit: '%' },
            {
              label: '月底预测',
              value: forecast,
              baselineValue: totalBudget.amount,
              unit: currency,
            },
          ],
          relatedTransactionIds: [],
          baseScore: important ? 86 : 74,
          confidence: { ...confidence, baseline: Math.max(0.65, confidence.baseline) },
          profile,
          feedback,
          generatedAt: now.getTime(),
        }),
      );
    }
  } else if (
    profile.intents.includes('controlSpending') ||
    profile.intents.includes('saveForGoal')
  ) {
    const recommendation = budgetRecommendation(
      expenses,
      now,
      timezoneOffsetMinutes,
      profile,
    );
    if (recommendation) {
      results.push(
        item({
          id: 'server:budget:recommendation',
          kind: 'goal',
          priority: 'attention',
          title: '可以用你的真实消费来设预算了',
          summary: `根据最近完整月份，当前建议总预算约 ¥${recommendation.recommended.toFixed(0)}。`,
          analysis: '不是把历史平均直接当预算，而是结合稳定消费区间和你的记账目标给出档位。',
          meaning: '从可持续的预算开始，比随手填一个过紧或过松的数字更容易长期执行。',
          response: 'advice',
          suggestion: '可以在“保持、适度控制、积极节省”三个档位之间选择。',
          actionLabel: '设置预算',
          actionRoute: '/profile/budgets',
          amount: recommendation.recommended,
          evidence: [
            {
              label: '历史月中位数',
              value: recommendation.median,
              unit: currency,
            },
            {
              label: '建议预算',
              value: recommendation.recommended,
              unit: currency,
            },
          ],
          relatedTransactionIds: [],
          baseScore: 70,
          confidence: {
            ...confidence,
            baseline: Math.max(recommendation.confidence, confidence.baseline),
          },
          profile,
          feedback,
          generatedAt: now.getTime(),
        }),
      );
    }
  }

  const creditAccounts = input.accounts.filter(
    account =>
      !account.isArchived &&
      (account.type === 'creditCard' ||
        account.type === 'liability' ||
        /花呗|月付|白条|信用|分期|先用后付/.test(account.name)),
  );
  if (creditAccounts.length >= 2) {
    results.push(
      item({
        id: 'server:accounts:multiple-credit',
        kind: 'financial',
        priority: 'attention',
        title: '你在使用多个信用 / 后付账户',
        summary:
          `已识别 ${creditAccounts.length} 个信用或负债账户：` +
          creditAccounts
            .slice(0, 3)
            .map(account => account.name)
            .join('、') +
          '。',
        analysis: '消费分散在多个待还账户后，只看银行卡余额容易高估真正可用的钱。',
        meaning: '把待还金额和还款日期集中看，比单独看每张卡更接近真实财务状态。',
        response: 'advice',
        suggestion: '建议确认待还金额和还款日，并避免把消费与还款重复统计成两次支出。',
        actionLabel: '管理账户',
        actionRoute: '/profile/accounts',
        evidence: [
          {
            label: '信用 / 负债账户',
            value: creditAccounts.length,
            unit: '个',
          },
        ],
        relatedTransactionIds: [],
        baseScore: 68,
        confidence: { ...confidence, baseline: 1 },
        profile,
        feedback,
        generatedAt: now.getTime(),
      }),
    );
  }

  const ninetyDaysAgo = now.getTime() - 90 * 86400000;
  const familyPattern = /爸爸|妈妈|父母|爸妈|家人|家里/;
  const familyRows = transactions.filter(
    tx =>
      tx.occurredAt >= ninetyDaysAgo &&
      familyPattern.test(
        `${tx.note ?? ''} ${tx.merchant ?? ''} ${tx.categoryName ?? ''}`,
      ) &&
      ['expense', 'lend'].includes(tx.type),
  );
  const familyAmount = familyRows.reduce((sum, tx) => sum + tx.amount, 0);
  if (familyRows.length >= 2 && familyAmount >= 100) {
    results.push(
      item({
        id: 'server:life:family-support',
        kind: 'life',
        priority: 'info',
        title: '家人是你近期支出里很特别的一部分',
        summary: `近 90 天记录到 ${familyRows.length} 笔与父母或家人相关的资金往来。`,
        analysis: '这些记录更像家庭支持，不适合简单理解成“社交消费变多”。',
        meaning: '钱也在记录生活关系。对这类支出，理解用途比单纯压低金额更重要。',
        response: 'encouragement',
        suggestion: '如果这是稳定支持，可以单独设置家庭预算，让其他消费分析更准确。',
        actionLabel: '查看流水',
        actionRoute: '/transactions',
        amount: familyAmount,
        evidence: [
          {
            label: '家庭相关记录',
            value: familyRows.length,
            unit: '笔',
            transactionIds: familyRows.map(tx => tx.id),
          },
          { label: '涉及金额', value: familyAmount, unit: currency },
        ],
        relatedTransactionIds: familyRows.map(tx => tx.id),
        baseScore: 55,
        confidence,
        profile,
        feedback,
        generatedAt: now.getTime(),
      }),
    );
  }

  const beautyRows = expenses.filter(
    tx =>
      tx.occurredAt >= ninetyDaysAgo &&
      /美妆|护肤|彩妆|口红|面膜|美容|香水/.test(
        `${tx.categoryName ?? ''} ${tx.merchant ?? ''} ${tx.note ?? ''}`,
      ),
  );
  if (beautyRows.length >= 4) {
    const amount = beautyRows.reduce((sum, tx) => sum + netExpense(tx), 0);
    results.push(
      item({
        id: 'server:life:beauty-care',
        kind: 'life',
        priority: 'info',
        title: '最近挺重视美妆护理',
        summary: `近 90 天有 ${beautyRows.length} 笔美妆或护理相关消费。`,
        analysis: '这类消费已经形成比较稳定的生活投入，可以单独观察频率和预算变化。',
        meaning: '账单能说明你近期重视这类生活投入，但不会据此猜测你的性别或外貌。',
        response: 'encouragement',
        suggestion: profile.intents.includes('controlSpending')
          ? '如果你希望控制消费，可以给美妆护理单独留一个可持续预算。'
          : undefined,
        actionLabel: '查看流水',
        actionRoute: '/transactions',
        amount,
        evidence: [
          {
            label: '相关消费',
            value: beautyRows.length,
            unit: '笔',
            transactionIds: beautyRows.map(tx => tx.id),
          },
          { label: '涉及金额', value: amount, unit: currency },
        ],
        relatedTransactionIds: beautyRows.map(tx => tx.id),
        baseScore: 48,
        confidence,
        profile,
        feedback,
        generatedAt: now.getTime(),
      }),
    );
  }

  const pendingReimbursements = transactions.filter(
    tx => tx.reimbursementStatus === 'pending',
  );
  if (pendingReimbursements.length) {
    const amount = pendingReimbursements.reduce(
      (sum, tx) => sum + (tx.reimbursementAmount ?? tx.amount),
      0,
    );
    results.push(
      item({
        id: 'server:money:pending-reimbursement',
        kind: 'discovery',
        priority: amount >= 500 ? 'attention' : 'info',
        title: '有待报销支出还没闭环',
        summary: `当前有 ${pendingReimbursements.length} 笔待报销，涉及约 ¥${amount.toFixed(0)}。`,
        analysis: '待报销支出会暂时占用现金，但不应长期被当成你的真实个人消费。',
        meaning: '把报销状态补全后，预算、分类占比和消费趋势都会更准确。',
        response: 'advice',
        suggestion: '报销到账后及时标记已报销。',
        actionLabel: '处理报销',
        actionRoute: '/transactions/reimbursements',
        amount,
        evidence: [
          {
            label: '待报销',
            value: amount,
            unit: currency,
            transactionIds: pendingReimbursements.map(tx => tx.id),
          },
        ],
        relatedTransactionIds: pendingReimbursements.map(tx => tx.id),
        baseScore: amount >= 500 ? 72 : 58,
        confidence,
        profile,
        feedback,
        generatedAt: now.getTime(),
      }),
    );
  }

  const activeGoals = input.goals
    .filter(goal => goal.status === 'active')
    .sort((a, b) => a.targetDate - b.targetDate);
  if (activeGoals.length) {
    const goal = activeGoals[0]!;
    const total = goal.targetDate - goal.createdAt;
    if (total > 0) {
      const timeProgress = clamp((now.getTime() - goal.createdAt) / total);
      const moneyProgress = clamp(goal.currentAmount / goal.targetAmount);
      const gap = timeProgress - moneyProgress;
      if (Math.abs(gap) >= 0.1) {
        const behind = gap > 0;
        results.push(
          item({
            id: `server:goal:${goal.id}:progress`,
            kind: behind ? 'goal' : 'positive',
            priority: behind ? 'attention' : 'info',
            title: behind
              ? `${goal.name}需要再追一点进度`
              : `${goal.name}进度走在计划前面`,
            summary: `资金进度 ${Math.round(moneyProgress * 100)}%，时间进度 ${Math.round(timeProgress * 100)}%。`,
            analysis: behind
              ? '按当前目标日期看，资金积累速度低于时间进度。'
              : '当前资金积累速度高于目标时间进度。',
            meaning: behind
              ? '目标洞察会把消费、预算和储蓄放到同一个目标里看，而不是只评价某一笔支出。'
              : '这是与你设定的目标方向一致的积极变化。',
            response: behind ? 'advice' : 'encouragement',
            suggestion: behind
              ? '可以先查看目标每月预留，再决定是否调整预算或目标日期。'
              : '保持当前节奏即可，不需要为了更快而过度压缩正常生活支出。',
            actionLabel: '查看目标',
            actionRoute: `/goals/${goal.id}`,
            amount: goal.currentAmount,
            changePercent: (moneyProgress - timeProgress) * 100,
            evidence: [
              {
                label: '目标资金进度',
                value: moneyProgress * 100,
                baselineValue: timeProgress * 100,
                unit: '%',
              },
              {
                label: '还差金额',
                value: Math.max(0, goal.targetAmount - goal.currentAmount),
                unit: currency,
              },
            ],
            relatedTransactionIds: [],
            baseScore: behind ? 66 : 48,
            confidence: { ...confidence, baseline: Math.max(0.65, confidence.baseline) },
            profile,
            feedback,
            generatedAt: now.getTime(),
          }),
        );
      }
    }
  }

  const fourteenDays = now.getTime() + 14 * 86400000;
  const upcoming = input.recurringBills.filter(
    bill =>
      bill.status === 'active' &&
      bill.type !== 'income' &&
      bill.nextDate >= now.getTime() &&
      bill.nextDate <= fourteenDays,
  );
  const upcomingIncome = input.recurringBills
    .filter(
      bill =>
        bill.status === 'active' &&
        bill.type === 'income' &&
        bill.nextDate >= now.getTime() &&
        bill.nextDate <= fourteenDays,
    )
    .reduce((sum, bill) => sum + bill.amount, 0);
  const upcomingExpense = upcoming.reduce((sum, bill) => sum + bill.amount, 0);
  const liquid = input.accounts
    .filter(
      account =>
        !account.isArchived &&
        !['creditCard', 'liability'].includes(account.type) &&
        ['cash', 'walletBalance', 'demandDeposit', 'unspecified'].includes(
          account.assetForm,
        ),
    )
    .reduce((sum, account) => sum + Math.max(0, account.balance), 0);
  if (
    upcoming.length >= 2 ||
    (upcomingExpense >= 300 && confidence.completeness >= 0.5)
  ) {
    const netUpcoming = Math.max(0, upcomingExpense - upcomingIncome);
    const risk =
      liquid > 0 &&
      confidence.completeness >= 0.65 &&
      netUpcoming > liquid * 0.7;
    results.push(
      item({
        id: 'server:cashflow:upcoming-recurring',
        kind: risk ? 'risk' : 'discovery',
        priority: risk ? 'important' : 'attention',
        title: risk ? '未来两周固定支出比较集中' : '未来两周有几项固定支出',
        summary: `已知周期支出约 ¥${upcomingExpense.toFixed(0)}，共 ${upcoming.length} 项。`,
        analysis:
          upcomingIncome > 0
            ? `同期已知周期收入约 ¥${upcomingIncome.toFixed(0)}，系统会把两边一起看。`
            : '这是基于已经记录的周期账单，不会把未知收入或支出当成事实。',
        meaning: risk
          ? '结合当前记录的可用资产，这段时间的现金流余量可能偏紧。'
          : '提前看固定支出，可以避免只凭账户当前余额判断“还能花多少”。',
        response: risk ? 'advice' : 'notice',
        suggestion: risk
          ? '建议先确认近期收入与待还账户，再决定可调整消费额度。'
          : undefined,
        actionLabel: '查看周期账单',
        actionRoute: '/profile/recurring-bills',
        amount: upcomingExpense,
        evidence: [
          { label: '未来14天周期支出', value: upcomingExpense, unit: currency },
          if (upcomingIncome > 0)
            { label: '未来14天周期收入', value: upcomingIncome, unit: currency },
          if (liquid > 0)
            { label: '当前记录的流动资产', value: liquid, unit: currency },
        ],
        relatedTransactionIds: [],
        baseScore: risk ? 82 : 61,
        confidence,
        profile,
        feedback,
        generatedAt: now.getTime(),
      }),
    );
  }

  if (confidence.classification < 0.68 && expenses.length >= 12) {
    results.push(
      item({
        id: 'server:data:classification',
        kind: 'discovery',
        priority: 'attention',
        title: '有些分类值得先校正',
        summary: '部分流水分类可信度偏低，先把账分准，后面的消费结论才可靠。',
        analysis: '未分类、低置信度分类或疑似重复记录会直接影响分类占比和趋势判断。',
        meaning: '数据质量是洞察的前置条件；系统宁愿少说，也不基于明显可疑的数据下结论。',
        response: 'advice',
        suggestion: '建议先检查最近的未分类和自动识别流水。',
        actionLabel: '检查分类',
        actionRoute: '/profile/categories',
        evidence: [],
        relatedTransactionIds: [],
        baseScore: 72,
        confidence,
        profile,
        feedback,
        generatedAt: now.getTime(),
      }),
    );
  }

  const byId = new Map<string, InsightItem>();
  for (const result of results) {
    const previous = byId.get(result.id);
    if (!previous || result.score > previous.score) byId.set(result.id, result);
  }
  const items = [...byId.values()]
    .filter(result => !feedback.dismissedIds.has(result.id))
    .filter(result => overallConfidence(result.confidence) >= policy.minConfidence)
    .sort((a, b) => b.score - a.score);

  return {
    origin: 'serverConfirmed' as const,
    confirmedAt: Date.now(),
    dataConfidence: confidence.data,
    completeness: confidence.completeness,
    classificationConfidence: confidence.classification,
    baselineConfidence: confidence.baseline,
    homeMinScore: policy.homeMinScore,
    homeMinConfidence: policy.minConfidence,
    historyDays,
    cooldownDays: policy.cooldownDays,
    items,
  };
}
