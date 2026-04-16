import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sms_transaction.dart';
import 'sms_parser.dart';

class SmsService {
  static const _channel = MethodChannel('com.fredysomy.money_management/sms');

  /// Returns true if READ_SMS permission is granted (or just granted).
  static Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<bool> get hasPermission async =>
      (await Permission.sms.status).isGranted;

  /// Fetches SMS from the inbox for the past [daysBack] days, parses them,
  /// and returns only those that look like financial transactions.
  ///
  /// Throws [SmsPermissionException] if permission is not granted.
  static Future<List<SmsTransaction>> getTodayTransactions({
    int daysBack = 1,
  }) async {
    final granted = await hasPermission;
    if (!granted) throw SmsPermissionException();

    final List<dynamic> raw;
    try {
      raw = await _channel.invokeMethod<List>(
            'getTodaySms',
            {'daysBack': daysBack},
          ) ??
          [];
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') throw SmsPermissionException();
      rethrow;
    }

    final results = <SmsTransaction>[];
    for (final item in raw) {
      final map = Map<String, dynamic>.from(item as Map);
      final body = (map['body'] as String?) ?? '';
      final sender = (map['address'] as String?) ?? '';
      final dateMs = (map['date'] as int?) ?? 0;
      final smsId = (map['id'] as String?) ?? '';

      final txn = SmsParser.parse(
        smsId: smsId,
        body: body,
        sender: sender,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(dateMs),
      );
      if (txn != null) results.add(txn);
    }
    return results;
  }
}

class SmsPermissionException implements Exception {
  @override
  String toString() => 'READ_SMS permission not granted';
}
