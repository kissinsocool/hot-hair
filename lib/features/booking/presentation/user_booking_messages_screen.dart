import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/booking_message_read_store.dart';
import '../data/booking_update_stream.dart';
import '../data/order_repository.dart';
import '../domain/booking_order.dart';

class UserBookingMessagesScreen extends StatefulWidget {
  const UserBookingMessagesScreen({super.key});

  @override
  State<UserBookingMessagesScreen> createState() =>
      _UserBookingMessagesScreenState();
}

class _UserBookingMessagesScreenState extends State<UserBookingMessagesScreen> {
  final OrderRepository _repository = OrderRepository();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  StreamSubscription<Map<String, dynamic>>? _bookingUpdateSubscription;
  bool _isLoading = true;
  String _errorMessage = '';
  List<BookingOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
    BookingUpdateStream.instance.start();
    _bookingUpdateSubscription =
        BookingUpdateStream.instance.stream.listen((event) {
      if (event['event'] == 'booking.created' ||
          event['event'] == 'booking.updated') {
        _loadOrders(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _bookingUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final orders = await _repository.fetchUserBookings();
      if (!mounted) return;
      await BookingMessageReadStore.markRead(
        BookingMessageReadStore.latestMessageKey(orders),
      );
      setState(() {
        _orders = orders;
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        title: Text('预约消息',
            style: TextStyle(
                color: AppTheme.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textDark),
        actions: [
          IconButton(
            tooltip: '返回首页',
            onPressed: () => context.go(AppRouter.home),
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _isLoading ? null : _loadOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryPink,
        onRefresh: _loadOrders,
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primaryPink)),
              )
            else if (_errorMessage.isNotEmpty)
              _buildEmptyState('消息加载失败', _errorMessage)
            else if (_orders.isEmpty)
              _buildEmptyState('暂无预约消息', '提交预约申请后，商家的处理结果会显示在这里')
            else
              ..._orders.map(_buildMessageCard),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(BookingOrder order) {
    final color = switch (order.status) {
      'accepted' => Colors.green,
      'rejected' => Colors.redAccent,
      _ => Colors.orange,
    };
    final icon = switch (order.status) {
      'accepted' => Icons.check_circle,
      'rejected' => Icons.cancel,
      _ => Icons.hourglass_top,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.statusLabel,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 8),
                Text(order.userMessage,
                    style: TextStyle(color: AppTheme.textDark, height: 1.35)),
                const SizedBox(height: 10),
                _buildInfoRow(
                  Icons.content_cut,
                  '${order.serviceName} · ${order.staffName}',
                ),
                const SizedBox(height: 4),
                _buildInfoRow(Icons.storefront, order.salonName),
                const SizedBox(height: 4),
                _buildInfoRow(
                    Icons.schedule, _dateFormat.format(order.startTime)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 45),
      child: Column(
        children: [
          Icon(Icons.notifications_none, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
