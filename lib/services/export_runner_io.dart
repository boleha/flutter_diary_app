import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

/// 打包核心逻辑：惰性读图 + 流式写盘，返回 ZIP 路径，失败返回 null。
Future<String?> packZip(
  List<String> imagePaths,
  String dataJson,
  String zipPath,
  String? password,
) async {
  try {
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
    developer.log('打包 ZIP 失败: $e', name: 'StorageService');
    return null;
  }
}

/// isolate 入口：args 末尾携带 SendPort，逐张图片处理后上报进度。
void _isolateMain(List<Object> args) async {
  final sendPort = args.removeLast() as SendPort;
  try {
    final imagePaths = (args[0] as List).cast<String>();
    final dataJson = args[1] as String;
    final zipPath = args[2] as String;
    final password = args.length > 3 ? args[3] as String? : null;

    sendPort.send({'type': 'total', 'total': imagePaths.length});

    final effectivePassword = (password == null || password.isEmpty) ? null : password;
    final archive = Archive();
    final jsonBytes = utf8.encode(dataJson);
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    int done = 0;
    for (final imagePath in imagePaths) {
      final file = File(imagePath);
      if (await file.exists()) {
        final size = await file.length();
        final fileName = imagePath.split('/').last.split('\\').last;
        archive.addFile(
          ArchiveFile('images/$fileName', size, InputFileStream(imagePath)),
        );
      }
      done++;
      sendPort.send({'type': 'progress', 'done': done});
    }

    final encoder = ZipEncoder(password: effectivePassword);
    final output = OutputFileStream(zipPath);
    encoder.encode(archive, output: output);
    await output.close();

    sendPort.send({'type': 'done', 'path': zipPath});
  } catch (e) {
    developer.log('后台导出 ZIP 失败: $e', name: 'StorageService');
    sendPort.send({'type': 'error', 'message': '$e'});
  }
}

/// 在后台 isolate 执行打包并上报进度，返回 ZIP 路径，失败返回 null。
Future<String?> runExportWithProgress(
  List<Object> args, {
  void Function(int done, int total)? onProgress,
}) async {
  final receivePort = ReceivePort();
  final completer = Completer<String?>();
  var total = 0;

  receivePort.listen((message) {
    final m = message as Map;
    switch (m['type']) {
      case 'total':
        total = m['total'] as int;
      case 'progress':
        onProgress?.call(m['done'] as int, total);
      case 'done':
        if (!completer.isCompleted) completer.complete(m['path'] as String?);
      case 'error':
        if (!completer.isCompleted) completer.complete(null);
    }
  });

  final fullArgs = List<Object>.from(args)..add(receivePort.sendPort);
  final errorPort = ReceivePort();
  errorPort.listen((error) {
    developer.log('导出 isolate 异常: $error', name: 'StorageService');
    if (!completer.isCompleted) completer.complete(null);
  });
  await Isolate.spawn(
    _isolateMain,
    fullArgs,
    onError: errorPort.sendPort,
  );

  final result = await completer.future.timeout(
    const Duration(minutes: 30),
    onTimeout: () {
      receivePort.close();
      return null;
    },
  );
  receivePort.close();
  return result;
}
