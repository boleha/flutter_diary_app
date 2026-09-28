import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_ui.dart';

class HomeCalendarHeader extends StatelessWidget {
  final DateTime focusedDay;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onGoToToday;

  const HomeCalendarHeader({
    super.key,
    required this.focusedDay,
    required this.onMonthChanged,
    required this.onGoToToday,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: AppUi.neumorphicDecoration(
              context,
              radius: 10,
              color: colors.calendarControlBackground,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: focusedDay.year,
                icon: Icon(Icons.arrow_drop_down, size: 20, color: colors.calendarControlIcon),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.calendarControlText,
                ),
                dropdownColor: colors.surface,
                borderRadius: BorderRadius.circular(8),
                menuMaxHeight: 200,
                items: List.generate(11, (index) {
                  final year = 2020 + index;
                  return DropdownMenuItem<int>(
                    value: year,
                    child: Text(
                      '$year',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            year == focusedDay.year ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  );
                }),
                onChanged: (int? year) {
                  if (year != null) {
                    onMonthChanged(DateTime(year, focusedDay.month, 1));
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: AppUi.neumorphicDecoration(
              context,
              radius: 10,
              color: colors.calendarControlBackground,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: focusedDay.month,
                icon: Icon(Icons.arrow_drop_down, size: 20, color: colors.calendarControlIcon),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.calendarControlText,
                ),
                dropdownColor: colors.surface,
                borderRadius: BorderRadius.circular(8),
                menuMaxHeight: 200,
                items: List.generate(12, (index) {
                  final month = index + 1;
                  return DropdownMenuItem<int>(
                    value: month,
                    child: Text(
                      '$month',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            month == focusedDay.month ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  );
                }),
                onChanged: (int? month) {
                  if (month != null) {
                    onMonthChanged(DateTime(focusedDay.year, month, 1));
                  }
                },
              ),
            ),
          ),
          const Spacer(),
          NeumorphicSurface(
            radius: 10,
            color: colors.calendarControlBackground,
            child: IconButton(
              onPressed: onGoToToday,
              icon: Icon(
                Icons.my_location,
                size: 20,
                color: colors.calendarControlIcon,
              ),
              tooltip: '定位到今天',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            ),
          ),
        ],
      ),
    );
  }
}
