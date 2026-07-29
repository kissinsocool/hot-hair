import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_hair_app/features/booking/presentation/confirm_booking_screen.dart';

void main() {
  testWidgets('selecting one coupon returns it to the confirmation page',
      (tester) async {
    String? selectedCouponId;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selectedCouponId = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => const CouponSelectionScreen(
                    coupons: [
                      {
                        'id': 'coupon-1',
                        'title': '满99减20',
                        'minimumSpendFen': 9900,
                        'discountFen': 2000,
                      },
                      {
                        'id': 'coupon-2',
                        'title': '满199减30',
                        'minimumSpendFen': 19900,
                        'discountFen': 3000,
                      },
                    ],
                    selectedCouponId: '',
                  ),
                ),
              );
            },
            child: const Text('选择优惠券'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('选择优惠券'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-coupon-coupon-2')));
    await tester.pumpAndSettle();

    expect(selectedCouponId, 'coupon-2');
    expect(find.byType(CouponSelectionScreen), findsNothing);
  });
}
