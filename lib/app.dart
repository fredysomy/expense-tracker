import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_screen.dart';

class MoneyManagerApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const MoneyManagerApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Manager',
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
