import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'screens/quick_add/quick_add_bottom_sheet.dart';

@pragma('vm:entry-point')
void quickAddMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _QuickAddApp()));
}

class _QuickAddApp extends StatelessWidget {
  const _QuickAddApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const _QuickAddRoot(),
    );
  }
}

class _QuickAddRoot extends StatefulWidget {
  const _QuickAddRoot();
  @override
  State<_QuickAddRoot> createState() => _QuickAddRootState();
}

class _QuickAddRootState extends State<_QuickAddRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await showQuickAdd(context);
      // Close the transparent activity once the sheet is dismissed
      SystemNavigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}
