import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/notification_service.dart';
import 'screens/quick_add/quick_add_bottom_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const ProviderScope(child: MoneyManagerApp()));
}

/// Entry point used by QuickAddActivity (widget tap).
/// Runs a transparent Flutter surface that immediately shows the quick-add sheet.
@pragma('vm:entry-point')
void quickAddMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const _QuickAddLauncher(),
      ),
    ),
  );
}

class _QuickAddLauncher extends StatefulWidget {
  const _QuickAddLauncher();
  @override
  State<_QuickAddLauncher> createState() => _QuickAddLauncherState();
}

class _QuickAddLauncherState extends State<_QuickAddLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await showQuickAdd(context, closeAppOnSave: true);
      // Sheet was dismissed without saving — close the activity
      if (mounted) SystemNavigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
    );
  }
}
