import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/placement.dart';
import '../../../core/widgets/app_card.dart';
import '../data/placement_repository.dart';

class PlacementSlot extends ConsumerStatefulWidget {
  const PlacementSlot({required this.surface, super.key});

  final PlacementSurface surface;

  @override
  ConsumerState<PlacementSlot> createState() => _PlacementSlotState();
}

class _PlacementSlotState extends ConsumerState<PlacementSlot> {
  String? _recordedPlacementId;

  @override
  Widget build(BuildContext context) {
    final placement = ref.watch(eligiblePlacementProvider(widget.surface));
    return placement.when(
      data: (value) {
        if (value == null) return const SizedBox.shrink();
        if (value.contentType == PlacementContentType.thirdParty) {
          return const SizedBox.shrink();
        }
        _recordImpression(value);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppCard(
            padding: const EdgeInsets.all(15),
            color: AppColors.surfaceSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '推广 · 好好记账',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  value.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (value.actionLabel != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _open(value),
                      child: Text(value.actionLabel!),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _recordImpression(PlacementConfig placement) {
    if (_recordedPlacementId == placement.id) return;
    _recordedPlacementId = placement.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(adEventRepositoryProvider)
          .record(placement: placement, type: AdEventType.impression);
    });
  }

  Future<void> _open(PlacementConfig placement) async {
    await ref
        .read(adEventRepositoryProvider)
        .record(placement: placement, type: AdEventType.click);
    if (!mounted) return;
    final route = placement.actionRoute;
    if (route != null) {
      context.go(route);
    }
  }
}
