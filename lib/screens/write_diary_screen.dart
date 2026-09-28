import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/diary_entry.dart';
import '../models/write_diary_form_snapshot.dart';
import '../services/storage_service.dart';
import '../services/motion_photo_service.dart';
import '../services/theme_service.dart' show ThemeService, ImageStorageMode;
import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/app_top_toast.dart';
import '../widgets/write_diary_content_editor.dart';
import '../widgets/write_diary_shell_sections.dart';
import '../widgets/write_diary_top_extras.dart';

class WriteDiaryScreen extends StatefulWidget {
  final DateTime selectedDate;
  final DiaryEntry? existingEntry;

  const WriteDiaryScreen({
    super.key,
    required this.selectedDate,
    this.existingEntry,
  });

  @override
  State<WriteDiaryScreen> createState() => _WriteDiaryScreenState();
}

class _WriteDiaryScreenState extends State<WriteDiaryScreen> {
  final StorageService _storageService = StorageService();
  final ThemeService _themeService = ThemeService();
  late final _contentController = _TimeHighlightController();
  final _breakfastController = TextEditingController();
  final _lunchController = TextEditingController();
  final _dinnerController = TextEditingController();
  final _snacksController = TextEditingController();
  final _moodController = TextEditingController();
  final _weatherController = TextEditingController();
  final _weightController = TextEditingController();
  final _contentFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  final _contentFieldKey = GlobalKey();
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<String>> _imagesNotifier =
      ValueNotifier<List<String>>(const []);
  late final Widget _topExtrasChild;
  late WriteDiaryFormSnapshot _initialSnapshot;
  String? _timestampTextCache;
  bool _isContentFocused = false;

  @override
  void initState() {
    super.initState();
    _isContentFocused = _contentFocusNode.hasFocus;
    _contentFocusNode.addListener(_handleContentFocusChange);
    if (widget.existingEntry != null) {
      _contentController.text = widget.existingEntry!.content;
      _breakfastController.text = widget.existingEntry!.breakfast ?? '';
      _lunchController.text = widget.existingEntry!.lunch ?? '';
      _dinnerController.text = widget.existingEntry!.dinner ?? '';
      _snacksController.text = widget.existingEntry!.snacks ?? '';
      _moodController.text = widget.existingEntry!.mood ?? '';
      _weatherController.text = widget.existingEntry!.weather ?? '';
      _weightController.text = widget.existingEntry!.weight ?? '';
      _setImages(widget.existingEntry!.images);
      _initialSnapshot = WriteDiaryFormSnapshot.fromEntry(
        widget.existingEntry!,
      );
      _timestampTextCache =
          '创建于 ${DateFormat('yyyy/MM/dd HH:mm:ss').format(widget.existingEntry!.createdAt)}  修改于 ${DateFormat('yyyy/MM/dd HH:mm:ss').format(widget.existingEntry!.updatedAt)}';
    } else {
      _setImages(const []);
      _initialSnapshot = WriteDiaryFormSnapshot.empty();
    }
    _topExtrasChild = RepaintBoundary(
      child: WriteDiaryTopExtras(
        imagesListenable: _imagesNotifier,
        onPickImages: _pickImages,
        onFieldTap: _handleNonContentFieldTap,
        onReorderImages: _reorderImages,
        onDeleteImageAt: _deleteImageAt,
        breakfastController: _breakfastController,
        lunchController: _lunchController,
        dinnerController: _dinnerController,
        moodController: _moodController,
        weatherController: _weatherController,
        weightController: _weightController,
      ),
    );
  }

  @override
  void dispose() {
    _contentFocusNode.removeListener(_handleContentFocusChange);
    _contentController.dispose();
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    _snacksController.dispose();
    _moodController.dispose();
    _weatherController.dispose();
    _weightController.dispose();
    _contentFocusNode.dispose();
    _isLoadingNotifier.dispose();
    _imagesNotifier.dispose();
    _onChangeDebounceTimer?.cancel();
    super.dispose();
  }

  List<String> get _images => _imagesNotifier.value;

  void _setImages(List<String> images) {
    _imagesNotifier.value = List<String>.unmodifiable(images);
  }

  void _updateImages(void Function(List<String> images) updater) {
    final nextImages = List<String>.from(_imagesNotifier.value);
    updater(nextImages);
    _imagesNotifier.value = List<String>.unmodifiable(nextImages);
  }

  void _handleContentFocusChange() {
    if (!mounted) return;
    final focused = _contentFocusNode.hasFocus;
    if (focused != _isContentFocused) {
      setState(() {
        _isContentFocused = focused;
      });
    }
  }

