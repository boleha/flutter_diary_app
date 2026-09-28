import 'package:flutter/material.dart';

import '../services/theme_service.dart' show ImageStorageMode;
import 'app_ui.dart';

class SettingsStorageModeSection extends StatelessWidget {
  final ImageStorageMode selectedMode;
  final ValueChanged<ImageStorageMode> onModeSelected;

  const SettingsStorageModeSection({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isCopy = selectedMode == ImageStorageMode.copy;
    return NeumorphicSurface(
      child: SwitchListTile(
        title: const Text('图片复制到应用'),
        subtitle: Text(isCopy ? '已开启：图片随日记完整备份' : '已关闭：仅保存图片路径，更省空间'),
        value: isCopy,
        onChanged: (value) {
          onModeSelected(value ? ImageStorageMode.copy : ImageStorageMode.reference);
        },
      ),
    );
  }
}
