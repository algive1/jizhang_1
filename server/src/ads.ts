import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

function formatMatchesSurface(
  surface: 'splash' | 'homePromo' | 'profilePromo' | 'goalPromo' | 'aiReward',
  format: 'splash' | 'native' | 'rewarded',
) {
  if (surface === 'splash') return format === 'splash';
  if (surface === 'aiReward') return format === 'rewarded';
  return format === 'native';
}

const placementSchema = z
  .strictObject({
    id: z.string().regex(/^[a-z0-9][a-z0-9_-]{1,63}$/),
    surface: z.enum([
      'splash',
      'homePromo',
      'profilePromo',
      'goalPromo',
      'aiReward',
    ]),
    format: z.enum(['splash', 'native', 'rewarded']),
    contentType: z.enum(['membership', 'feature', 'campaign', 'thirdParty']),
    title: z.string().trim().min(1).max(80),
    description: z.string().trim().max(240),
    actionLabel: z.string().trim().min(1).max(32).nullable().optional(),
    actionRoute: z
      .string()
      .trim()
      .regex(/^\/[a-zA-Z0-9_\-/:.]*$/)
      .max(160)
      .nullable()
      .optional(),
    enabled: z.boolean(),
    targetAudience: z.enum(['all', 'free', 'pro', 'family']),
    startAt: z.number().int().nonnegative().nullable().optional(),
    endAt: z.number().int().nonnegative().nullable().optional(),
    dailyLimit: z.number().int().min(1).max(20),
    priority: z.number().int().min(0).max(1000),
    provider: z.string().regex(/^[a-z0-9][a-z0-9_-]{1,31}$/),
    contentCategory: z.enum([
      'productFeature',
      'financialEducation',
      'consumerCampaign',
    ]),
  })
  .superRefine((placement, ctx) => {
    if (!formatMatchesSurface(placement.surface, placement.format)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['format'],
        message: '广告类型与 Placement 位置不匹配',
      });
    }
    if (placement.surface === 'splash' && placement.dailyLimit !== 1) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['dailyLimit'],
        message: '开屏广告每天最多一次',
      });
    }
    if (
      placement.startAt != null &&
      placement.endAt != null &&
      placement.startAt >= placement.endAt
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['endAt'],
        message: '广告结束时间必须晚于开始时间',
      });
    }
    if (
      placement.contentType === 'thirdParty' &&
      placement.provider === 'internal'
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['provider'],
        message: '第三方广告不能使用 internal provider',
      });
    }
    if (
      placement.contentType !== 'thirdParty' &&
      placement.provider !== 'internal'
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['provider'],
        message: '内部推广位必须使用 internal provider',
      });
    }
    if (
      placement.contentType === 'thirdParty' &&
      placement.actionRoute != null
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['actionRoute'],
        message: '第三方广告跳转必须由广告 SDK 管理',
      });
    }
  });

const configSchema = z
  .array(placementSchema)
  .max(100)
  .refine(
    (items) => new Set(items.map((item) => item.id)).size === items.length,
    'Placement ID 不能重复',
  );

function configuredPlacements() {
  const raw = (process.env.ADS_PLACEMENTS_JSON ?? '').trim();
  if (!raw) {
    return {
      configured: false,
      placements: [] as z.infer<typeof placementSchema>[],
    };
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error('ADS_PLACEMENTS_JSON 不是有效 JSON');
  }
  return {
    configured: true,
    placements: configSchema.parse(parsed),
  };
}

export function registerAdConfigRoutes(app: FastifyInstance) {
  app.get('/api/v1/ads/placements', async () => {
    const config = configuredPlacements();
    return {
      configured: config.configured,
      configVersion: process.env.ADS_CONFIG_VERSION?.trim() || 'local',
      placements: config.placements,
    };
  });
}