  void _handleNonContentFieldTap() {
    if (_contentFocusNode.hasFocus) {
      _contentFocusNode.unfocus();
    }
    if (_isContentFocused && mounted) {
      setState(() {
        _isContentFocused = false;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        // Android 动态照片的视频附在原始 JPEG 后，选择时不能重新编码。
        imageQuality: defaultTargetPlatform == TargetPlatform.android
            ? 100
            : 85,
      );

      if (images.isNotEmpty) {
        final storageMode = _themeService.imageStorageMode;

        for (var image in images) {
          if (!_images.contains(image.path)) {
            final isMotionPhoto =
                defaultTargetPlatform == TargetPlatform.android &&
                await MotionPhotoService.inspect(image.path) != null;
            if (storageMode == ImageStorageMode.copy || isMotionPhoto) {
              // 复制到应用文件夹
              final copiedPath = await _storageService.copyImageToAppDirectory(
                image.path,
              );
              if (copiedPath != null) {
                _updateImages((nextImages) {
                  if (!nextImages.contains(copiedPath)) {
                    nextImages.add(copiedPath);
                  }
                });
              } else {
                if (mounted) {
                  _showSnackBar('复制图片失败: ${image.path}');
                }
              }
            } else {
              // 仅保存引用
              _updateImages((nextImages) {
                if (!nextImages.contains(image.path)) {
                  nextImages.add(image.path);
                }
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('选择图片失败: $e');
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    AppTopToast.show(context, message, isError: isError);
  }

  void _deleteImageAt(int index) {
    _updateImages((nextImages) {
      if (index >= 0 && index < nextImages.length) {
        nextImages.removeAt(index);
      }
    });
  }

  void _reorderImages(int oldIndex, int newIndex) {
    _updateImages((nextImages) {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = nextImages.removeAt(oldIndex);
      nextImages.insert(newIndex, item);
    });
  }

  Widget _buildAppBar() {
    return WriteDiaryHeader(
      selectedDate: widget.selectedDate,
      isLoadingListenable: _isLoadingNotifier,
      onSave: _saveDiary,
    );
  }

  bool _hasChanges() {
    final current = _buildCurrentSnapshot();
    if (widget.existingEntry == null) {
      return current.hasAnyMeaningfulInput();
    }
    return !current.isSameAs(_initialSnapshot);
  }

  WriteDiaryFormSnapshot _buildCurrentSnapshot() {
    return WriteDiaryFormSnapshot(
      content: _contentController.text,
      breakfast: _breakfastController.text,
      lunch: _lunchController.text,
      dinner: _dinnerController.text,
      snacks: _snacksController.text,
      mood: _moodController.text,
      weather: _weatherController.text,
      weight: _weightController.text,
      images: List<String>.unmodifiable(_images),
    );
  }

  Future<void> _handleBack() async {
    if (!_hasChanges()) {
      Navigator.pop(context);
      return;
    }

    final confirm = await _showDiscardChangesDialog();
    if (confirm == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool?> _showDiscardChangesDialog() {
    final colors = AppColors.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的修改'),
        content: const Text('你有未保存的修改，确定要离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('离开', style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDiary() async {
    if (!_formKey.currentState!.validate()) return;

    _isLoadingNotifier.value = true;

    try {
      final now = DateTime.now();
      final entry = _buildEntryForSave(now);

      await _storageService.saveEntry(entry);

      if (mounted) {
        _showSnackBar('日记保存成功');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('保存失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        _isLoadingNotifier.value = false;
      }
    }
  }

  DiaryEntry _buildEntryForSave(DateTime now) {
    final content = _contentController.text.trim();
    return DiaryEntry(
      id:
          widget.existingEntry?.id ??
          '${now.millisecondsSinceEpoch}_${now.microsecondsSinceEpoch % 1000}',
      date: widget.selectedDate,
      title: _buildAutoTitle(content),
      content: content,
      breakfast: _normalizedOrNull(_breakfastController.text),
      lunch: _normalizedOrNull(_lunchController.text),
      dinner: _normalizedOrNull(_dinnerController.text),
      snacks: _normalizedOrNull(_snacksController.text),
      mood: _normalizedOrNull(_moodController.text),
      weather: _normalizedOrNull(_weatherController.text),
      weight: _normalizedOrNull(_weightController.text),
      images: List<String>.from(_images),
      createdAt: widget.existingEntry?.createdAt ?? now,
      updatedAt: now,
      isFavorite: widget.existingEntry?.isFavorite ?? false,
    );
  }

  String _buildAutoTitle(String content) {
    if (content.isEmpty) {
      return '${widget.selectedDate.month}月${widget.selectedDate.day}日的日记';
    }
    return content.length > 10 ? content.substring(0, 10) : content;
  }

  String? _normalizedOrNull(String raw) {
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  String? _lastValue;
  // 用于节流 onChanged 的定时器
  Timer? _onChangeDebounceTimer;

  void _handleContentEditorTap() {
    if (_contentController.text.isEmpty) {
      Future.microtask(() {
        final now = DateTime.now();
        final timeStr =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        _contentController.text = '$timeStr ';
        _lastValue = _contentController.text;
        _contentController.selection = TextSelection.fromPosition(
          TextPosition(offset: _contentController.text.length),
        );
      });
    }
  }

  void _handleContentChanged(String value) {
    _onChangeDebounceTimer?.cancel();

    if (_lastValue != null &&
        value.length > _lastValue!.length &&
        value.endsWith('\n')) {
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      _contentController.text = '$value$timeStr ';
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _contentController.text.length),
      );
    }

    _onChangeDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _lastValue = _contentController.text;
    });
  }

  Widget _buildContentSection() {
    return WriteDiaryContentEditor(
      fieldKey: _contentFieldKey,
      controller: _contentController,
      focusNode: _contentFocusNode,
      onTap: _handleContentEditorTap,
      onChanged: _handleContentChanged,
    );
  }

  Widget _buildTimestampSection() {
    if (_timestampTextCache == null) return const SizedBox.shrink();
    return WriteDiaryTimestamp(
      text: _timestampTextCache!,
      color: AppUi.mutedText(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    // 让顶部区域跟随键盘 inset 连续变化，避免出现“下面先变、上面后变”的割裂感。
    const keyboardFullInset = 280.0;
    final topExtrasVisibility = (_isContentFocused && keyboardInset > 0)
        ? (1 - (keyboardInset / keyboardFullInset)).clamp(0.0, 1.0).toDouble()
        : 1.0;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        // 启用键盘避让，避免输入框被软键盘遮挡
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 顶部区域 - 固定不滚动
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAppBar(),
                      const SizedBox(height: 4),
                      IgnorePointer(
                        ignoring: topExtrasVisibility < 0.99,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: topExtrasVisibility,
                            child: Opacity(
                              opacity: topExtrasVisibility,
                              child: _topExtrasChild,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 内容区域 - 可滚动，使用 Expanded 填充剩余空间
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildContentSection()),
                        const SizedBox(height: 8),
                        _buildTimestampSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 自定义 TextEditingController，用于高亮时间格式
class _TimeHighlightController extends TextEditingController {
  // 时间格式正则表达式 (HH:mm)
  static final RegExp _timeRegex = RegExp(r'\b(\d{2}):(\d{2})\b');

  // 缓存上次构建的文本和结果，避免重复计算
  String? _lastText;
  TextSpan? _lastSpan;
  bool? _lastIsDark;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final String text = this.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 如果文本和主题都没有变化，直接返回缓存的结果
    if (text == _lastText && _lastIsDark == isDark && _lastSpan != null) {
      return _lastSpan!;
    }

    _lastText = text;
    _lastIsDark = isDark;

    // 如果文本很短或没有内容，直接返回普通文本
    if (text.isEmpty) {
      _lastSpan = TextSpan(text: text, style: style);
      return _lastSpan!;
    }

    // 快速短路：不包含 ":" 时不可能匹配 HH:mm
    if (!text.contains(':')) {
      _lastSpan = TextSpan(text: text, style: style);
      return _lastSpan!;
    }

    // 如果文本较长（超过600字符），跳过复杂高亮以保证输入帧率
    if (text.length > 600) {
      _lastSpan = TextSpan(text: text, style: style);
      return _lastSpan!;
    }

    final List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    // 获取主题颜色
    final colors = AppColors.of(context);
    final timeColor = isDark ? colors.textSecondary : colors.textSecondary;

    // 查找所有时间格式并高亮
    for (final Match match in _timeRegex.allMatches(text)) {
      // 添加时间前的普通文本
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: style,
          ),
        );
      }

      // 添加时间纯文本样式
      final timeText = match.group(0)!;
      spans.add(
        TextSpan(
          text: timeText,
          style: (style ?? const TextStyle()).copyWith(
            color: timeColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    // 添加剩余文本
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }

    // 如果没有匹配到时间，返回普通文本
    if (spans.isEmpty) {
      _lastSpan = TextSpan(text: text, style: style);
      return _lastSpan!;
    }

    _lastSpan = TextSpan(children: spans);
    return _lastSpan!;
  }
}
