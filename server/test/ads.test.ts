import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createApp } from '../src/app.js';

test('ad placement config is explicitly unconfigured by default', async t => {
  const previousPlacements = process.env.ADS_PLACEMENTS_JSON;
  const previousVersion = process.env.ADS_CONFIG_VERSION;
  delete process.env.ADS_PLACEMENTS_JSON;
  delete process.env.ADS_CONFIG_VERSION;
  t.after(() => {
    if (previousPlacements == null) delete process.env.ADS_PLACEMENTS_JSON;
    else process.env.ADS_PLACEMENTS_JSON = previousPlacements;
    if (previousVersion == null) delete process.env.ADS_CONFIG_VERSION;
    else process.env.ADS_CONFIG_VERSION = previousVersion;
  });

  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const response = await app.inject({
    method: 'GET',
    url: '/api/v1/ads/placements',
  });
  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.json(), {
    configured: false,
    configVersion: 'local',
    placements: [],
  });
});

test('ad placement config accepts safe surface-format combinations', async t => {
  const previousPlacements = process.env.ADS_PLACEMENTS_JSON;
  const previousVersion = process.env.ADS_CONFIG_VERSION;
  process.env.ADS_CONFIG_VERSION = '2026-09-19-a';
  process.env.ADS_PLACEMENTS_JSON = JSON.stringify([
    {
      id: 'goal-membership',
      surface: 'goalPromo',
      format: 'native',
      contentType: 'membership',
      title: '家庭目标',
      description: '一起完成目标',
      actionLabel: '查看',
      actionRoute: '/profile/family',
      enabled: true,
      targetAudience: 'free',
      dailyLimit: 2,
      priority: 80,
      provider: 'internal',
      contentCategory: 'productFeature',
    },
    {
      id: 'startup-network',
      surface: 'splash',
      format: 'splash',
      contentType: 'thirdParty',
      title: '第三方开屏',
      description: '',
      actionLabel: null,
      actionRoute: null,
      enabled: true,
      targetAudience: 'free',
      dailyLimit: 1,
      priority: 100,
      provider: 'vendor',
      contentCategory: 'consumerCampaign',
    },
  ]);
  t.after(() => {
    if (previousPlacements == null) delete process.env.ADS_PLACEMENTS_JSON;
    else process.env.ADS_PLACEMENTS_JSON = previousPlacements;
    if (previousVersion == null) delete process.env.ADS_CONFIG_VERSION;
    else process.env.ADS_CONFIG_VERSION = previousVersion;
  });

  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const response = await app.inject({
    method: 'GET',
    url: '/api/v1/ads/placements',
  });
  assert.equal(response.statusCode, 200);
  const body = response.json() as any;
  assert.equal(body.configured, true);
  assert.equal(body.configVersion, '2026-09-19-a');
  assert.equal(body.placements.length, 2);
  assert.equal(body.placements[0].provider, 'internal');
  assert.equal(body.placements[1].provider, 'vendor');
});

test('ad placement config rejects unsafe or structurally invalid placements', async t => {
  const previous = process.env.ADS_PLACEMENTS_JSON;
  t.after(() => {
    if (previous == null) delete process.env.ADS_PLACEMENTS_JSON;
    else process.env.ADS_PLACEMENTS_JSON = previous;
  });

  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const invalidConfigs = [
    [
      {
        id: 'wrong-format',
        surface: 'splash',
        format: 'native',
        contentType: 'thirdParty',
        title: '错误类型',
        description: '',
        enabled: true,
        targetAudience: 'free',
        dailyLimit: 1,
        priority: 1,
        provider: 'vendor',
        contentCategory: 'consumerCampaign',
      },
    ],
    [
      {
        id: 'unsafe-provider',
        surface: 'goalPromo',
        format: 'native',
        contentType: 'thirdParty',
        title: '错误 Provider',
        description: '',
        enabled: true,
        targetAudience: 'free',
        dailyLimit: 1,
        priority: 1,
        provider: 'internal',
        contentCategory: 'consumerCampaign',
      },
    ],
    [
      {
        id: 'too-frequent-splash',
        surface: 'splash',
        format: 'splash',
        contentType: 'thirdParty',
        title: '过度开屏',
        description: '',
        enabled: true,
        targetAudience: 'free',
        dailyLimit: 2,
        priority: 1,
        provider: 'vendor',
        contentCategory: 'consumerCampaign',
      },
    ],
    [
      {
        id: 'unsafe-category',
        surface: 'goalPromo',
        format: 'native',
        contentType: 'thirdParty',
        title: '高风险内容',
        description: '',
        enabled: true,
        targetAudience: 'free',
        dailyLimit: 1,
        priority: 1,
        provider: 'vendor',
        contentCategory: 'gambling',
      },
    ],
  ];

  for (const config of invalidConfigs) {
    process.env.ADS_PLACEMENTS_JSON = JSON.stringify(config);
    const response = await app.inject({
      method: 'GET',
      url: '/api/v1/ads/placements',
    });
    assert.equal(response.statusCode, 400);
  }
});
