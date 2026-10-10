import type { FastifyInstance } from 'fastify';
import type { Store } from '../store.js';
import { requireCondition as check } from '../contract.js';
import { getPublishedDocuments } from './documents.js';

export function publishedAppFlags(store: Store, installationId?: string): Record<string, boolean> {
  const flags: Record<string, boolean> = {};
  for (const doc of getPublishedDocuments(store, 'config', installationId)) {
    for (const [key, value] of Object.entries(doc.payload as Record<string, unknown>)) {
      if (typeof value === 'boolean') flags[key] = value;
    }
  }
  return flags;
}

/// The same rollout cohort is used by configuration delivery and execution.
/// Local bookkeeping/backup recovery and administrative endpoints stay usable.
export function registerAppCapabilityGuard(app: FastifyInstance, store: Store) {
  app.addHook('preHandler', async request => {
    const path = request.url.split('?')[0] ?? '';
    const required: string[] = [];
    if (path.startsWith('/api/v1/assistant/') && request.method === 'POST') required.push('aiEnabled');
    if (path === '/api/v1/insights/interpret' && request.method === 'POST') required.push('aiEnabled');
    if (path === '/api/v1/assistant/parse-transaction') {
      const source = (request.body as {source?: string} | undefined)?.source;
      if (source === 'ocr') required.push('ocrEnabled');
      if (source === 'voice') required.push('voiceEnabled');
    }
    if (path === '/api/v1/asr/recognize') required.push('voiceEnabled');
    if (path.startsWith('/api/v1/sync/') && path !== '/api/v1/sync/status') required.push('cloudBackupEnabled');
    if (required.length === 0) return;
    const header = request.headers['x-app-installation-id'];
    const installationId = typeof header === 'string' && /^[a-f0-9]{32}$/.test(header) ? header : undefined;
    const flags = publishedAppFlags(store, installationId);
    const labels: Record<string, string> = {aiEnabled:'AI 服务', ocrEnabled:'账单识别', voiceEnabled:'语音记账', cloudBackupEnabled:'云备份'};
    for (const key of required) check(flags[key] !== false, `${labels[key]}暂时关闭，请稍后重试`, 503);
  });
}
