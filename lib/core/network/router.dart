import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/salon_discovery/presentation/salon_detail_screen.dart';
import '../../features/salon_discovery/presentation/salon_home_screen.dart';
import '../../features/booking/presentation/booking_screen.dart';
import '../../features/booking/presentation/staff_detail_screen.dart';
import '../../features/booking/presentation/confirm_booking_screen.dart';
import '../../features/salon_discovery/presentation/service_detail_screen.dart';
import '../../features/booking/presentation/user_booking_messages_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String detail = '/detail';
  static const String serviceDetail = '/service'; // 新增
  static const String booking = '/booking';
  static const String staffDetail = '/staff';
  static const String confirm = '/confirm';
  static const String userMessages = '/booking-messages';

  static final GoRouter router = GoRouter(
    initialLocation: home,
    routes: [
      GoRoute(
        name: 'salon_detail',
        path: '$detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return SalonDetailScreen(salonId: id);
        },
      ),
      GoRoute(
        name: 'staff_detail', // 新增理发师详情路由名称
        path: '$staffDetail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return StaffDetailScreen(staffId: id);
        },
      ),
      GoRoute(path: home, builder: (context, state) => const SalonHomeScreen()),
      GoRoute(
        path: serviceDetail,
        builder: (context, state) {
          final name = state.uri.queryParameters['name'] ?? '';
          final price = state.uri.queryParameters['price'] ?? '';
          final duration = state.uri.queryParameters['duration'] ?? '';
          final imageUrl = state.uri.queryParameters['img'] ?? '';
          return ServiceDetailScreen(
            name: name,
            price: price,
            duration: duration,
            imageUrl: imageUrl,
          );
        },
      ),
      GoRoute(
          path: booking, builder: (context, state) => const BookingScreen()),
      GoRoute(
          path: confirm,
          builder: (context, state) => const ConfirmBookingScreen()),
      GoRoute(
          path: userMessages,
          builder: (context, state) => const UserBookingMessagesScreen()),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('页面不存在')),
    ),
  );
}
