import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../theme/app_colors.dart';
import 'custom_calendar_view.dart';
import 'home_calendar_day_cell.dart';
import 'home_calendar_entry_card.dart';
import 'home_calendar_header.dart';

class HomeCalendarDrawer extends StatefulWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Map<DateTime, List<DiaryEntry>> events;
  final bool calendarImageRenderingEnabled;
  final bool calendarEntryListRenderingEnabled;
  final void Function(DateTime selectedDay, DateTime focusedDay) onCalendarDaySelected;
  final ValueChanged<DateTime> onCalendarPageChanged;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DiaryEntry> onEntryDayTap;
  final VoidCallback onGoToToday;

  const HomeCalendarDrawer({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.events,
    required this.calendarImageRenderingEnabled,
    required this.calendarEntryListRenderingEnabled,
    required this.onCalendarDaySelected,
    required this.onCalendarPageChanged,
    required this.onMonthChanged,
    required this.onEntryDayTap,
    required this.onGoToToday,
  });

  @override
  State<HomeCalendarDrawer> createState() => _HomeCalendarDrawerState();
}

class _HomeCalendarDrawerState extends State<HomeCalendarDrawer> {
  final Map<String, File> _imageFileCache = {};
  List<DateTime> _monthDaysWithEntriesCache = const [];
  Map<DateTime, String> _monthFirstImageCache = const {};
  Map<DateTime, DiaryEntry> _monthFirstEntryCache = const {};
  String _monthCacheKey = '';
  int _monthCacheEventsIdentity = 0;
  final Set<int> _progressiveImageDayKeys = <int>{};
  Timer? _progressiveImageTimer;
  int _progressiveLoadToken = 0;

  void _rebuildMonthCache() {
    final cacheKey = '${widget.focusedDay.year}-${widget.focusedDay.month}';
    final eventsIdentity = identityHashCode(widget.events);
    if (_monthCacheKey == cacheKey && _monthCacheEventsIdentity == eventsIdentity) {
      return;
    }

    final List<DateTime> daysWithEntries = [];
    final Map<DateTime, String> firstImageMap = {};
    final Map<DateTime, DiaryEntry> firstEntryMap = {};
    final lastDay = DateTime(widget.focusedDay.year, widget.focusedDay.month + 1, 0).day;

    for (int day = 1; day <= lastDay; day++) {
      final date = DateTime(widget.focusedDay.year, widget.focusedDay.month, day);
      final entries = widget.events[date];
      if (entries == null || entries.isEmpty) continue;

      final firstEntry = entries.first;
      firstEntryMap[date] = firstEntry;

      if (firstEntry.images.isNotEmpty) {
        daysWithEntries.add(date);
        firstImageMap[date] = firstEntry.images.first;
      }
    }

    _monthCacheKey = cacheKey;
    _monthCacheEventsIdentity = eventsIdentity;
    _monthDaysWithEntriesCache = daysWithEntries;
    _monthFirstImageCache = firstImageMap;
    _monthFirstEntryCache = firstEntryMap;
  }

  int _dayKey(DateTime day) {
    return day.year * 10000 + day.month * 100 + day.day;
  }

  void _stopProgressiveImageLoading() {
    _progressiveLoadToken++;
    _progressiveImageTimer?.cancel();
    _progressiveImageTimer = null;
  }

  List<DateTime> _buildProgressiveLoadQueue(List<DateTime> daysWithEntries) {
    final selectedDay = widget.selectedDay;
    final focusedDay = widget.focusedDay;
    final queue = <DateTime>[];
    final seen = <int>{};

    void addDay(DateTime day) {
      final key = _dayKey(day);
      if (seen.add(key)) {
        queue.add(day);
      }
    }

    if (selectedDay != null) {
      final normalizedSelected = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
      );
      if (_monthFirstImageCache[normalizedSelected] != null) {
        addDay(normalizedSelected);
      }
    }

    final normalizedFocused = DateTime(
      focusedDay.year,
      focusedDay.month,
      focusedDay.day,
    );
    if (_monthFirstImageCache[normalizedFocused] != null) {
      addDay(normalizedFocused);
    }

