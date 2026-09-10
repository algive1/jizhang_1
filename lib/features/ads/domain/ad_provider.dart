import '../../../core/models/placement.dart';

abstract interface class AdProvider {
  String get id;
  Future<bool> isAvailable(AdFormat format);
  Future<NativeAdPayload?> loadNative(PlacementConfig placement);
  Future<AdDeliveryResult> showSplash(PlacementConfig placement);
  Future<AdDeliveryResult> showRewarded(PlacementConfig placement);
}

class UnconfiguredAdProvider implements AdProvider {
  const UnconfiguredAdProvider();

  @override
  String get id => 'unconfigured';

  @override
  Future<bool> isAvailable(AdFormat format) async => false;

  @override
  Future<NativeAdPayload?> loadNative(PlacementConfig placement) async => null;

  @override
  Future<AdDeliveryResult> showRewarded(PlacementConfig placement) async =>
      const AdDeliveryResult(completed: false);

  @override
  Future<AdDeliveryResult> showSplash(PlacementConfig placement) async =>
      const AdDeliveryResult(completed: false);
}
