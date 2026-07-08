import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/router.dart';
import 'booking_notifier.dart';

class ConfirmBookingScreen extends ConsumerWidget {
  const ConfirmBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingState = ref.watch(bookingProvider);
    final bookingNotifier = ref.read(bookingProvider.notifier);
    final servicePrice = _parsePrice(bookingState.selectedService?.priceLabel);
    final extraFee = bookingState.selectedStaff?.extraServiceFee ?? 0;
    final totalPrice = servicePrice + extraFee;

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
                      '预约日期',
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
                  _buildRow(
                    '合计',
                    _formatPrice(totalPrice),
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
                onPressed: () =>
                    _submit(context, bookingNotifier, bookingState),
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

  void _submit(BuildContext context, BookingNotifier notifier,
      BookingState state) async {
    if (state.selectedStaff == null ||
        state.selectedService == null ||
        state.selectedTime == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('请完成所有预约选项')));
      return;
    }

    final success = await notifier.confirmBooking(
        state.selectedStaff!.id, state.selectedService!.id, state.selectedTime!,
        candidateStaffIds: state.selectedStaff!.id == '__no_preference__'
            ? state.noPreferenceCandidateStaffIds
            : const []);

    if (!context.mounted) return;

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
    }
  }
}
