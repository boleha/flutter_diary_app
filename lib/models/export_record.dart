/// 导出/备份/恢复操作记录
class ExportRecord {
  final String id;
  final DateTime time;
  final String type; // zip_full / zip_data / webdav_full / webdav_data / webdav_restore / import
  final String location; // 文件路径或远端文件名
  final int size; // 字节，0 表示未知
  final bool success;
  final String? detail;

  const ExportRecord({
    required this.id,
    required this.time,
    required this.type,
    required this.location,
    this.size = 0,
    this.success = true,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'type': type,
        'location': location,
        'size': size,
        'success': success,
        'detail': detail,
      };

  factory ExportRecord.fromJson(Map<String, dynamic> json) {
    return ExportRecord(
      id: json['id'] as String? ?? '',
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      type: json['type'] as String? ?? '',
      location: json['location'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      success: json['success'] as bool? ?? true,
      detail: json['detail'] as String?,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'zip_full':
        return '导出 ZIP（含图片）';
      case 'zip_data':
        return '导出 ZIP（仅数据）';
      case 'webdav_full':
        return '备份到 WebDAV（含图片）';
      case 'webdav_data':
        return '备份到 WebDAV（仅数据）';
      case 'webdav_restore':
        return '从 WebDAV 恢复';
      case 'import':
        return '导入 ZIP';
      default:
        return type;
    }
  }

  String get sizeLabel {
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
