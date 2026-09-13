import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createApp } from '../src/app.js';
import type { AssistantModelProvider } from '../src/assistant_ai.js';

test('助手策略接口限制边界、次数和会员功能', async t => {
  const { app, store } = await createApp(':memory:');
  const base = await app.listen({ host: '127.0.0.1', port: 0 });
  t.after(() => app.close());
  const request = async (path: string, token = '', body?: unknown, method = body ? 'POST' : 'GET') => {
    const response = await fetch(`${base}/api/v1${path}`, {
      method,
      headers: {
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: response.status, data: await response.json() as Record<string, unknown> };
  };
  const register = await request('/auth/register', '', { username: 'assistant_user', password: 'local-test-password' });
  assert.equal(register.status, 201);
  const token = register.data.token as string;
  const id = '0123456789abcdef0123456789abcdef';

  const code = await request('/assistant/authorize', token, { requestId: id, text: '请帮我写一段 Python 代码' });
  assert.equal(code.status, 200);
  assert.equal(code.data.allowed, false);
  assert.match(String(code.data.message), /只处理记账/);

  const voice = await request('/assistant/authorize', token, { requestId: `${id}voice`, feature: 'voice' });
  assert.equal(voice.status, 200);
  assert.equal(voice.data.allowed, false);
  assert.equal(voice.data.requiresMembership, true);

  const configured = await request('/admin/assistant/config', token);
  assert.equal(configured.status, 503);

  const replay = await request('/assistant/authorize', token, { requestId: id, text: '请帮我写一段 Python 代码' });
  assert.deepEqual(replay.data, code.data);

  const user = store.db.prepare('SELECT id FROM users WHERE username=?').get('assistant_user') as { id: string };
  store.db.prepare('INSERT INTO assistant_memberships VALUES(?,?)').run(user.id, store.now() + 3600);
  const memberVoice = await request('/assistant/authorize', token, { requestId: `${id}member`, feature: 'voice' });
  assert.equal(memberVoice.data.allowed, true);
});

test('管理员可以更新助手提示词和边界策略，但公共接口不泄露提示词', async t => {
  const previous = process.env.ASSISTANT_ADMIN_TOKEN;
  process.env.ASSISTANT_ADMIN_TOKEN = 'assistant-admin-token-with-32-characters-000';
  t.after(() => {
    if (previous == null) delete process.env.ASSISTANT_ADMIN_TOKEN;
    else process.env.ASSISTANT_ADMIN_TOKEN = previous;
  });
  const { app } = await createApp(':memory:');
  const base = await app.listen({ host: '127.0.0.1', port: 0 });
  t.after(() => app.close());
  const fetchJson = async (path: string, options: RequestInit = {}) => {
    const response = await fetch(`${base}/api/v1${path}`, options);
    return { status: response.status, data: await response.json() as Record<string, unknown> };
  };
  const update = await fetchJson('/admin/assistant/config', {
    method: 'PUT',
    headers: { Authorization: `Bearer ${process.env.ASSISTANT_ADMIN_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      enabled: true,
      systemPrompt: '你只能处理记账业务，并且必须在真实业务落库后再确认结果，不得提供代码、写作或其他通用任务。',
      boundaryReply: '仅支持记账相关问题。',
      maxInputLength: 200,
      freeDailyLimit: 2,
      memberDailyLimit: 20,
      requestsPerMinute: 5,
      memberFeatures: ['voice'],
    }),
  });
  assert.equal(update.status, 200);
  assert.equal((await fetchJson('/assistant/config')).data.systemPrompt, undefined);
  const admin = await fetchJson('/admin/assistant/config', { headers: { Authorization: `Bearer ${process.env.ASSISTANT_ADMIN_TOKEN}` } });
  assert.equal(admin.data.maxInputLength, 200);
});

test('模型对话使用后端提示词、请求幂等且不重复扣次数', async t => {
  const calls: Array<{ systemPrompt: string; userText: string }> = [];
  const provider: AssistantModelProvider = {
    async complete(input) {
      calls.push(input);
      return '我可以帮助记录账单并查询收支。';
    },
  };
  const previous = process.env.ASSISTANT_ADMIN_TOKEN;
  process.env.ASSISTANT_ADMIN_TOKEN = 'assistant-admin-token-with-32-characters-000';
  t.after(() => {
    if (previous == null) delete process.env.ASSISTANT_ADMIN_TOKEN;
    else process.env.ASSISTANT_ADMIN_TOKEN = previous;
  });
  const { app, store } = await createApp(':memory:', provider);
  const base = await app.listen({ host: '127.0.0.1', port: 0 });
  t.after(() => app.close());
  const request = async (path: string, token = '', body?: unknown, method = body ? 'POST' : 'GET') => {
    const response = await fetch(`${base}/api/v1${path}`, {
      method,
      headers: {
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: response.status, data: await response.json() as Record<string, unknown> };
  };
  const register = await request('/auth/register', '', { username: 'assistant_chat_test', password: 'local-test-password' });
  assert.equal(register.status, 201);
  const token = register.data.token as string;
  const prompt = '只处理记账相关请求；真实业务写入成功前不得声称已记账，也不得提供代码或通用任务答案。';
  const config = await request('/admin/assistant/config', process.env.ASSISTANT_ADMIN_TOKEN, {
    enabled: true,
    systemPrompt: prompt,
    boundaryReply: '请只咨询记账相关问题。',
    maxInputLength: 300,
    freeDailyLimit: 30,
    memberDailyLimit: 300,
    requestsPerMinute: 10,
    memberFeatures: ['voice'],
  }, 'PUT');
  assert.equal(config.status, 200);
  const body = { requestId: 'abcdef0123456789abcdef0123456789', text: '你好，请说明你能提供什么帮助' };
  const first = await request('/assistant/chat', token, body);
  assert.equal(first.status, 200);
  assert.equal(first.data.source, 'deepseek');
  assert.equal(first.data.remaining, 29);
  assert.equal(calls.length, 1);
  assert.equal(calls[0]?.systemPrompt, prompt);
  const replay = await request('/assistant/chat', token, body);
  assert.deepEqual(replay.data, first.data);
  assert.equal(calls.length, 1);
  const usage = store.db.prepare('SELECT used FROM assistant_usage').get() as { used: number };
  assert.equal(usage.used, 1);
});
