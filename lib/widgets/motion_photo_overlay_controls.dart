import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MotionPhotoOverlayControls extends StatefulWidget {
  final Widget child;
  final bool isMotionPhoto;
  final bool isLoading;
  final double bottom;
  final VideoPlayerController? controller;
  final VoidCallback onTogglePlayback;
  final VoidCallback onImageLongPress;
  final Future<void> Function() onPrepareScrubbing;

  const MotionPhotoOverlayControls({
    super.key,
    required this.child,
    required this.isMotionPhoto,
    required this.isLoading,
    required this.controller,
    required this.onTogglePlayback,
    required this.onImageLongPress,
    required this.onPrepareScrubbing,
    this.bottom = 12,
  });

  @override
  State<MotionPhotoOverlayControls> createState() =>
      _MotionPhotoOverlayControlsState();
}

class _MotionPhotoOverlayControlsState
    extends State<MotionPhotoOverlayControls> {
  static const double _timelineHeight = 80;
  static const double _timelineRadius = 22;
  static const double _expandedButtonSize = 56;
  static const double _buttonInset = 12;

  Timer? _seekTimer;
  Duration? _pendingSeek;
  Completer<void>? _seekComplete;
  bool _isSeeking = false;
  bool _showScrubber = false;
  bool _isScrubbing = false;
  Duration _scrubPosition = Duration.zero;

  @override
  void dispose() {
    _seekTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MotionPhotoOverlayControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _seekTimer?.cancel();
      _pendingSeek = null;
      _isScrubbing = false;
      _scrubPosition = widget.controller?.value.position ?? Duration.zero;
    }
    if (!widget.isMotionPhoto) {
      _showScrubber = false;
      _isScrubbing = false;
    }
  }

  Future<void> _revealScrubber() async {
    if (_showScrubber || !widget.isMotionPhoto) return;
    setState(() {
      _showScrubber = true;
      _scrubPosition = widget.controller?.value.position ?? Duration.zero;
    });
    await widget.onPrepareScrubbing();
    if (!mounted) return;
    setState(() {
      _scrubPosition = widget.controller?.value.position ?? Duration.zero;
    });
  }

  void _beginScrubbing(double fraction) {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;
    _seekTimer?.cancel();
    if (controller.value.isPlaying) unawaited(controller.pause());
    setState(() => _isScrubbing = true);
    _updateScrubPosition(fraction);
  }

  void _updateScrubPosition(double fraction) {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;
    final durationMs = controller.value.duration.inMilliseconds;
    if (durationMs <= 0) return;
    final target = Duration(
      milliseconds: (fraction * durationMs)
          .round()
          .clamp(0, durationMs)
          .toInt(),
    );
    setState(() => _scrubPosition = target);
    _seekTimer?.cancel();
    _seekTimer = Timer(const Duration(milliseconds: 35), () {
      unawaited(_queueSeek(target));
    });
  }

  Future<void> _endScrubbing() async {
    if (!_isScrubbing) return;
    _seekTimer?.cancel();
    await _queueSeek(_scrubPosition);
    if (mounted) setState(() => _isScrubbing = false);
  }

  Future<void> _queueSeek(Duration position) {
    _pendingSeek = position;
    if (_isSeeking) return _seekComplete!.future;
    _isSeeking = true;
    final complete = Completer<void>();
    _seekComplete = complete;
    unawaited(_drainSeeks(complete));
    return complete.future;
  }

  Future<void> _drainSeeks(Completer<void> complete) async {
    try {
      while (mounted && _pendingSeek != null) {
        final position = _pendingSeek!;
        _pendingSeek = null;
        final controller = widget.controller;
        if (controller == null || !controller.value.isInitialized) break;
        try {
          await controller.seekTo(position);
        } catch (_) {
          break;
        }
      }
    } finally {
      _pendingSeek = null;
      _isSeeking = false;
      _seekComplete = null;
      complete.complete();
    }
  }

  Widget _buildPlayButton(VideoPlayerValue? value, double size) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 1),
      ),
      child: Semantics(
        button: true,
        label: value?.isPlaying == true ? '暂停动态照片' : '播放动态照片',
        child: InkWell(
          key: const Key('motion_photo_play_button'),
          customBorder: const CircleBorder(),
          onTap: widget.isLoading ? null : widget.onTogglePlayback,
          onLongPress: () => unawaited(_revealScrubber()),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : CustomPaint(
                      size: Size.square(size * 0.34),
                      painter: _MotionPhotoControlGlyphPainter(
                        isPlaying: value?.isPlaying == true,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  double _fractionAt(double localX, double width) {
    final travel = width - 2 * _buttonInset - _expandedButtonSize;
    if (travel <= 0) return 0;
    return ((localX - _buttonInset - _expandedButtonSize / 2) / travel)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  Widget _buildTimeline(VideoPlayerValue? value, double fraction) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final travel = (width - 2 * _buttonInset - _expandedButtonSize)
            .clamp(0.0, double.infinity)
            .toDouble();
        final canSeek =
            value?.isInitialized == true &&
            (value?.duration.inMilliseconds ?? 0) > 0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: canSeek
              ? (details) => _beginScrubbing(
                  _fractionAt(details.localPosition.dx, width),
                )
              : null,
          onHorizontalDragUpdate: canSeek
              ? (details) => _updateScrubPosition(
                  _fractionAt(details.localPosition.dx, width),
                )
              : null,
          onHorizontalDragEnd: canSeek
              ? (_) => unawaited(_endScrubbing())
              : null,
          onHorizontalDragCancel: canSeek
              ? () => unawaited(_endScrubbing())
              : null,
          child: Container(
            key: const Key('motion_photo_timeline'),
            height: _timelineHeight,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.48),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.88),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(_timelineRadius),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: _buttonInset + fraction * travel,
                  top: (_timelineHeight - _expandedButtonSize) / 2,
                  child: _buildPlayButton(value, _expandedButtonSize),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlsForValue(VideoPlayerValue? value) {
    final duration = value?.duration ?? Duration.zero;
    final position = _isScrubbing
        ? _scrubPosition
        : value?.position ?? Duration.zero;
    final fraction = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();

    return _showScrubber
        ? _buildTimeline(value, fraction)
        : Center(child: _buildPlayButton(value, 44));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: widget.isMotionPhoto ? widget.onImageLongPress : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (widget.isMotionPhoto)
            Positioned(
              left: 16,
              right: 16,
              bottom: widget.bottom,
              child: widget.controller == null
                  ? _buildControlsForValue(null)
                  : ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: widget.controller!,
                      builder: (context, value, _) =>
                          _buildControlsForValue(value),
                    ),
            ),
        ],
      ),
    );
  }
}

class _MotionPhotoControlGlyphPainter extends CustomPainter {
  final bool isPlaying;

  const _MotionPhotoControlGlyphPainter({required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isPlaying) {
      final top = size.height * 0.12;
      final bottom = size.height * 0.88;
      canvas.drawLine(
        Offset(size.width * 0.34, top),
        Offset(size.width * 0.34, bottom),
        paint,
      );
      canvas.drawLine(
        Offset(size.width * 0.66, top),
        Offset(size.width * 0.66, bottom),
        paint,
      );
      return;
    }

    final triangle = Path()
      ..moveTo(size.width * 0.28, size.height * 0.12)
      ..lineTo(size.width * 0.82, size.height * 0.5)
      ..lineTo(size.width * 0.28, size.height * 0.88)
      ..close();
    canvas.drawPath(triangle, paint);
  }

  @override
  bool shouldRepaint(covariant _MotionPhotoControlGlyphPainter oldDelegate) =>
      oldDelegate.isPlaying != isPlaying;
}
