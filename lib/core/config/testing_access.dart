import 'package:flutter/foundation.dart';

/// Temporary access switch used while the product is still in end-to-end testing.
///
/// Debug builds remain open for local testing; release builds enforce membership.
/// An explicit dart-define can enable test access for a release test package.
const bool kAllFeaturesFreeForTesting = bool.fromEnvironment(
  'ALL_FEATURES_FREE_FOR_TESTING',
  defaultValue: !kReleaseMode,
);
