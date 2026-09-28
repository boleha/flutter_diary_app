import 'package:flutter/foundation.dart' show compute;

import 'storage_service.dart' show exportZipIsolate;

/// Web 平台不支持后台 isolate 打包，直接同步执行（无进度回调）。
Future<String?> runExportWithProgress(
  List<Object> args, {
  void Function(int done, int total)? onProgress,
}) {
  return compute(exportZipIsolate, args);
}
