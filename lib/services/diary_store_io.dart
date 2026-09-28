import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// SQLite 持久化后端（io 平台）：每篇日记一行，data 列为 JSON 字符串。
class DiaryStore {
  static const String _table = 'diary_entries';
  static const String _colId = 'id';
  static const String _colData = 'data';
  static const String _colDeletedAt = 'deleted_at';
  static const String _colDate = 'date';
  static const String _colFavorite = 'is_favorite';

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dbPath = path.join(await getDatabasesPath(), 'diary.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            $_colId TEXT PRIMARY KEY,
            $_colData TEXT NOT NULL,
            $_colDeletedAt TEXT,
            $_colDate TEXT,
            $_colFavorite INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_entries_date ON $_table ($_colDate)',
        );
        await db.execute(
          'CREATE INDEX idx_entries_deleted ON $_table ($_colDeletedAt)',
        );
        await db.execute(
          'CREATE INDEX idx_entries_favorite ON $_table ($_colFavorite)',
        );
      },
    );
    return _db!;
  }

  /// 是否有数据（用于判断是否需要从旧存储迁移）
  Future<bool> hasData() async {
    final db = await _open();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table',
    );
    final count = result.first['c'] as int? ?? 0;
    return count > 0;
  }

  /// 全量替换（事务内 delete + insert），与旧 SharedPreferences 语义一致
  Future<void> replaceAll(List<String> jsonList) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete(_table);
      final batch = txn.batch();
      for (final jsonStr in jsonList) {
        final values = _rowValues(jsonStr);
        if (values == null) continue;
        batch.insert(
          _table,
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// 单条写入（INSERT OR REPLACE），增量操作
  Future<void> upsert(String jsonStr) async {
    final db = await _open();
    final values = _rowValues(jsonStr);
    if (values == null) return;
    await db.insert(
      _table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 按 id 删除单条
  Future<void> deleteById(String id) async {
    final db = await _open();
    await db.delete(_table, where: '$_colId = ?', whereArgs: [id]);
  }

  /// 删除指定时间之前的软删除日记
  Future<void> deleteBefore(DateTime before) async {
    final db = await _open();
    await db.delete(
      _table,
      where: '$_colDeletedAt IS NOT NULL AND $_colDeletedAt < ?',
      whereArgs: [before.toIso8601String()],
    );
  }

  Map<String, dynamic>? _rowValues(String jsonStr) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final id = data['id'] as String? ?? '';
    if (id.isEmpty) return null;
    final deletedAt = data['deletedAt'] as String?;
    final dateStr = data['date'] as String?;
    final isFavorite = data['isFavorite'] == true ? 1 : 0;
    return {
      _colId: id,
      _colData: jsonStr,
      _colDeletedAt: deletedAt,
      _colDate: dateStr,
      _colFavorite: isFavorite,
    };
  }

  /// 读取全部日记 JSON 字符串（按 date 倒序）
  Future<List<String>> readAll() async {
    final db = await _open();
    final rows = await db.query(
      _table,
      columns: [_colData],
      orderBy: '$_colDate DESC',
    );
    return rows.map((row) => row[_colData] as String).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
