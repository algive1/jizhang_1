import 'package:flutter/services.dart';

/// Sends a lightweight native confirmation after an automatic bookkeeping
/// operation commits. The call is intentionally best-effort: desktop, iOS,
/// tests and older Android builds can continue without a native handler.
abstract final class BookkeepingFeedback {
  static const _channel = MethodChannel('jizhang/bookkeeping_feedback');

  static Future<void> notifySuccess({required int count}) async {
    if (count <= 0) return;
    try {
      await _channel.invokeMethod<void>('notifySuccess', {'count': count});
    } on Object {
      // Native feedback is optional outside Android and must never affect the
      // already-committed bookkeeping result.
    }
  }
}
