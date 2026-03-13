import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';

class ExportImportService {
  static final _db = DatabaseHelper();

  // ── Export ──────────────────────────────────────────────────────────────

  /// Builds the JSON payload, saves it to external app storage AND shares it.
  /// Returns the saved file path so the caller can show it to the user.
  static Future<String> exportAndShare() async {
    final db = await _db.database;

    final accounts = await db.query('accounts');
    final categories = await db.query('categories');
    final transactions = await db.query('transactions');
    final rawBudgets = await db.query('budgets');

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
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'money_manager_backup_$ts.json';

    // Save to external app storage — always visible in Files app under
    // Android > data > com.fredysomy.money_management > files
    final extDir = await getExternalStorageDirectory();
    final saveDir = extDir ?? await getApplicationDocumentsDirectory();
    final file = File('${saveDir.path}/$fileName');
    await file.writeAsString(json, encoding: utf8);

    // Also share so user can send it anywhere
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: fileName)],
      subject: 'Money Manager Backup',
    );

    return file.path;
  }

  // ── Import ──────────────────────────────────────────────────────────────

  static Future<ImportPreview?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;

    // Decode content — withData:true fills bytes; fallback to path
    String content;
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString(encoding: utf8);
    } else {
      throw Exception('Could not read the selected file.');
    }

    // Quick sanity check — must start with { to be JSON
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('{')) {
      throw Exception(
          'The selected file is not a valid JSON backup.\n'
          'Make sure you pick the .json file exported by this app.\n'
          'Avoid opening the file in Google Drive first — '
          'use the Files app instead.');
    }

    return _parse(content);
  }

  static ImportPreview _parse(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;

    // Use Map.from() instead of cast<> — JSON decodes to Map<String, Object?>
    List<Map<String, dynamic>> listOf(String key) =>
        ((data[key] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    return ImportPreview(
      accounts: listOf('accounts'),
      categories: listOf('categories'),
      transactions: listOf('transactions'),
      budgets: listOf('budgets'),
      exportedAt: data['exported_at'] as String?,
    );
  }

  static Future<void> applyImport(ImportPreview preview) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      await txn.delete('budget_accounts');
      await txn.delete('budget_categories');
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('accounts');
      await txn.delete('categories');

      // Parents before children to satisfy parent_id FK
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
        // IDs may be parsed as dynamic — convert to String safely
        final catIds = (row.remove('category_ids') as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final accIds = (row.remove('account_ids') as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

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
