import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

import '../models/diary_entry.dart';
import '../services/motion_photo_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/motion_photo_overlay_controls.dart';

class DiaryDetailScreen extends StatefulWidget {
  final DiaryEntry entry;

  const DiaryDetailScreen({super.key, required this.entry});

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  late final PageController _pageController;
  int _pageIndex = 0;
  bool _isLoadingMotion = false;
  MotionPhoto? _motionPhoto;
  VideoPlayerController? _motionController;

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _motionController?.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final controller = _motionController;
    _motionController = null;
    controller?.dispose();
    setState(() {
      _pageIndex = index;
      _motionPhoto = null;
      _isLoadingMotion = false;
    });
    if (index > 0) _loadMotionPhoto(index - 1);
  }

  Future<void> _loadMotionPhoto(int imageIndex) async {
    final path = widget.entry.images[imageIndex];
    final motionPhoto = await MotionPhotoService.inspect(path);
    if (!mounted || _pageIndex != imageIndex + 1) return;
    setState(() => _motionPhoto = motionPhoto);
  }

  Future<void> _toggleMotionPhoto() async {
    final motionPhoto = _motionPhoto;
    if (motionPhoto == null || _isLoadingMotion || _pageIndex == 0) return;

    final pageAtStart = _pageIndex;
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
    if (!mounted || _pageIndex != pageAtStart) return;
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
    await _toggleMotionPhoto();
  }

  Future<void> _prepareMotionPhotoForScrubbing() async {
    final motionPhoto = _motionPhoto;
    if (_motionController != null ||
        _isLoadingMotion ||
        motionPhoto == null ||
        _pageIndex == 0) {
      return;
    }

    final pageAtStart = _pageIndex;
    final imagePath = widget.entry.images[_pageIndex - 1];
    setState(() => _isLoadingMotion = true);
    VideoPlayerController? controller;
    try {
      final videoPath = await MotionPhotoService.extractVideo(
        imagePath,
        motionPhoto,
      );
      controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      if (!mounted || _pageIndex != pageAtStart) {
        await controller.dispose();
        return;
      }
      setState(() => _motionController = controller);
    } catch (_) {
      await controller?.dispose();
      if (mounted && _pageIndex == pageAtStart) {
        setState(() => _motionController = null);
      }
    } finally {
      if (mounted && _pageIndex == pageAtStart) {
        setState(() => _isLoadingMotion = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final entry = widget.entry;
    final pageCount = entry.images.length + 1;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: pageCount,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => index == 0
                  ? _buildTextPage(context)
                  : _buildImagePage(context, index - 1),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: _buildPageIndicator(context, pageCount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextPage(BuildContext context) {
    final entry = widget.entry;
    final colors = AppColors.of(context);
    final meals = <(String, String?)>[
      ('早餐', entry.breakfast),
      ('午餐', entry.lunch),
      ('晚餐', entry.dinner),
      ('加餐', entry.snacks),
    ].where((item) => item.$2?.trim().isNotEmpty == true).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${entry.date.year}年${entry.date.month}月',
            style: TextStyle(fontSize: 15, color: colors.textMuted),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.date.day}',
                style: TextStyle(
                  fontSize: 54,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 7),
                child: Text(
                  _weekdays[entry.date.weekday - 1],
                  style: TextStyle(fontSize: 16, color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (entry.mood?.trim().isNotEmpty == true ||
              entry.weather?.trim().isNotEmpty == true ||
              entry.weight?.trim().isNotEmpty == true)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entry.mood?.trim().isNotEmpty == true)
                  _buildInfoChip(context, Icons.mood_outlined, entry.mood!),
                if (entry.weather?.trim().isNotEmpty == true)
                  _buildInfoChip(
                    context,
                    Icons.wb_cloudy_outlined,
                    entry.weather!,
                  ),
                if (entry.weight?.trim().isNotEmpty == true)
                  _buildInfoChip(
                    context,
                    Icons.monitor_weight_outlined,
                    _weightLabel(entry.weight!),
                  ),
              ],
            ),
          if (entry.content.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            NeumorphicSurface(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '记录',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      entry.content.trim(),
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.8,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (meals.isNotEmpty) ...[
            const SizedBox(height: 16),
            NeumorphicSurface(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '饮食记录',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final meal in meals) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 42,
                              child: Text(
                                meal.$1,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                meal.$2!.trim(),
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (entry.content.trim().isEmpty && meals.isEmpty) ...[
            const SizedBox(height: 20),
            NeumorphicSurface(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '这天没有文字记录',
                  style: TextStyle(color: colors.textMuted, fontSize: 15),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String text) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: AppUi.neumorphicDecoration(
        context,
        radius: 20,
        color: colors.surfaceCard,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.iconMuted),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _weightLabel(String value) {
    final normalized = value.trim();
    return normalized.toLowerCase().endsWith('kg') || normalized.endsWith('公斤')
        ? normalized
        : '${normalized}kg';
  }

  Widget _buildImagePage(BuildContext context, int imageIndex) {
    final colors = AppColors.of(context);
    final path = widget.entry.images[imageIndex];
    final isCurrentPage = _pageIndex == imageIndex + 1;
    final controller = isCurrentPage ? _motionController : null;
    final image = controller?.value.isInitialized == true
        ? Center(
            child: AspectRatio(
              aspectRatio: controller!.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          )
        : PhotoView(
            imageProvider: FileImage(File(path)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            heroAttributes: PhotoViewHeroAttributes(
              tag: 'diary_${widget.entry.id}_image_$imageIndex',
            ),
            backgroundDecoration: BoxDecoration(color: colors.background),
          );

    return MotionPhotoOverlayControls(
      key: ValueKey('diary_${widget.entry.id}_$path'),
      isMotionPhoto: isCurrentPage && _motionPhoto != null,
      isLoading: isCurrentPage && _isLoadingMotion,
      controller: controller,
      onTogglePlayback: _toggleMotionPhoto,
      onImageLongPress: _playMotionPhotoFromImage,
      onPrepareScrubbing: _prepareMotionPhotoForScrubbing,
      child: image,
    );
  }

  Widget _buildPageIndicator(BuildContext context, int pageCount) {
    final colors = AppColors.of(context);
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: colors.surfaceCard.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outlineStrong.withValues(alpha: 0.25),
              width: 0.7,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadowSoft.withValues(alpha: 0.6),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              pageCount,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _pageIndex == index
                      ? Theme.of(context).colorScheme.primary
                      : colors.outlineStrong.withValues(alpha: 0.48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
