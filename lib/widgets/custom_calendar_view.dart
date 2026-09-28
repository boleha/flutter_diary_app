import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 自实现月历组件：6 行 x 7 列网格，左右滑动翻月。
/// 替代 table_calendar，功能等价：选中、今天、非本月灰显、禁用日期。
class CustomCalendarView extends StatefulWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  /// 自定义日期格子渲染；返回 null 时使用默认数字样式。
  final Widget Function(
    BuildContext context,
    DateTime day,
    bool isToday,
    bool isSelected,
    bool isOutside,
    bool isDisabled,
  )? dayBuilder;

  const CustomCalendarView({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    this.dayBuilder,
  });

  @override
  State<CustomCalendarView> createState() => _CustomCalendarViewState();
}

class _CustomCalendarViewState extends State<CustomCalendarView> {
  static const int _firstYear = 2020;
  static const int _lastYear = 2030;
  static const int _centerPage = 500;

  late final PageController _pageController;
  DateTime _pageFocusedMonth = DateTime(_firstYear, 1, 1);

  int _monthIndex(DateTime day) => (day.year - _firstYear) * 12 + (day.month - 1);

  DateTime _monthFromIndex(int index) {
    return DateTime(_firstYear + index ~/ 12, index % 12 + 1, 1);
  }

  int _pageFor(DateTime day) => _centerPage + _monthIndex(day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isOutOfRange(DateTime day) {
    final index = _monthIndex(day);
    final lastIndex = (_lastYear - _firstYear) * 12 + 11;
    return index < 0 || index > lastIndex;
  }

  List<DateTime> _buildMonthGrid(int year, int month) {
    final firstOfMonth = DateTime(year, month, 1);
    final leadingCount = firstOfMonth.weekday - 1; // 周一开头
    final cells = <DateTime>[];
    for (int i = 0; i < 42; i++) {
      cells.add(DateTime(year, month, 1 + i - leadingCount));
    }
    return cells;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageFor(widget.focusedDay));
    _pageFocusedMonth = DateTime(widget.focusedDay.year, widget.focusedDay.month, 1);
  }

  @override
  void didUpdateWidget(covariant CustomCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newMonth = DateTime(widget.focusedDay.year, widget.focusedDay.month, 1);
    if (!_isSameDay(_pageFocusedMonth, newMonth)) {
      _pageController.jumpToPage(_pageFor(newMonth));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return Column(
      children: [
        Row(
          children: List.generate(7, (index) {
            final isWeekend = index >= 5;
            return Expanded(
              child: Center(
                child: Text(
                  weekdays[index],
                  style: TextStyle(
                    color: isWeekend
                        ? colors.calendarWeekendText
                        : colors.calendarWeekdayText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              final month = _monthFromIndex(page - _centerPage);
              _pageFocusedMonth = month;
              widget.onPageChanged(month);
            },
            itemBuilder: (context, page) {
              final month = _monthFromIndex(page - _centerPage);
              return _buildMonthGridWidget(month);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGridWidget(DateTime month) {
    final cells = _buildMonthGrid(month.year, month.month);
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        final cellHeight = constraints.maxHeight / 6;
        final childAspectRatio = cellWidth / cellHeight;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: cells.length,
          itemBuilder: (context, index) {
            final day = cells[index];
            final isToday = _isSameDay(day, DateTime.now());
            final isSelected =
                widget.selectedDay != null && _isSameDay(day, widget.selectedDay!);
            final isOutside =
                day.year != month.year || day.month != month.month;
            final isDisabled = _isOutOfRange(day);

            Widget dayWidget;
            if (widget.dayBuilder != null) {
              dayWidget = widget.dayBuilder!(
                context,
                day,
                isToday,
                isSelected,
                isOutside,
                isDisabled,
              );
            } else {
              dayWidget = Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDisabled
                        ? colors.calendarDayDisabledText
                        : isOutside
                            ? colors.calendarDayOutsideText
                            : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isDisabled
                  ? null
                  : () {
                      widget.onDaySelected(
                        day,
                        DateTime(day.year, day.month, 1),
                      );
                    },
              child: dayWidget,
            );
          },
        );
      },
    );
  }
}
