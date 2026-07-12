import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/home_screen.dart';
import 'screens/thread_screen.dart';
import 'sms_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SmsStore.instance.init();
  runApp(const ClearSmsApp());
}

final navigatorKey = GlobalKey<NavigatorState>();

class ClearSmsApp extends StatefulWidget {
  const ClearSmsApp({super.key});

  @override
  State<ClearSmsApp> createState() => _ClearSmsAppState();
}

class _ClearSmsAppState extends State<ClearSmsApp> {
  @override
  void initState() {
    super.initState();
    SmsStore.instance.addListener(_maybeOpenThread);
  }

  @override
  void dispose() {
    SmsStore.instance.removeListener(_maybeOpenThread);
    super.dispose();
  }

  // Notification taps land here: open the requested thread.
  void _maybeOpenThread() {
    final store = SmsStore.instance;
    final threadId = store.pendingOpenThreadId;
    if (threadId == null) return;
    Conversation? conv;
    for (final c in store.conversations) {
      if (c.threadId == threadId) {
        conv = c;
        break;
      }
    }
    if (conv == null) return;
    store.pendingOpenThreadId = null;
    final target = conv;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState
        ?..popUntil((r) => r.isFirst)
        ..push(MaterialPageRoute(
          builder: (_) => ThreadScreen(conversation: target),
        ));
    });
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3D5AFE),
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0E0F13) : const Color(0xFFF6F6FA),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? const Color(0xFF0E0F13) : const Color(0xFFF6F6FA),
        surfaceTintColor: Colors.transparent,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClearSMS',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}

/// Shared visual language for the four categories.
class CategoryStyle {
  final String label;
  final IconData icon;
  final Color color;
  const CategoryStyle(this.label, this.icon, this.color);
}

CategoryStyle categoryStyle(SmsCategory c) => switch (c) {
      SmsCategory.personal =>
        const CategoryStyle('Personal', Icons.person_rounded, Color(0xFF3D5AFE)),
      SmsCategory.otp =>
        const CategoryStyle('OTP', Icons.key_rounded, Color(0xFF00A67E)),
      SmsCategory.transaction => const CategoryStyle(
          'Transactions', Icons.account_balance_rounded, Color(0xFFB45309)),
      SmsCategory.promotion => const CategoryStyle(
          'Promotions', Icons.campaign_rounded, Color(0xFF9333EA)),
    };
