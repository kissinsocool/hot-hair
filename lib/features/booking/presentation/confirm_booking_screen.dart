import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/router.dart';
import '../../../core/widgets/coupon_ticket.dart';
import '../../auth/data/user_auth_repository.dart';
import 'booking_notifier.dart';

class ConfirmBookingScreen extends ConsumerStatefulWidget {
  const ConfirmBookingScreen({super.key});

  @override
  ConsumerState<ConfirmBookingScreen> createState() =>
      _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends ConsumerState<ConfirmBookingScreen> {
  final UserAuthRepository _authRepository = UserAuthRepository();
  List<Map<String, dynamic>> _coupons = const [];
  String _selectedCouponId = '';
  bool _couponsLoading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    try {
      final coupons = await _authRepository.fetchCoupons();
      if (!mounted) return;
      final bookingState = ref.read(bookingProvider);
      final totalFen = (_parsePrice(bookingState.selectedService?.priceLabel) +
              (bookingState.selectedStaff?.extraServiceFee ?? 0)) *
          100;
      setState(() {
        _coupons = coupons;
        _selectedCouponId = _eligibleCoupons(coupons, totalFen)
                .any((coupon) => coupon['id'] == _selectedCouponId)
            ? _selectedCouponId
            : '';
        _couponsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _couponsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);
    final bookingNotifier = ref.read(bookingProvider.notifier);
    final servicePrice = _parsePrice(bookingState.selectedService?.priceLabel);
    final extraFee = bookingState.selectedStaff?.extraServiceFee ?? 0;
    final totalPrice = servicePrice + extraFee;
    final eligibleCoupons = _eligibleCoupons(_coupons, totalPrice * 100);
    final selectedCoupon = _selectedCoupon(eligibleCoupons, _selectedCouponId);
    final discountFen = _couponDiscount(selectedCoupon);
    final payableFen = totalPrice * 100 - discountFen;

    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        title: Text('最终确认', style: TextStyle(color: AppTheme.textDark)),
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textDark),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          MediaQuery.sizeOf(context).height * 0.2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请核对您的预约信息',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentBeige),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ],
              ),
              child: Column(
                children: [
                  _buildRow(
                      '服务项目', bookingState.selectedService?.name ?? '未选择'),
                  Divider(height: 30),
                  _buildRow(
                      '到店日期',
                      bookingState.selectedDate != null
                          ? DateFormat('yyyy-MM-dd')
                              .format(bookingState.selectedDate!)
                          : '未选择'),
                  SizedBox(height: 10),
                  _buildRow('到店时间', bookingState.selectedTime ?? '未选择'),
                  Divider(height: 30),
                  _buildRow('理发师', bookingState.selectedStaff?.name ?? '未选择'),
                  Divider(height: 30),
                  _buildRow('服务费用', _formatPrice(servicePrice)),
                  SizedBox(height: 10),
                  _buildRow('理发师额外服务费', _formatPrice(extraFee)),
                  Divider(height: 30),
                  InkWell(
                    onTap: _couponsLoading
                        ? null
                        : () => _chooseCoupon(eligibleCoupons),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          const Text(
                            '优惠券',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _couponsLoading
                                  ? '加载中'
                                  : '${selectedCoupon?['title']?.toString() ?? '选择优惠券'} >',
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selectedCoupon == null
                                    ? Colors.grey
                                    : AppTheme.primaryPink,
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (selectedCoupon != null) ...[
                    const SizedBox(height: 10),
                    _buildRow('优惠金额', '-${_formatFen(discountFen)}'),
                  ],
                  Divider(height: 30),
                  _buildRow(
                    '到店需支付',
                    _formatFen(payableFen),
                    valueColor: AppTheme.primaryPink,
                    isEmphasis: true,
                  ),
                ],
              ),
            ),
            SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () => _submit(
                          context,
                          bookingNotifier,
                          bookingState,
                          selectedCoupon == null ? '' : _selectedCouponId,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPink,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: Text('提交预约申请',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    Color? valueColor,
    bool isEmphasis = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isEmphasis ? 18 : 14,
              color: valueColor ?? AppTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }

  int _parsePrice(String? priceLabel) {
    final digits = (priceLabel ?? '').replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(digits) ?? 0;
  }

  String _formatPrice(int value) {
    final formatted = NumberFormat('#,###').format(value);
    return '¥$formatted';
  }

  static int _couponDiscount(Map<String, dynamic>? coupon) =>
      (coupon?['discountFen'] as num?)?.toInt() ?? 0;

  static String _formatFen(int value) {
    final amount = value / 100;
    return '¥${NumberFormat('#,##0.00').format(amount)}';
  }

  static List<Map<String, dynamic>> _eligibleCoupons(
    List<Map<String, dynamic>> coupons,
    int totalFen,
  ) {
    return coupons
        .where(
          (coupon) =>
              coupon['status'] == 'available' &&
              ((coupon['minimumSpendFen'] as num?)?.toInt() ?? 0) <= totalFen,
        )
        .toList();
  }

  static Map<String, dynamic>? _selectedCoupon(
    List<Map<String, dynamic>> coupons,
    String couponId,
  ) {
    for (final coupon in coupons) {
      if (coupon['id']?.toString() == couponId) return coupon;
    }
    return null;
  }

  Future<void> _chooseCoupon(
    List<Map<String, dynamic>> eligibleCoupons,
  ) async {
    final couponId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CouponSelectionScreen(
          coupons: eligibleCoupons,
          selectedCouponId: _selectedCouponId,
        ),
      ),
    );
    if (couponId != null && mounted) {
      setState(() => _selectedCouponId = couponId);
    }
  }

  Future<void> _submit(
    BuildContext context,
    BookingNotifier notifier,
    BookingState state,
    String couponId,
  ) async {
    if (state.selectedStaff == null ||
        state.selectedService == null ||
        state.selectedTime == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('请完成所有预约选项')));
      return;
    }

    setState(() => _submitting = true);
    final success = await notifier.confirmBooking(
      state.selectedStaff!.id,
      state.selectedService!.id,
      state.selectedTime!,
      couponId: couponId,
    );

    if (!context.mounted) return;
    setState(() => _submitting = false);

    if (success) {
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) => SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.all(15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 60),
                SizedBox(height: 20),
                Text('预约申请已发送给商家！',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark),
                    textAlign: TextAlign.center),
                SizedBox(height: 8),
                Text('商家接单或拒单后，您可以在预约消息中查看结果。',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center),
                SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go(AppRouter.userMessages);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink),
                    child:
                        Text('查看预约消息', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('预约提交失败，请刷新优惠券后重试')),
      );
    }
  }
}

class CouponSelectionScreen extends StatelessWidget {
  const CouponSelectionScreen({
    super.key,
    required this.coupons,
    required this.selectedCouponId,
  });

  final List<Map<String, dynamic>> coupons;
  final String selectedCouponId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        title: const Text('选择优惠券'),
        backgroundColor: AppTheme.white,
        actions: [
          if (selectedCouponId.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('不使用'),
            ),
        ],
      ),
      body: coupons.isEmpty
          ? const Center(child: Text('暂无可用优惠券'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: coupons.length,
              separatorBuilder: (_, __) => const SizedBox.shrink(),
              itemBuilder: (context, index) {
                final coupon = coupons[index];
                final id = coupon['id']?.toString() ?? '';
                final selected = id == selectedCouponId;
                return CouponTicket(
                  key: ValueKey('select-coupon-$id'),
                  coupon: coupon,
                  enabled: true,
                  selected: selected,
                  onTap: () => Navigator.pop(context, id),
                );
              },
            ),
    );
  }
}
