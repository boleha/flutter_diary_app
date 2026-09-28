import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import '../models/export_record.dart';
import '../models/favorite_item.dart';
import 'diary_store_stub.dart'
    if (dart.library.io) 'diary_store_io.dart' as diary_store;
import 'export_runner_stub.dart'
    if (dart.library.io) 'export_runner_io.dart' as export_runner;
import 'motion_photo_service.dart';

/// 加密 ZIP 需要密码
class EncryptedZipException implements Exception {
  final bool wrongPassword;
  EncryptedZipException({this.wrongPassword = false});
}

/// 后台 isolate 压缩图片：最长边 1920、JPEG 质量 85，失败返回 null。
Future<Uint8List?> _compressImageToBytes(String sourcePath) async {
  try {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    const int maxSide = 1920;
    var resized = decoded;
    if (decoded.width > maxSide || decoded.height > maxSide) {
      if (decoded.width >= decoded.height) {
        resized = img.copyResize(decoded, width: maxSide);
      } else {
        resized = img.copyResize(decoded, height: maxSide);
      }
    }

    if (decoded.hasAlpha) {
      // 透明背景转白底（JPEG 不支持 alpha）
      final canvas = img.Image(
        width: resized.width,
        height: resized.height,
        numChannels: 3,
      );
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(canvas, resized);
      return img.encodeJpg(canvas, quality: 85);
    }
    return img.encodeJpg(resized, quality: 85);
  } catch (e) {
    developer.log('压缩图片失败: $e', name: 'StorageService');
    return null;
  }
}

/// 打包 ZIP（Web 端直接执行，io 端供 compute/isolate 使用）。
/// 图片以 InputFileStream 惰性分块读取，输出以 OutputFileStream 流式写盘。
/// 传入 password 时使用 AES-256 加密。
Future<String?> exportZipIsolate(List<Object> args) async {
  try {
    final imagePaths = (args[0] as List).cast<String>();
    final dataJson = args[1] as String;
    final zipPath = args[2] as String;
    final password = args.length > 3 ? args[3] as String? : null;
    final effectivePassword = (password == null || password.isEmpty) ? null : password;

    final archive = Archive();
    final jsonBytes = utf8.encode(dataJson);
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    for (final imagePath in imagePaths) {
      final file = File(imagePath);
      if (await file.exists()) {
        final size = await file.length();
        final fileName = imagePath.split('/').last.split('\\').last;
        archive.addFile(
          ArchiveFile('images/$fileName', size, InputFileStream(imagePath)),
        );
      }
    }

    final encoder = ZipEncoder(password: effectivePassword);
    final output = OutputFileStream(zipPath);
    encoder.encode(archive, output: output);
    await output.close();

    return zipPath;
  } catch (e) {
    developer.log('后台导出 ZIP 失败: $e', name: 'StorageService');
    return null;
  }
}

class StorageService {
  static const String _diaryKey = 'diary_entries';
  /// 日记存储键（供 Web 后端复用）
  static const String diaryStorePrefsKey = _diaryKey;
  static const String _initializedKey = 'diary_initialized';
  static const String _favoritesKey = 'favorite_items';
  static const String _dataClearedKey = 'data_cleared'; // 标记数据是否被手动清除
  static const String _exportRecordsKey = 'export_records';
  static const int _maxExportRecords = 30;
  static const MethodChannel _downloadsChannel =
      MethodChannel('com.example.diary_app/downloads');

  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final diary_store.DiaryStore _store = diary_store.DiaryStore();
  bool _migrationChecked = false;

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();
  List<DiaryEntry>? _entriesCache;
  List<DiaryEntry>? _activeEntriesCache;
  List<DiaryEntry>? _deletedEntriesCache;
  List<DiaryEntry>? _favoriteEntriesCache;
  Map<String, DiaryEntry>? _entriesByIdCache;
  Map<int, DiaryEntry>? _entriesByDayCache;
  Map<String, List<DiaryEntry>>? _entriesByMonthCache;

  void _rebuildIndexes(List<DiaryEntry> entries) {
    _entriesCache = List<DiaryEntry>.from(entries);
    _entriesByIdCache = <String, DiaryEntry>{};
    _entriesByDayCache = <int, DiaryEntry>{};
    _entriesByMonthCache = <String, List<DiaryEntry>>{};
    _activeEntriesCache = [];
    _deletedEntriesCache = [];
    _favoriteEntriesCache = [];

    for (final entry in entries) {
      _entriesByIdCache![entry.id] = entry;

      if (entry.deletedAt != null) {
        _deletedEntriesCache!.add(entry);
        continue;
      }

      _activeEntriesCache!.add(entry);
      if (entry.isFavorite) {
        _favoriteEntriesCache!.add(entry);
      }

      _entriesByDayCache![_dayKey(entry.date)] = entry;
      final monthKey = _monthKey(entry.date);
      _entriesByMonthCache!.putIfAbsent(monthKey, () => <DiaryEntry>[]).add(entry);
    }
  }

