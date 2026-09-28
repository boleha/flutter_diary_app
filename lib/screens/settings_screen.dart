import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/export_record.dart';
import '../services/theme_service.dart' show ThemeService;
import '../services/storage_service.dart';
import '../services/webdav_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/app_top_toast.dart';
import '../widgets/settings_action_group_card.dart';
import '../widgets/settings_storage_mode_section.dart';
import '../widgets/settings_theme_mode_dialog.dart' show ThemeModeUi;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ThemeService _themeService = ThemeService();
  final StorageService _storageService = StorageService();
  final WebdavService _webdavService = WebdavService();
  final TextEditingController _webdavUrlController = TextEditingController();
  final TextEditingController _webdavUsernameController =
      TextEditingController();
  final TextEditingController _webdavPasswordController =
      TextEditingController();
  bool _obscureWebdavPassword = true;
  bool _webdavConfigured = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _loadWebdavConfig();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _webdavUrlController.dispose();
    _webdavUsernameController.dispose();
    _webdavPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadWebdavConfig() async {
    final isConfigured = await _webdavService.isConfigured();
    final url = await _webdavService.getUrl();
    final username = await _webdavService.getUsername();
    final password = await _webdavService.getPassword();
    if (mounted) {
      setState(() {
        _webdavConfigured = isConfigured;
        _webdavUrlController.text = url ?? '';
        _webdavUsernameController.text = username ?? '';
        _webdavPasswordController.text = password ?? '';
      });
    }
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> _addExportRecord({
    required String type,
    required String location,
    int size = 0,
    bool success = true,
    String? detail,
  }) async {
    await _storageService.addExportRecord(
      ExportRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        time: DateTime.now(),
        type: type,
        location: location,
        size: size,
        success: success,
        detail: detail,
      ),
    );
  }

  // 导出前询问密码（可留空 = 不加密），返回 null 表示取消
  Future<String?> _promptExportPassword() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('设置导出密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('可选。设置后 ZIP 将被 AES-256 加密，导入时需要输入密码。'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码（留空则不加密）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('导出'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return password;
  }

  // 导入 ZIP，支持加密文件：自动检测 → 输入密码 → 错误重试
  Future<bool> _importZipWithPassword(String zipPath) async {
    String? password;
    while (true) {
      try {
        return await _storageService.importDataFromZip(
          zipPath,
          password: password,
        );
      } on EncryptedZipException catch (e) {
        final controller = TextEditingController();
        password = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(e.wrongPassword ? '密码错误' : '文件已加密'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.wrongPassword ? '输入的密码不正确，请重新输入。' : '该 ZIP 文件已加密，请输入密码。',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (password == null) return false; // 用户取消
      }
    }
  }

  // 导出数据（包含图片的 ZIP 文件）
  Future<void> _exportData() async {
    try {
      final password = await _promptExportPassword();
      if (password == null || !mounted) return;

      var progressDone = 0;
      var progressTotal = 0;

      // 显示进度对话框（打包完成后由下方关闭）
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final value = progressTotal > 0
                ? progressDone / progressTotal
                : null;
            return AlertDialog(
              title: const Text('正在导出'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: value),
                  const SizedBox(height: 12),
                  Text(
                    progressTotal > 0
                        ? '正在打包图片 $progressDone/$progressTotal ...'
                        : '正在准备数据...',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final zipPath = await _storageService.exportDataWithImages(
        password: password,
        onProgress: (done, total) {
          progressDone = done;
          progressTotal = total;
        },
      );

      if (mounted) {
        Navigator.pop(context); // 关闭进度对话框
      }

      if (zipPath != null) {
        // 保存到系统"下载"目录（用户可直接在文件管理器找到）
        final fileName = zipPath.split('/').last.split('\\').last;
        final savedLocation = await _storageService.saveZipToDownloads(
          zipPath,
          fileName: fileName,
        );

        // 分享文件
        await Share.shareXFiles([XFile(zipPath)], subject: '日记备份');

        final size = await File(zipPath).length();
        final details = <String>[
          if (password.isNotEmpty) '已加密',
          if (savedLocation != null) '已保存到 $savedLocation',
        ];
        await _addExportRecord(
          type: 'zip_full',
          location: savedLocation ?? zipPath,
          size: size,
          detail: details.isEmpty ? null : details.join('，'),
        );

        if (mounted) {
          AppTopToast.show(
            context,
            savedLocation != null
                ? '导出成功，已保存到 $savedLocation'
                : '导出成功，请通过分享选择保存位置',
          );
        }
      } else {
        await _addExportRecord(
          type: 'zip_full',
          location: '本地导出失败',
          success: false,
        );
        if (mounted) {
          AppTopToast.show(context, '导出失败', isError: true);
        }
      }
    } catch (e) {
      await _addExportRecord(
        type: 'zip_full',
        location: '本地导出异常',
        success: false,
        detail: '$e',
      );
      if (mounted) {
        AppTopToast.show(context, '导出失败: $e', isError: true);
      }
    }
  }

  // 导入数据（ZIP 文件，包含图片）
  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (!mounted) return;

      if (result != null && result.files.single.path != null) {
        // 确认导入
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认导入'),
            content: const Text(
              '导入数据会合并到现有日记中，相同 ID 的日记会被覆盖。图片会被解压到应用目录。是否继续？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('导入'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          if (mounted) {
            AppTopToast.show(context, '正在导入数据，请稍候...');
          }

          final success = await _importZipWithPassword(
            result.files.single.path!,
          );

          await _addExportRecord(
            type: 'import',
            location: result.files.single.path!,
            success: success,
            detail: success ? null : '导入失败',
          );

          if (mounted) {
            AppTopToast.show(
              context,
              success ? '数据导入成功' : '数据导入失败',
              isError: !success,
            );

            // 如果导入成功，返回 true 通知主页刷新
            if (success) {
              Navigator.pop(context, true);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppTopToast.show(context, '导入失败: $e', isError: true);
      }
    }
  }

  // WebDAV 相关方法
  Future<void> _saveWebdavConfig() async {
    final url = _webdavUrlController.text.trim();
    final username = _webdavUsernameController.text.trim();
    final password = _webdavPasswordController.text.trim();

    if (url.isEmpty || username.isEmpty || password.isEmpty) {
      if (mounted) {
        AppTopToast.show(context, '请填写完整的 WebDAV 配置', isError: true);
      }
      return;
    }

    await _webdavService.saveConfig(
      url: url,
      username: username,
      password: password,
    );

    if (mounted) {
      setState(() {
        _webdavConfigured = true;
      });
      AppTopToast.show(context, 'WebDAV 配置已保存');
    }
  }

  Future<void> _testWebdavConnection() async {
    final url = _webdavUrlController.text.trim();
    final username = _webdavUsernameController.text.trim();
    final password = _webdavPasswordController.text.trim();

    if (url.isEmpty || username.isEmpty || password.isEmpty) {
      if (mounted) {
        AppTopToast.show(context, '请先填写完整的 WebDAV 配置', isError: true);
      }
      return;
    }

    if (!mounted) return;
    AppTopToast.show(context, '正在测试连接...');

    try {
      // 使用临时配置测试连接
      final success = await _webdavService.testConnectionWithConfig(
        url: url,
        username: username,
        password: password,
      );
      if (mounted) {
        AppTopToast.show(context, success ? '连接成功' : '连接失败');
      }
    } catch (e) {
      if (mounted) {
        AppTopToast.show(context, '连接失败: $e', isError: true);
      }
    }
  }

  Future<void> _backupToWebdav({bool includeImages = true}) async {
    if (!_webdavConfigured) {
      if (mounted) {
        AppTopToast.show(context, '请先配置 WebDAV', isError: true);
      }
      return;
    }

    if (!mounted) return;

    try {
      // 询问密码（可选）
      final password = await _promptExportPassword();
      if (password == null || !mounted) return;

      // 显示进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildProgressDialog(
          includeImages ? '正在准备完整备份（含图片）...' : '正在准备数据备份...',
        ),
      );

      // 导出数据（可选是否含图片）
      final zipPath = includeImages
          ? await _storageService.exportDataWithImages(password: password)
          : await _storageService.exportDataOnly(password: password);

      if (zipPath == null) {
        await _addExportRecord(
          type: includeImages ? 'webdav_full' : 'webdav_data',
          location: '备份数据准备失败',
          success: false,
        );
        if (mounted) {
          Navigator.pop(context);
          AppTopToast.show(context, '备份数据准备失败', isError: true);
        }
        return;
      }

      if (!mounted) return;

      // 更新进度
      Navigator.pop(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildProgressDialog('正在上传到 WebDAV...'),
      );

      // 上传到 WebDAV
      await _webdavService.backupToWebdav(zipFilePath: zipPath);

      final size = await File(zipPath).length();
      await _addExportRecord(
        type: includeImages ? 'webdav_full' : 'webdav_data',
        location: zipPath,
        size: size,
        detail: password.isEmpty ? null : '已加密',
      );

      if (mounted) {
        Navigator.pop(context);
        AppTopToast.show(context, includeImages ? '完整备份成功' : '数据备份成功');
      }
    } catch (e) {
      await _addExportRecord(
        type: includeImages ? 'webdav_full' : 'webdav_data',
        location: 'WebDAV 备份异常',
        success: false,
        detail: '$e',
      );
      if (mounted) {
        Navigator.pop(context);
        AppTopToast.show(context, '备份失败: $e', isError: true);
      }
    }
  }

  Future<void> _restoreFromWebdav() async {
    if (!_webdavConfigured) {
      if (mounted) {
        AppTopToast.show(context, '请先配置 WebDAV', isError: true);
      }
      return;
    }

    if (!mounted) return;

    try {
      // 获取备份列表
      AppTopToast.show(context, '正在获取备份列表...');
      final backups = await _webdavService.listBackups();

      if (!mounted) return;

      if (backups.isEmpty) {
        AppTopToast.show(context, '云端没有找到备份文件', isError: true);
        return;
      }

      // 显示备份选择对话框
      final selectedBackup = await _showBackupSelectionDialog(backups);
      if (!mounted) return;
      if (selectedBackup == null) return; // 用户取消

      // 确认恢复
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认恢复'),
          content: Text(
            '将从云端恢复备份"${selectedBackup['name']}"到本地，相同 ID 的日记会被覆盖。是否继续？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('恢复'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      if (!mounted) return;

      // 显示进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildProgressDialog('正在下载备份文件...'),
      );

      // 从 WebDAV 下载指定备份
      final zipPath = await _webdavService.restoreFromWebdav(
        remoteFileName: selectedBackup['name'] as String,
      );

      if (!mounted) return;

      // 更新进度 - 安全关闭对话框
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // 关闭下载进度
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildProgressDialog('正在导入数据...'),
      );

      // 导入数据
      final success = await _importZipWithPassword(zipPath);

      await _addExportRecord(
        type: 'webdav_restore',
        location: selectedBackup['name'] as String,
        size: await File(zipPath).length(),
        success: success,
        detail: success ? null : '云端恢复失败',
      );

      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context); // 关闭导入进度
        }
        AppTopToast.show(context, success ? '恢复成功' : '恢复失败', isError: !success);
        if (success && Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      await _addExportRecord(
        type: 'webdav_restore',
        location: 'WebDAV 恢复异常',
        success: false,
        detail: '$e',
      );
      if (mounted) {
        // 确保关闭任何打开的对话框
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        AppTopToast.show(context, '恢复失败: $e', isError: true);
      }
    }
  }

  Future<void> _showExportRecords() async {
    final records = await _storageService.getExportRecords();

    if (!mounted) return;

    if (records.isEmpty) {
      AppTopToast.show(context, '暂无导出记录', isError: true);
      return;
    }

    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('导出记录'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final timeStr = record.time
                  .toLocal()
                  .toString()
                  .split('.')
                  .first
                  .replaceFirst('T', ' ');
              return ListTile(
                dense: true,
                leading: Icon(
                  record.success ? Icons.check_circle : Icons.error,
                  color: record.success ? colors.success : colors.danger,
                ),
                title: Text(
                  '${record.typeLabel}${record.success ? '' : '（失败）'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(timeStr, style: const TextStyle(fontSize: 12)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.location,
                            style: const TextStyle(fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: record.location),
                            );
                            AppTopToast.show(context, '路径已复制');
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.copy,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (record.detail != null)
                      Text(
                        record.detail!,
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                  ],
                ),
                trailing: record.sizeLabel.isEmpty
                    ? null
                    : Text(
                        record.sizeLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showBackupSelectionDialog(
    List<Map<String, dynamic>> backups,
  ) async {
    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择要恢复的备份'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: backups.length,
            itemBuilder: (context, index) {
              final backup = backups[index];
              final name = backup['name'] as String;
              final size = backup['size'] as int;
              final time = backup['modified'] as DateTime;
              final type = backup['type'] as String;

              // 格式化大小
              String sizeStr;
              if (size < 1024) {
                sizeStr = '$size B';
              } else if (size < 1024 * 1024) {
                sizeStr = '${(size / 1024).toStringAsFixed(1)} KB';
              } else {
                sizeStr = '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
              }

              return ListTile(
                leading: Icon(
                  type == '完整' ? Icons.backup : Icons.description,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(name),
                subtitle: Text(
                  '$type · $sizeStr · ${time.toString().split('.').first}',
                ),
                onTap: () => Navigator.pop(context, backup),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDialog(String message) {
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  void _showWebdavConfigDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('WebDAV 配置'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _webdavUrlController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'https://example.com/dav/',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppUi.itemGap),
                  TextField(
                    controller: _webdavUsernameController,
                    decoration: const InputDecoration(labelText: '用户名'),
                  ),
                  const SizedBox(height: AppUi.itemGap),
                  TextField(
                    controller: _webdavPasswordController,
                    decoration: InputDecoration(
                      labelText: '密码',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureWebdavPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureWebdavPassword = !_obscureWebdavPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureWebdavPassword,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _testWebdavConnection,
                      icon: const Icon(Icons.wifi, size: 18),
                      label: const Text('测试连接'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                _saveWebdavConfig();
                Navigator.pop(dialogContext);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = _themeService.themeMode;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: AppUi.headerPadding,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    tooltip: '返回',
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '设置',
                    style: GoogleFonts.righteous(
                      fontSize: 28,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: AppUi.pagePadding,
                children: [
                  // 主题模式
                  NeumorphicSurface(
                    child: ListTile(
                      title: const Text('主题模式'),
                      trailing: Icon(
                        ThemeModeUi.icon(themeMode),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () => _themeService.cycleThemeMode(),
                    ),
                  ),
                  const SizedBox(height: AppUi.sectionGap),

                  // 图片存储模式设置
                  SettingsStorageModeSection(
                    selectedMode: _themeService.imageStorageMode,
                    onModeSelected: (mode) async {
                      await _themeService.setImageStorageMode(mode);
                      if (!mounted) return;
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: AppUi.sectionGap),

                  // 数据导入导出
                  SettingsActionGroupCard(
                    items: [
                      SettingsActionItem(
                        icon: Icons.download,
                        title: '导出数据',
                        subtitle: 'ZIP 文件（含图片）',
                        onTap: _exportData,
                      ),
                      SettingsActionItem(
                        icon: Icons.upload,
                        title: '导入数据',
                        subtitle: '从 ZIP 文件恢复',
                        onTap: _importData,
                      ),
                      SettingsActionItem(
                        icon: Icons.history,
                        title: '导出记录',
                        subtitle: '查看历史导出/备份',
                        onTap: _showExportRecords,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // WebDAV 云备份
                  SettingsActionGroupCard(
                    items: [
                      SettingsActionItem(
                        icon: Icons.cloud,
                        title: 'WebDAV 配置',
                        subtitle: _webdavConfigured ? '已配置' : '未配置',
                        onTap: _showWebdavConfigDialog,
                      ),
                      SettingsActionItem(
                        icon: Icons.backup,
                        title: '备份到 WebDAV',
                        subtitle: '日记 + 图片',
                        onTap: () => _backupToWebdav(includeImages: true),
                      ),
                      SettingsActionItem(
                        icon: Icons.description,
                        title: '仅数据备份',
                        subtitle: '不含图片，更快',
                        onTap: () => _backupToWebdav(includeImages: false),
                      ),
                      SettingsActionItem(
                        icon: Icons.restore,
                        title: '从 WebDAV 恢复',
                        onTap: _restoreFromWebdav,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppUi.sectionGap),

                  // 备份说明
                  NeumorphicSurface(
                    child: Padding(
                      padding: AppUi.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '备份说明',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• ZIP：本地备份。点「导出数据」生成文件（含图片），可分享到电脑/网盘保存；点「导入数据」选择该文件即可恢复。',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppUi.mutedText(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• WebDAV：云端备份。配置网盘（如坚果云）后一键上传/恢复，换机不丢数据。',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppUi.mutedText(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '建议：WebDAV 定期备份，ZIP 导出留档。',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppUi.mutedText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
