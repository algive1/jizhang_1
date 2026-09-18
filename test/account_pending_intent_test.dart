import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/account/application/account_pending_intent.dart';

void main() {
  test('pending intent keeps action metadata and can be consumed once', () {
    final controller = AccountPendingIntentController();
    const intent = AccountPendingIntent(
      id: 'membership:pro_monthly:wechatPay',
      action: AccountPendingAction.membershipPurchase,
      returnLocation: '/profile/membership',
      payload: {
        'productId': 'pro_monthly',
        'channel': 'wechatPay',
      },
    );

    controller.set(intent);
    expect(controller.current, same(intent));
    expect(controller.consume(intent.id), same(intent));
    expect(controller.current, isNull);
    expect(controller.consume(intent.id), isNull);
  });

  test('clearing a different intent id does not remove the current action', () {
    final controller = AccountPendingIntentController();
    const intent = AccountPendingIntent(
      id: 'join-1',
      action: AccountPendingAction.joinSharedLedger,
      returnLocation: '/profile/family',
    );
    controller.set(intent);
    controller.clear('other');
    expect(controller.current, same(intent));
    controller.clear('join-1');
    expect(controller.current, isNull);
  });
}
