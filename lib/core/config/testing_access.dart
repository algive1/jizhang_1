/// Temporary pre-release access switch.
///
/// During the current product-test phase every feature and theme is available
/// without a membership. Before production launch, build with
/// `--dart-define=TEST_ALL_FEATURES_FREE=false` and restore the intended
/// membership catalog/policies.
const bool testingAllFeaturesFree = bool.fromEnvironment(
  'TEST_ALL_FEATURES_FREE',
  defaultValue: true,
);
