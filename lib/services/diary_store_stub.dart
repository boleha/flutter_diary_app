import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 与 StorageService._diaryKey 保持一致
const String _diaryKey = 'diary_entries';

/// Web 平台后端：继续使用 SharedPreferences（原逻辑）。
class DiaryStore {
  Future<bool> hasData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_diaryKey);
    return jsonString != null && jsonString.isNotEmpty;
  }

  Future<void> replaceAll(List<String> jsonList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_diaryKey, jsonEncode(jsonList));
  }

  Future<List<String>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_diaryKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => jsonEncode(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> upsert(String jsonStr) async {
    final list = await readAll();
    final existing = list.indexWhere((s) {
      try {
        final data = jsonDecode(s) as Map<String, dynamic>;
        final newData = jsonDecode(jsonStr) as Map<String, dynamic>;
        return data['id'] == newData['id'];
      } catch (_) {
        return false;
      }
    });
    if (existing >= 0) {
      list[existing] = jsonStr;
    } else {
      list.add(jsonStr);
    }
    await replaceAll(list);
  }

  Future<void> deleteById(String id) async {
    final list = await readAll();
    list.removeWhere((s) {
      try {
        final data = jsonDecode(s) as Map<String, dynamic>;
        return data['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await replaceAll(list);
  }

  Future<void> deleteBefore(DateTime before) async {
    final list = await readAll();
    final beforeStr = before.toIso8601String();
    list.removeWhere((s) {
      try {
        final data = jsonDecode(s) as Map<String, dynamic>;
        final deletedAt = data['deletedAt'] as String?;
        return deletedAt != null && deletedAt.compareTo(beforeStr) < 0;
      } catch (_) {
        return false;
      }
    });
    await replaceAll(list);
  }
}
