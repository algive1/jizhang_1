export function testingAllFeaturesFree(): boolean {
  const raw = (process.env.TEST_ALL_FEATURES_FREE ?? 'true')
    .trim()
    .toLowerCase();
  return !['0', 'false', 'off', 'no'].includes(raw);
}
