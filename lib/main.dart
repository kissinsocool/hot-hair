import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/network/router.dart';
import 'features/auth/data/user_auth_repository.dart';
import 'features/auth/data/user_session_store.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/booking/data/booking_message_read_store.dart';
import 'features/salon_discovery/data/favorite_salon_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 160 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 220;
  await UserSessionStore.restore();
  await BookingMessageReadStore.restore();
  if (UserSessionStore.currentSession != null) {
    await FavoriteSalonStore.load();
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ClientAuthSession? _session = UserSessionStore.currentSession;

  Widget _buildAppShell(BuildContext context, Widget? child) {
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(1).clamp(1.0, 1.08).toDouble();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MediaQuery(
        data: media.copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _handleAuthenticated(ClientAuthSession session) async {
    await UserSessionStore.save(session);
    await FavoriteSalonStore.load();
    if (!mounted) return;
    setState(() => _session = session);
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return MaterialApp(
        title: '麻辣烫',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: _buildAppShell,
        home: AuthScreen(onAuthenticated: _handleAuthenticated),
      );
    }

    return MaterialApp.router(
      title: '麻辣烫',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: _buildAppShell,
      // 使用 GoRouter 的配置
      routerConfig: AppRouter.router,
    );
  }
}
