import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

class CouponTicket extends StatelessWidget {
  const CouponTicket({
    super.key,
    required this.coupon,
    this.enabled,
    this.selected = false,
    this.onTap,
  });

  final Map<String, dynamic> coupon;
  final bool? enabled;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final minimum = ((coupon['minimumSpendFen'] as num?) ?? 0) / 100;
    final discount = ((coupon['discountFen'] as num?) ?? 0) / 100;
    final status = coupon['status']?.toString() ?? 'expired';
    final validUntil = DateTime.tryParse(
      coupon['validUntil']?.toString() ?? '',
    )?.toLocal();
    final isEnabled = enabled ??
        (status == 'unclaimed' || status == 'pending' || status == 'available');
    final minimumText = minimum.toStringAsFixed(minimum % 1 == 0 ? 0 : 2);
    final discountText = discount.toStringAsFixed(discount % 1 == 0 ? 0 : 2);
    final validityText = validUntil == null
        ? '有效期未设置'
        : '${DateFormat('yyyy.MM.dd').format(validUntil)}到期';
    final couponColor =
        isEnabled ? const Color(0xFFD06884) : Colors.grey.shade500;
    final stubColor =
        isEnabled ? const Color(0xFFFDE4EB) : Colors.grey.shade200;

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 114,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: couponColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: couponColor.withValues(alpha: selected ? 0.34 : 0.2),
                blurRadius: selected ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        color:
                            isEnabled ? AppTheme.white : Colors.grey.shade100,
                        padding: EdgeInsets.fromLTRB(
                          onTap == null ? 14 : 38,
                          12,
                          12,
                          11,
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: discountText,
                                              style: const TextStyle(
                                                fontSize: 52,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -2,
                                                height: 0.9,
                                              ),
                                            ),
                                            const TextSpan(
                                              text: '元',
                                              style: TextStyle(
                                                fontSize: 23,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        style: TextStyle(color: couponColor),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '代金券',
                                        style: TextStyle(
                                          color: couponColor,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '满$minimumText元可用',
                                        style: TextStyle(
                                          color: couponColor.withValues(
                                            alpha: 0.78,
                                          ),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    coupon['title']?.toString().isNotEmpty ==
                                            true
                                        ? coupon['title'].toString()
                                        : '优惠券',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: couponColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Container(
                                  width: 1,
                                  height: 12,
                                  color: couponColor.withValues(alpha: 0.45),
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    validityText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: couponColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 68,
                      color: stubColor,
                      alignment: Alignment.center,
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Text(
                          'COUPON',
                          style: TextStyle(
                            color: couponColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  bottom: 10,
                  right: 67,
                  child: SizedBox(
                    width: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        11,
                        (_) => Container(
                          width: 2,
                          height: 3,
                          decoration: BoxDecoration(
                            color: couponColor,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -11,
                  right: 57,
                  child: IgnorePointer(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: couponColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -11,
                  right: 57,
                  child: IgnorePointer(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: couponColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                if (onTap != null)
                  Positioned(
                    left: 7,
                    top: 7,
                    child: IgnorePointer(
                      child: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? couponColor
                            : couponColor.withValues(alpha: 0.52),
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
