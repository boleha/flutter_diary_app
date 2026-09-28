import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import '../services/gallery_service.dart';
import '../services/motion_photo_service.dart';
import '../theme/app_colors.dart';
import 'app_top_toast.dart';
import 'motion_photo_overlay_controls.dart';

class ImageGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final Function(int)? onDelete;
  final bool canDelete;

  const ImageGalleryScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    this.onDelete,
    this.canDelete = false,
  });

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late final PageController _pageController;
  final GalleryService _galleryService = GalleryService();
  late int _currentIndex;
  late List<String> _images;
  bool _isSaving = false;
  bool _isLoadingMotion = false;
  MotionPhoto? _motionPhoto;
  VideoPlayerController? _motionController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _images = List<String>.from(widget.images);
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadMotionPhoto();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _motionController?.dispose();
    super.dispose();
  }

  Future<void> _loadMotionPhoto() async {
    if (_images.isEmpty) return;
    final imagePath = _images[_currentIndex];
    final motionPhoto = await MotionPhotoService.inspect(imagePath);
    if (!mounted || _images.isEmpty || _images[_currentIndex] != imagePath) {
      return;
    }
    setState(() => _motionPhoto = motionPhoto);
  }

  Future<void> _playMotionPhoto() async {
    final motionPhoto = _motionPhoto;
    if (motionPhoto == null || _isLoadingMotion) return;
    final imagePath = _images[_currentIndex];
    final existing = _motionController;
    if (existing != null) {
      if (existing.value.isPlaying) {
        await existing.pause();
      } else {
        if (existing.value.position >= existing.value.duration) {
          await existing.seekTo(Duration.zero);
        }
        await existing.play();
      }
      if (mounted) setState(() {});
      return;
    }

    await _prepareMotionPhotoForScrubbing();
    if (!mounted || _images[_currentIndex] != imagePath) return;
    final controller = _motionController;
    if (controller == null) return;
    if (controller.value.position >= controller.value.duration) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
    if (mounted) setState(() {});
  }

  Future<void> _playMotionPhotoFromImage() async {
    if (_motionController?.value.isPlaying == true) return;
    await _playMotionPhoto();
  }

  Future<void> _prepareMotionPhotoForScrubbing() async {
    final motionPhoto = _motionPhoto;
    if (_motionController != null ||
        _isLoadingMotion ||
        motionPhoto == null ||
        _images.isEmpty) {
      return;
    }

    final imagePath = _images[_currentIndex];
    setState(() => _isLoadingMotion = true);
    VideoPlayerController? controller;
    try {
      final videoPath = await MotionPhotoService.extractVideo(
        imagePath,
        motionPhoto,
      );
      controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      if (!mounted || _images[_currentIndex] != imagePath) {
        await controller.dispose();
        return;
      }
      setState(() => _motionController = controller);
    } catch (_) {
      await controller?.dispose();
      if (mounted && _images[_currentIndex] == imagePath) {
        setState(() => _motionController = null);
        AppTopToast.show(context, '动态照片加载失败', isError: true);
      }
    } finally {
      if (mounted && _images[_currentIndex] == imagePath) {
        setState(() => _isLoadingMotion = false);
      }
    }
  }

  void _resetMotionPhoto() {
    final controller = _motionController;
    _motionController = null;
    _motionPhoto = null;
    _isLoadingMotion = false;
    if (controller != null) controller.dispose();
    _loadMotionPhoto();
  }

  // 删除当前图片
  void _deleteCurrentImage() {
    if (!widget.canDelete) return;
    if (_images.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) {
        final colors = AppColors.of(context);
        final theme = Theme.of(context);
        return AlertDialog(
        backgroundColor: colors.surface,
        title: Text('删除', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text(
          '确定要删除这张图片吗？',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete();
            },
            child: Text('删除', style: TextStyle(color: colors.danger)),
          ),
        ],
      );
      },
    );
  }

  void _confirmDelete() {
    final deletedIndex = _currentIndex;
    final deletedPath = _images[deletedIndex];
    
    setState(() {
      _images.removeAt(deletedIndex);
    });
    
    // 通知父组件
    widget.onDelete?.call(deletedIndex);
    
    if (_images.isEmpty) {
      // 如果没有图片了，返回并传递删除的图片索引
      Navigator.pop(context, {'deletedIndex': deletedIndex, 'deletedPath': deletedPath});
      return;
    }
    
    // 调整当前索引
    if (_currentIndex >= _images.length) {
      _currentIndex = _images.length - 1;
    }
    _resetMotionPhoto();
  }

  Future<void> _saveCurrentImage() async {
    if (_images.isEmpty || _isSaving) return;
    final imagePath = _images[_currentIndex];
    setState(() {
      _isSaving = true;
    });
    final success = await _galleryService.saveImageToGallery(imagePath);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
    AppTopToast.show(
      context,
      success ? '已保存到相册' : '保存失败',
      isError: !success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (_images.isEmpty) {
      return Scaffold(
        backgroundColor: colors.scrim,
        body: Center(
          child: IconButton(
            icon: Icon(Icons.close, color: colors.actionPrimaryForeground, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.scrim,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              _resetMotionPhoto();
            },
            itemBuilder: (context, index) {
              final controller =
                  index == _currentIndex ? _motionController : null;
              final Widget image;
              if (controller != null && controller.value.isInitialized) {
                image = Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                );
              } else {
                image = PhotoView(
                  imageProvider: FileImage(File(_images[index])),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes: PhotoViewHeroAttributes(tag: 'image_$index'),
                  backgroundDecoration: BoxDecoration(color: colors.scrim),
                );
              }
              return MotionPhotoOverlayControls(
                key: ValueKey(_images[index]),
                isMotionPhoto:
                    index == _currentIndex && _motionPhoto != null,
                isLoading: index == _currentIndex && _isLoadingMotion,
                controller: controller,
                onTogglePlayback: _playMotionPhoto,
                onImageLongPress: _playMotionPhotoFromImage,
                onPrepareScrubbing: _prepareMotionPhotoForScrubbing,
                bottom: _images.length > 1 ? 78 : 40,
                child: image,
              );
            },
          ),
          // 顶部按钮栏
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.canDelete)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: colors.actionPrimaryForeground,
                      size: 28,
                    ),
                    onPressed: _deleteCurrentImage,
                  )
                else
                  const SizedBox(width: 48, height: 48),
                // 关闭按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: _isSaving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.actionPrimaryForeground,
                              ),
                            )
                          : Icon(
                              Icons.download_outlined,
                              color: colors.actionPrimaryForeground,
                              size: 28,
                            ),
                      tooltip: '保存到相册',
                      onPressed: _isSaving ? null : _saveCurrentImage,
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colors.actionPrimaryForeground, size: 30),
                      onPressed: () => Navigator.pop(context, {'currentIndex': _currentIndex}),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_images.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _images.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? colors.actionPrimaryForeground
                          : colors.actionPrimaryForeground.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
