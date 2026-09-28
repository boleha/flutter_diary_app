import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class MotionPhoto {
  final int videoOffset;
  final int videoLength;

  const MotionPhoto(this.videoOffset, this.videoLength);
}

/// Reads the video appended to an Android JPEG Motion Photo without changing
/// the original image. Other image formats remain ordinary photos.
class MotionPhotoService {
  const MotionPhotoService._();

  static Future<MotionPhoto?> inspect(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final length = await file.length();
    if (length < 12) return null;
    final reader = await file.open();
    try {
      final header = await reader.read(min(length, 256 * 1024));
      if (header.length < 2 || header[0] != 0xff || header[1] != 0xd8) {
        return null;
      }
      final metadata = String.fromCharCodes(header);
      final hasMotionFlag = RegExp(
        r'(?:Camera|GCamera):(?:MotionPhoto|MicroVideo)="1"',
      ).hasMatch(metadata);
      if (!hasMotionFlag) return null;

      int? videoLength;
      for (final item in RegExp(
        r'<[^>]*Item:Semantic="MotionPhoto"[^>]*>',
      ).allMatches(metadata)) {
        videoLength = int.tryParse(
          RegExp(r'Item:Length="(\d+)"').firstMatch(item.group(0)!)?.group(1) ??
              '',
        );
        if (videoLength != null) break;
      }
      videoLength ??= int.tryParse(
        RegExp(
              r'(?:Camera|GCamera):MicroVideoOffset="(\d+)"',
            ).firstMatch(metadata)?.group(1) ??
            '',
      );
      if (videoLength == null || videoLength < 12 || videoLength >= length) {
        return null;
      }

      final offset = length - videoLength;
      await reader.setPosition(offset + 4);
      final marker = await reader.read(4);
      if (marker.length != 4 || String.fromCharCodes(marker) != 'ftyp') {
        return null;
      }
      return MotionPhoto(offset, videoLength);
    } finally {
      await reader.close();
    }
  }

  static Future<String> extractVideo(
    String imagePath,
    MotionPhoto motionPhoto,
  ) async {
    final image = File(imagePath);
    final modified = (await image.lastModified()).millisecondsSinceEpoch;
    final cache = await getTemporaryDirectory();
    final name = path
        .basenameWithoutExtension(imagePath)
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final video = File(
      path.join(
        cache.path,
        'motion_${name}_${modified}_${motionPhoto.videoLength}.mp4',
      ),
    );
    if (await video.exists() &&
        await video.length() == motionPhoto.videoLength) {
      return video.path;
    }

    final source = await image.open();
    final target = await video.open(mode: FileMode.write);
    try {
      await source.setPosition(motionPhoto.videoOffset);
      var remaining = motionPhoto.videoLength;
      while (remaining > 0) {
        final bytes = await source.read(min(remaining, 64 * 1024));
        if (bytes.isEmpty) throw const FileSystemException('动态照片视频数据不完整');
        await target.writeFrom(bytes);
        remaining -= bytes.length;
      }
    } finally {
      await source.close();
      await target.close();
    }
    return video.path;
  }
}