    final sortedDays = List<DateTime>.from(daysWithEntries)
      ..sort((a, b) {
        final da = a.difference(normalizedFocused).inDays.abs();
        final db = b.difference(normalizedFocused).inDays.abs();
        return da.compareTo(db);
      });
    for (final day in sortedDays) {
      addDay(day);
    }
    return queue;
  }

  void _startProgressiveImageLoading() {
    _stopProgressiveImageLoading();
    final token = ++_progressiveLoadToken;
    final daysWithEntries = _getMonthDaysWithEntries();
    if (daysWithEntries.isEmpty) {
      if (_progressiveImageDayKeys.isNotEmpty && mounted) {
        setState(() {
          _progressiveImageDayKeys.clear();
        });
      }
      return;
    }

    final queue = _buildProgressiveLoadQueue(daysWithEntries);
    int cursor = 0;

    void applyBatch(int batchSize) {
      if (!mounted || token != _progressiveLoadToken) return;
      if (cursor >= queue.length) return;
      final end = (cursor + batchSize).clamp(0, queue.length);
      setState(() {
        for (int i = cursor; i < end; i++) {
          _progressiveImageDayKeys.add(_dayKey(queue[i]));
        }
      });
      cursor = end;
    }

    applyBatch(10);
    if (cursor >= queue.length) return;

    _progressiveImageTimer = Timer.periodic(
      const Duration(milliseconds: 70),
      (timer) {
        if (!mounted || token != _progressiveLoadToken) {
          timer.cancel();
          return;
        }
        if (cursor >= queue.length) {
          timer.cancel();
          return;
        }
        applyBatch(6);
      },
    );
  }

  List<DateTime> _getMonthDaysWithEntries() {
    _rebuildMonthCache();
    return _monthDaysWithEntriesCache;
  }

  DiaryEntry? _getDayFirstEntry(DateTime day) {
    _rebuildMonthCache();
    final date = DateTime(day.year, day.month, day.day);
    return _monthFirstEntryCache[date];
  }

  File? _getCachedImageFile(String? path) {
    if (path == null) return null;
    return _imageFileCache.putIfAbsent(path, () => File(path));
  }

  @override
  void initState() {
    super.initState();
    if (widget.calendarImageRenderingEnabled) {
      _startProgressiveImageLoading();
    }
  }

  @override
  void didUpdateWidget(covariant HomeCalendarDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final monthChanged = oldWidget.focusedDay.year != widget.focusedDay.year ||
        oldWidget.focusedDay.month != widget.focusedDay.month;
    final eventsChanged = !identical(oldWidget.events, widget.events);
    final imageToggleChanged =
        oldWidget.calendarImageRenderingEnabled != widget.calendarImageRenderingEnabled;

    if (imageToggleChanged && !widget.calendarImageRenderingEnabled) {
      _stopProgressiveImageLoading();
      if (_progressiveImageDayKeys.isNotEmpty && mounted) {
        setState(() {
          _progressiveImageDayKeys.clear();
        });
      }
      return;
    }

    if (widget.calendarImageRenderingEnabled &&
        (imageToggleChanged || monthChanged || eventsChanged)) {
      _startProgressiveImageLoading();
    }
  }

  @override
  void dispose() {
    _stopProgressiveImageLoading();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daysWithEntries = _getMonthDaysWithEntries();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Drawer(
        backgroundColor: colors.background,
        child: SafeArea(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            cacheExtent: 320,
            itemCount: daysWithEntries.isEmpty
                ? 4
                : (widget.calendarEntryListRenderingEnabled
                    ? daysWithEntries.length + 3
                    : 4),
            itemBuilder: (context, index) {
              if (index == 0) {
                return HomeCalendarHeader(
                  focusedDay: widget.focusedDay,
                  onMonthChanged: widget.onMonthChanged,
                  onGoToToday: widget.onGoToToday,
                );
              }

              if (index == 1) {
                return RepaintBoundary(
                  child: SizedBox(
                    height: 350,
                    child: CustomCalendarView(
                      focusedDay: widget.focusedDay,
                      selectedDay: widget.selectedDay,
                      onDaySelected: widget.onCalendarDaySelected,
                      onPageChanged: widget.onCalendarPageChanged,
                      dayBuilder:
                          (context, day, isToday, isSelected, isOutside, isDisabled) {
                        final normalizedDay =
                            DateTime(day.year, day.month, day.day);
                        final imagePath = _monthFirstImageCache[normalizedDay];
                        final canRenderImage = imagePath != null &&
                            widget.calendarImageRenderingEnabled &&
                            _progressiveImageDayKeys
                                .contains(_dayKey(normalizedDay));
                        return HomeCalendarDayCell(
                          day: day,
                          imagePath: canRenderImage ? imagePath : null,
                          calendarImageRenderingEnabled: canRenderImage,
                          isToday: isToday,
                          isSelected: isSelected,
                          isOutside: isOutside,
                          isDisabled: isDisabled,
                          getCachedImageFile: _getCachedImageFile,
                        );
                      },
                    ),
                  ),
                );
              }

              if (index == 2) {
                return Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.calendarDivider,
                  indent: 16,
                  endIndent: 16,
                );
              }

              if (daysWithEntries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      '本月暂无日记',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                );
              }

              if (!widget.calendarEntryListRenderingEnabled) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.calendarControlIcon,
                      ),
                    ),
                  ),
                );
              }

              final date = daysWithEntries[index - 3];
              final firstEntry = _getDayFirstEntry(date);
              if (firstEntry == null) {
                return const SizedBox.shrink();
              }

              return RepaintBoundary(
                child: HomeCalendarEntryCard(
                  date: date,
                  entry: firstEntry,
                  isDark: isDark,
                  onTap: () => widget.onEntryDayTap(firstEntry),
                  getCachedImageFile: _getCachedImageFile,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

}
