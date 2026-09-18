import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

const platformSchema = z.enum(['android', 'ios']);
const versionSchema = z.string().regex(/^\d+\.\d+\.\d+$/);

type PlatformName = z.infer<typeof platformSchema>;

function compareVersions(left: string, right: string) {
  const a = left.split('.').map(Number);
  const b = right.split('.').map(Number);
  for (let index = 0; index < 3; index += 1) {
    if (a[index] !== b[index]) return a[index] < b[index] ? -1 : 1;
  }
  return 0;
}

function envName(platform: PlatformName, suffix: string) {
  return `APP_UPDATE_${platform.toUpperCase()}_${suffix}`;
}

function config(platform: PlatformName) {
  const latestVersion = process.env[envName(platform, 'LATEST_VERSION')] ?? '1.0.0';
  const minimumVersion = process.env[envName(platform, 'MINIMUM_VERSION')] ?? '1.0.0';
  const storeUrl = (process.env[envName(platform, 'STORE_URL')] ?? '').trim();
  const message = (
    process.env[envName(platform, 'MESSAGE')] ??
    '发现新版本，建议更新后继续使用。'
  ).trim();

  versionSchema.parse(latestVersion);
  versionSchema.parse(minimumVersion);
  if (compareVersions(minimumVersion, latestVersion) > 0) {
    throw new Error(`${platform} 最低支持版本不能高于最新版本`);
  }
  return { latestVersion, minimumVersion, storeUrl, message };
}

export function registerAppUpdateRoutes(app: FastifyInstance) {
  app.get('/api/v1/app/update', async (request) => {
    const input = z.strictObject({
      platform: platformSchema,
      version: versionSchema,
    }).parse(request.query);
    const value = config(input.platform);

    if (!value.storeUrl) {
      return {
        status: 'none' as const,
        latestVersion: value.latestVersion,
        minimumVersion: value.minimumVersion,
        storeUrl: null,
        message: null,
      };
    }

    const belowMinimum =
      compareVersions(input.version, value.minimumVersion) < 0;
    const belowLatest = compareVersions(input.version, value.latestVersion) < 0;
    return {
      status: belowMinimum
        ? ('required' as const)
        : belowLatest
          ? ('optional' as const)
          : ('none' as const),
      latestVersion: value.latestVersion,
      minimumVersion: value.minimumVersion,
      storeUrl: value.storeUrl,
      message: belowLatest ? value.message : null,
    };
  });
}
