/// Temporary access switch used while the product is still in end-to-end testing.
///
/// The default is intentionally open for the current test phase. Before public
/// launch set `--dart-define=ALL_FEATURES_FREE_FOR_TESTING=false` (or change
/// the default) to restore normal membership gating.
const bool kAllFeaturesFreeForTesting = bool.fromEnvironment(
  'ALL_FEATURES_FREE_FOR_TESTING',
  defaultValue: true,
);
