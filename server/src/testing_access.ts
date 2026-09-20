export function allFeaturesFreeForTesting(): boolean {
  return process.env.ALL_FEATURES_FREE_FOR_TESTING === 'true';
}
