import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/network/router.dart';
import 'features/auth/data/user_auth_repository.dart';
import 'features/auth/data/user_session_store.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/salon_discovery/data/favorite_salon_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserSessionStore.restore();
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
        title: 'Hot Pepper Clone',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: AuthScreen(onAuthenticated: _handleAuthenticated),
      );
    }

    return MaterialApp.router(
      title: 'Hot Pepper Clone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // 使用 GoRouter 的配置
      routerConfig: AppRouter.router,
    );
  }
}