  /// 首次使用时将旧 SharedPreferences 数据迁移到 SQLite（io 平台）
  Future<void> _ensureMigrated() async {
    if (_migrationChecked) return;
    _migrationChecked = true;
    if (kIsWeb) return; // Web 后端就是 SharedPreferences，无需迁移

    final prefs = await _prefs;
    final oldJson = prefs.getString(_diaryKey);
    if (oldJson == null || oldJson.isEmpty) return;
    if (await _store.hasData()) return; // SQLite 已有数据

    try {
      final List<dynamic> jsonList = jsonDecode(oldJson);
      await _store.replaceAll(
        jsonList.map((j) => jsonEncode(j)).toList(),
      );
      developer.log('✅ 日记数据已迁移到 SQLite', name: 'StorageService');
    } catch (e) {
      developer.log('迁移日记数据失败: $e', name: 'StorageService');
    }
  }

  Future<void> _saveAllEntries(List<DiaryEntry> entries, {SharedPreferences? prefs}) async {
    entries.sort((a, b) => b.date.compareTo(a.date));
    final jsonList = entries.map((e) => jsonEncode(e.toJson())).toList();
    await _ensureMigrated();
    await _store.replaceAll(jsonList);
    _rebuildIndexes(entries);
  }

  // 获取所有未删除的日记（正常列表）
  Future<List<DiaryEntry>> getAllEntries() async {
    if (_activeEntriesCache != null) {
      return List<DiaryEntry>.from(_activeEntriesCache!);
    }
    await _getAllEntriesIncludingDeleted();
    return List<DiaryEntry>.from(_activeEntriesCache ?? const <DiaryEntry>[]);
  }

