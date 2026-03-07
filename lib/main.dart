import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'screens/quick_add/quick_add_bottom_sheet.dart';

final navigatorKey = GlobalKey<NavigatorState>();
const _widgetChannel =
    MethodChannel('com.fredysomy.money_management/widget');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      child: MoneyManagerApp(navigatorKey: navigatorKey),
    ),
  );

  // Set up widget method channel after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    _widgetChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAction' && call.arguments == 'quick_add') {
        _triggerQuickAdd();
      }
    });

    // Check if app was launched from the widget
    try {
      final action =
          await _widgetChannel.invokeMethod<String>('getInitialAction');
      if (action == 'quick_add') {
        await Future.delayed(const Duration(milliseconds: 400));
        _triggerQuickAdd();
      }
    } catch (_) {}
  });
}

void _triggerQuickAdd() {
  final ctx = navigatorKey.currentContext;
  if (ctx != null) showQuickAdd(ctx, closeAppOnSave: true);
}
