import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';

class ExportImportService {
  static final _db = DatabaseHelper();

  // ── Export ──────────────────────────────────────────────────────────────

  static Future<void> exportAndShare() async {
    final db = await _db.database;

    final accounts = await db.query('accounts');
    final categories = await db.query('categories');
    final transactions = await db.query('transactions');
    final rawBudgets = await db.query('budgets');

    // Embed junction table rows into each budget
    final budgets = await Future.wait(rawBudgets.map((b) async {
      final cats = await db.query('budget_categories',
          where: 'budget_id = ?', whereArgs: [b['id']]);
      final accs = await db.query('budget_accounts',
          where: 'budget_id = ?', whereArgs: [b['id']]);
      return {
        ...b,
        'category_ids': cats.map((c) => c['category_id']).toList(),
        'account_ids': accs.map((a) => a['account_id']).toList(),
      };
    }));

    final payload = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accounts,
      'categories': categories,
      'transactions': transactions,
      'budgets': budgets,
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/money_manager_backup_$ts.json');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Money Manager Backup',
    );
  }

  // ── Import ──────────────────────────────────────────────────────────────

  /// Opens file picker and parses the selected JSON file.
  /// Returns null if the user cancelled or the file is invalid.
  static Future<ImportPreview?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true, // always read bytes directly — avoids path permission issues
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;

    String content;
    if (file.bytes != null) {
      content = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      return null;
    }

    return _parse(content);
  }

  static ImportPreview _parse(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;

    List<Map<String, dynamic>> listOf(String key) =>
        ((data[key] as List?) ?? []).cast<Map<String, dynamic>>();

    return ImportPreview(
      accounts: listOf('accounts'),
      categories: listOf('categories'),
      transactions: listOf('transactions'),
      budgets: listOf('budgets'),
      exportedAt: data['exported_at'] as String?,
    );
  }

  /// Wipes all existing data and inserts everything from [preview].
  static Future<void> applyImport(ImportPreview preview) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      // Clear in reverse FK order
      await txn.delete('budget_accounts');
      await txn.delete('budget_categories');
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('accounts');
      await txn.delete('categories');

      // Categories: parents first, then children
      final parents =
          preview.categories.where((c) => c['parent_id'] == null).toList();
      final children =
          preview.categories.where((c) => c['parent_id'] != null).toList();
      for (final c in [...parents, ...children]) {
        await txn.insert('categories', _clean(c));
      }

      for (final a in preview.accounts) {
        await txn.insert('accounts', _clean(a));
      }

      for (final t in preview.transactions) {
        await txn.insert('transactions', _clean(t));
      }

      for (final b in preview.budgets) {
        final row = Map<String, dynamic>.from(b);
        final catIds =
            (row.remove('category_ids') as List?)?.cast<String>() ?? [];
        final accIds =
            (row.remove('account_ids') as List?)?.cast<String>() ?? [];

        await txn.insert('budgets', row);

        for (final id in catIds) {
          await txn.insert('budget_categories',
              {'budget_id': b['id'], 'category_id': id});
        }
        for (final id in accIds) {
          await txn.insert('budget_accounts',
              {'budget_id': b['id'], 'account_id': id});
        }
      }
    });
  }

  /// Remove any extra keys (like category_ids/account_ids) not in the schema.
  static Map<String, dynamic> _clean(Map<String, dynamic> row) {
    final copy = Map<String, dynamic>.from(row);
    copy.remove('category_ids');
    copy.remove('account_ids');
    return copy;
  }
}

class ImportPreview {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> budgets;
  final String? exportedAt;

  const ImportPreview({
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.budgets,
    this.exportedAt,
  });
}