  // 获取所有日记（包括已删除的，用于回收站）
  Future<List<DiaryEntry>> _getAllEntriesIncludingDeleted() async {
    if (_entriesCache != null) {
      return List<DiaryEntry>.from(_entriesCache!);
    }

    await _ensureMigrated();
    final jsonStrings = await _store.readAll();

    final parsed = <DiaryEntry>[];
    for (final jsonStr in jsonStrings) {
      try {
        parsed.add(
          DiaryEntry.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>),
        );
      } catch (e) {
        developer.log('解析日记失败: $e', name: 'StorageService');
      }
    }
    _rebuildIndexes(parsed);
    return parsed;
  }

  // 获取回收站中的日记
  Future<List<DiaryEntry>> getDeletedEntries() async {
    if (_deletedEntriesCache != null) {
      return List<DiaryEntry>.from(_deletedEntriesCache!);
    }
    await _getAllEntriesIncludingDeleted();
    return List<DiaryEntry>.from(_deletedEntriesCache ?? const <DiaryEntry>[]);
  }

  Future<void> saveEntry(DiaryEntry entry) async {
    await _ensureMigrated();
    final entries = _entriesCache ?? await _getAllEntriesIncludingDeleted();
    
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }

    await _store.upsert(jsonEncode(entry.toJson()));
    _rebuildIndexes(entries);
  }

  // 软删除日记
  Future<void> deleteEntry(String id) async {
    final entries = _entriesCache ?? await _getAllEntriesIncludingDeleted();

    final index = entries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final updated = entries[index].copyWith(deletedAt: DateTime.now());
      entries[index] = updated;
      await _store.upsert(jsonEncode(updated.toJson()));
      _rebuildIndexes(entries);
    }
  }

  // 恢复日记
  Future<void> restoreEntry(String id) async {
    final entries = _entriesCache ?? await _getAllEntriesIncludingDeleted();

    final index = entries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final updated = entries[index].copyWith(deletedAt: null);
      entries[index] = updated;
      await _store.upsert(jsonEncode(updated.toJson()));
      _rebuildIndexes(entries);
    }
  }

  // 永久删除日记
  Future<void> permanentlyDeleteEntry(String id) async {
    final entries = _entriesCache ?? await _getAllEntriesIncludingDeleted();

    entries.removeWhere((e) => e.id == id);
    await _store.deleteById(id);
    _rebuildIndexes(entries);
  }

  // 批量永久删除日记（用于清空回收站）
  Future<void> permanentlyDeleteEntries(List<String> ids) async {
    final entries = _entriesCache ?? await _getAllEntriesIncludingDeleted();
    final idSet = ids.toSet();

    entries.removeWhere((e) => idSet.contains(e.id));
    for (final id in ids) {
      await _store.deleteById(id);
    }
    _rebuildIndexes(entries);
  }

  // 清理超过30天的已删除日记
  Future<void> cleanupOldDeletedEntries() async {
    final entries = _entriesCache ?? await _getAllEntriesIncludingDeleted();
    final now = DateTime.now();

    entries.removeWhere((e) {
      if (e.deletedAt == null) return false;
      final daysSinceDeleted = now.difference(e.deletedAt!).inDays;
      return daysSinceDeleted >= 30;
    });
    await _store.deleteBefore(now.subtract(const Duration(days: 30)));
    _rebuildIndexes(entries);
  }

  Future<DiaryEntry?> getEntryByDate(DateTime date) async {
    if (_entriesByDayCache == null) {
      await _getAllEntriesIncludingDeleted();
    }
    return _entriesByDayCache?[_dayKey(date)];
  }

  Future<List<DiaryEntry>> getEntriesByMonth(DateTime month) async {
    if (_entriesByMonthCache == null) {
      await _getAllEntriesIncludingDeleted();
    }
    return List<DiaryEntry>.from(
      _entriesByMonthCache?[_monthKey(month)] ?? const <DiaryEntry>[],
    );
  }

  int _dayKey(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month}';
  }

  // ========== 收藏夹功能 ==========

  Future<List<FavoriteItem>> getAllFavorites() async {
    final prefs = await _prefs;
    final String? jsonString = prefs.getString(_favoritesKey);

    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => FavoriteItem.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveFavorite(FavoriteItem item) async {
    final prefs = await _prefs;
    final items = await getAllFavorites();

    final index = items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      items[index] = item;
    } else {
      items.add(item);
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final jsonList = items.map((i) => i.toJson()).toList();
    await prefs.setString(_favoritesKey, jsonEncode(jsonList));
  }

  Future<void> deleteFavorite(String id) async {
    final prefs = await _prefs;
    final items = await getAllFavorites();

    items.removeWhere((i) => i.id == id);

    final jsonList = items.map((i) => i.toJson()).toList();
    await prefs.setString(_favoritesKey, jsonEncode(jsonList));
  }

  Future<List<FavoriteItem>> getFavoritesByType(String type) async {
    final items = await getAllFavorites();
    return items.where((i) => i.type == type).toList();
  }

  Future<List<FavoriteItem>> searchFavorites(String keyword) async {
    final items = await getAllFavorites();
    final lowerKeyword = keyword.toLowerCase();
    return items.where((i) {
      final contentMatch = i.content?.toLowerCase().contains(lowerKeyword) ?? false;
      final sourceMatch = i.source?.toLowerCase().contains(lowerKeyword) ?? false;
      final tagMatch = i.tags.any((tag) => tag.toLowerCase().contains(lowerKeyword));
      return contentMatch || sourceMatch || tagMatch;
    }).toList();
  }

  // ========== 日记收藏功能 ==========

  Future<void> toggleFavorite(String entryId) async {
    final entries = _entriesCache ?? await _getAllEntriesIncludingDeleted();
    
    final index = entries.indexWhere((e) => e.id == entryId);
    if (index >= 0) {
      final updated = entries[index].copyWith(
        isFavorite: !entries[index].isFavorite,
      );
      entries[index] = updated;
      await _store.upsert(jsonEncode(updated.toJson()));
      _rebuildIndexes(entries);
    }
  }

  Future<List<DiaryEntry>> getFavoriteEntries() async {
    if (_favoriteEntriesCache != null) {
      return List<DiaryEntry>.from(_favoriteEntriesCache!);
    }
    await _getAllEntriesIncludingDeleted();
    return List<DiaryEntry>.from(_favoriteEntriesCache ?? const <DiaryEntry>[]);
  }

  Future<void> clearAllData() async {
    final prefs = await _prefs;
    await prefs.remove(_diaryKey);
    await prefs.remove(_favoritesKey);
    await prefs.remove(_initializedKey);
    // 设置数据已清除标记，防止自动重新初始化测试数据
    await prefs.setBool(_dataClearedKey, true);
    await _store.replaceAll(const <String>[]);
    _rebuildIndexes(const <DiaryEntry>[]);
    
    // 清除应用目录下的图片文件夹
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      
      // 删除 images 文件夹
      final Directory imagesDir = Directory('${appDir.path}/images');
      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
      }
      
      // 删除 imported_images 文件夹
      final Directory importedImagesDir = Directory('${appDir.path}/imported_images');
      if (await importedImagesDir.exists()) {
        await importedImagesDir.delete(recursive: true);
      }
    } catch (e) {
      developer.log('清除图片文件夹失败: $e', name: 'StorageService');
    }
  }

  // 复制图片到应用目录
  Future<String?> copyImageToAppDirectory(String sourcePath) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagesDir = '${appDir.path}/images';
      
      // 创建 images 目录（如果不存在）
      final Directory dir = Directory(imagesDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // 生成唯一文件名
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${sourcePath.split('/').last.split('\\').last}';
      final String destPath = '$imagesDir/$fileName';
      
      // 复制文件（后台压缩，最长边 1920、质量 85）
      final File sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        if (await MotionPhotoService.inspect(sourcePath) != null) {
          // JPEG 尾部包含视频，重新编码会丢失动态片段。
          await sourceFile.copy(destPath);
        } else {
          final compressed = await compute(_compressImageToBytes, sourcePath);
          if (compressed != null) {
            await File(destPath).writeAsBytes(compressed);
          } else {
            await sourceFile.copy(destPath);
          }
        }
        return destPath;
      }
      return null;
    } catch (e) {
      developer.log('复制图片失败: $e', name: 'StorageService');
      return null;
    }
  }

  // 导出日记数据（不含图片）
  Future<String?> exportDataOnly({
    String? password,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      final entries = await _getAllEntriesIncludingDeleted();
      
      // 创建数据 JSON（不包含图片列表）
      final data = {
        'version': '1.0',
        'exportTime': DateTime.now().toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'images': <String>[], // 空图片列表
      };
      
      // 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final fileName = 'diary_data_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipPath = '${tempDir.path}/$fileName';

      // 后台 isolate 打包（io 端带进度），避免卡 UI
      final result = await export_runner.runExportWithProgress(
        <Object>[<String>[], jsonEncode(data), zipPath, password ?? ''],
        onProgress: onProgress,
      );

      if (result != null) {
        developer.log('✅ 数据导出成功（不含图片）', name: 'StorageService');
      }
      return result;
    } catch (e) {
      developer.log('导出数据失败: $e', name: 'StorageService');
      return null;
    }
  }

  // 导出所有日记数据为 ZIP（包含图片）
  Future<String?> exportDataWithImages({
    String? password,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      final entries = await _getAllEntriesIncludingDeleted();
      
      // 收集所有图片路径
      final List<String> allImages = [];
      for (var entry in entries) {
        allImages.addAll(entry.images);
      }
      final uniqueImages = allImages.toSet().toList();
      
      // 创建数据 JSON
      final data = {
        'version': '1.0',
        'exportTime': DateTime.now().toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'images': uniqueImages,
      };
      
      // 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final fileName = 'diary_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipPath = '${tempDir.path}/$fileName';

      // 后台 isolate 打包（惰性读图 + 流式写盘，带进度），避免卡死和内存峰值
      final result = await export_runner.runExportWithProgress(
        <Object>[uniqueImages, jsonEncode(data), zipPath, password ?? ''],
        onProgress: onProgress,
      );

      if (result != null) {
        developer.log('✅ 数据导出成功（含图片）', name: 'StorageService');
      }
      return result;
    } catch (e) {
      developer.log('导出数据失败: $e', name: 'StorageService');
      return null;
    }
  }

  // 读取首个文件内容，触发 AES 惰性解密以验证密码是否正确
  void _verifyZipDecryptable(Archive archive) {
    for (final file in archive) {
      if (file.name.isNotEmpty && !file.name.endsWith('/')) {
        file.content;
        return;
      }
    }
  }

  // 导入 ZIP 文件（包含数据和图片）
  Future<bool> importDataFromZip(String zipPath, {String? password}) async {
    try {
      developer.log('开始导入 ZIP: $zipPath', name: 'StorageService');
      
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        developer.log('ZIP 文件不存在', name: 'StorageService');
        return false;
      }
      
      final bytes = await zipFile.readAsBytes();
      developer.log('ZIP 文件大小: ${bytes.length} bytes', name: 'StorageService');

      // 解码并验证（archive 的 AES 解密是惰性的，需访问 content 才触发密码校验）
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
        _verifyZipDecryptable(archive);
      } catch (_) {
        // 无密码失败 → 加密文件
        if (password == null || password.isEmpty) {
          throw EncryptedZipException();
        }
        try {
          archive = ZipDecoder().decodeBytes(bytes, password: password);
          _verifyZipDecryptable(archive);
        } catch (_) {
          throw EncryptedZipException(wrongPassword: true);
        }
      }
      developer.log('ZIP 包含 ${archive.length} 个文件', name: 'StorageService');
      
      // 找到数据文件
      ArchiveFile? dataFile;
      final List<ArchiveFile> imageFiles = [];
      
      for (var file in archive) {
        developer.log('ZIP 中的文件: ${file.name}', name: 'StorageService');
        if (file.name == 'data.json') {
          dataFile = file;
        } else if (file.name.startsWith('images/')) {
          imageFiles.add(file);
        }
      }
      
      if (dataFile == null) {
        developer.log('未找到 data.json 文件', name: 'StorageService');
        return false;
      }
      
      developer.log('找到 ${imageFiles.length} 张图片', name: 'StorageService');
      
      // 解析数据
      final jsonString = utf8.decode(dataFile.content);
      final data = jsonDecode(jsonString);
      
      // 获取应用目录
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/imported_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      // 解压图片
      final Map<String, String> pathMapping = {}; // 旧路径 -> 新路径
      for (var imageFile in imageFiles) {
        final fileName = imageFile.name.split('/').last;
        final newPath = '${imagesDir.path}/$fileName';
        final file = File(newPath);
        await file.writeAsBytes(imageFile.content);
        pathMapping[fileName] = newPath;
      }
      
      // 更新日记中的图片路径
      final List<dynamic> entriesJson = data['entries'];
      for (var entryJson in entriesJson) {
        final List<dynamic> oldImages = entryJson['images'] ?? [];
        final List<String> newImages = [];
        for (var oldPath in oldImages) {
          final fileName = oldPath.split('/').last.split('\\').last;
          if (pathMapping.containsKey(fileName)) {
            newImages.add(pathMapping[fileName]!);
          } else {
            // 如果图片不在 ZIP 中，保留原路径（可能是引用模式）
            newImages.add(oldPath);
          }
        }
        entryJson['images'] = newImages;
      }
      
      // 导入数据
      return await importData(data);
    } catch (e) {
      developer.log('导入 ZIP 失败: $e', name: 'StorageService');
      return false;
    }
  }

  // ========== 导出/备份记录 ==========

  /// 将文件保存到系统"下载"目录（Android 10+ 用 MediaStore，无需权限），
  /// 返回用户可理解的路径（如 "下载/xxx.zip"），失败返回 null。
  Future<String?> saveZipToDownloads(
    String sourcePath, {
    required String fileName,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      return await _downloadsChannel.invokeMethod<String>(
        'saveZipToDownloads',
        {'path': sourcePath, 'fileName': fileName},
      );
    } catch (e) {
      developer.log('保存到下载目录失败: $e', name: 'StorageService');
      return null;
    }
  }

  Future<List<ExportRecord>> getExportRecords() async {
    final prefs = await _prefs;
    final String? jsonString = prefs.getString(_exportRecordsKey);
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => ExportRecord.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addExportRecord(ExportRecord record) async {
    final prefs = await _prefs;
    final records = await getExportRecords();
    records.insert(0, record);
    if (records.length > _maxExportRecords) {
      records.removeRange(_maxExportRecords, records.length);
    }
    final jsonList = records.map((r) => r.toJson()).toList();
    await prefs.setString(_exportRecordsKey, jsonEncode(jsonList));
  }

  // 导入日记数据
  Future<bool> importData(Map<String, dynamic> data) async {
    try {
      final prefs = await _prefs;
      
      // 验证数据格式
      if (!data.containsKey('entries')) {
        developer.log('导入失败：数据格式不正确，缺少 entries 字段', name: 'StorageService');
        return false;
      }
      
      final List<dynamic> entriesJson = data['entries'];
      developer.log('正在导入 ${entriesJson.length} 条日记', name: 'StorageService');
      
      final List<DiaryEntry> newEntries = entriesJson
          .map((json) => DiaryEntry.fromJson(json))
          .toList();
      
      // 获取现有数据
      final existingEntries = await _getAllEntriesIncludingDeleted();
      
      // 合并数据（根据 ID 去重，新数据覆盖旧数据）
      final Map<String, DiaryEntry> entryMap = {};
      for (var entry in existingEntries) {
        entryMap[entry.id] = entry;
      }
      for (var entry in newEntries) {
        entryMap[entry.id] = entry;
      }

      // 保存合并后的数据
      await _saveAllEntries(entryMap.values.toList(), prefs: prefs);
      
      // 清除数据已清除标记，因为现在有数据了
      await prefs.remove(_dataClearedKey);
      
      developer.log('导入成功，共 ${entryMap.length} 条日记', name: 'StorageService');
      return true;
    } catch (e) {
      developer.log('导入数据失败: $e', name: 'StorageService');
      return false;
    }
  }
}
