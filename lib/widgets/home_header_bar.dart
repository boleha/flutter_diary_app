import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_ui.dart';

class HomeHeaderBar extends StatelessWidget {
  final bool isSearching;
  final DateTime? selectedDay;
  final Color headerDateColor;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onToggleSearch;
  final VoidCallback onDateTap;
  final VoidCallback onLocateToday;
  final VoidCallback onOpenRecycleBin;
  final VoidCallback onOpenSettings;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSearchChanged;

  const HomeHeaderBar({
    super.key,
    required this.isSearching,
    required this.selectedDay,
    required this.headerDateColor,
    required this.searchController,
    required this.searchFocusNode,
    required this.onToggleSearch,
    required this.onDateTap,
    required this.onLocateToday,
    required this.onOpenRecycleBin,
    required this.onOpenSettings,
    required this.onClearSearch,
    required this.onSearchChanged,
  });

  Widget _actionButton({
    required Widget icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return NeumorphicSurface(
      radius: 12,
      child: IconButton(
        icon: icon,
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppUi.headerPadding,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: AnimatedSwitcher(
                duration: AppUi.fastDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: isSearching
                    ? TextField(
                        key: const ValueKey<String>('search_field'),
                        controller: searchController,
                        focusNode: searchFocusNode,
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: '搜索日记...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: onClearSearch,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppUi.subtleSurface(context),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: onSearchChanged,
                        onTapOutside: (_) {
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : Align(
                        key: const ValueKey<String>('date_trigger'),
                        alignment: Alignment.centerLeft,
                        child: selectedDay == null
                            ? const SizedBox.shrink()
                            : InkWell(
                                onTap: onDateTap,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '${selectedDay!.month}',
                                        style: GoogleFonts.righteous(
                                          fontSize: 32,
                                          color: headerDateColor,
                                        ),
                                      ),
                                      Text(
                                        '月',
                                        style: GoogleFonts.righteous(
                                          fontSize: 16,
                                          color: headerDateColor,
                                        ),
                                      ),
                                      Text(
                                        '${selectedDay!.day}',
                                        style: GoogleFonts.righteous(
                                          fontSize: 32,
                                          color: headerDateColor,
                                        ),
                                      ),
                                      Text(
                                        '日',
                                        style: GoogleFonts.righteous(
                                          fontSize: 16,
                                          color: headerDateColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
              ),
            ),
          ),
          _actionButton(
            icon: AnimatedSwitcher(
              duration: AppUi.fastDuration,
              child: Icon(
                isSearching ? Icons.close : Icons.search,
                key: ValueKey<bool>(isSearching),
              ),
            ),
            onPressed: onToggleSearch,
            tooltip: isSearching ? '关闭搜索' : '搜索',
          ),
          const SizedBox(width: 6),
          _actionButton(
            icon: const Icon(Icons.my_location),
            onPressed: onLocateToday,
            tooltip: '定位到今天',
          ),
          const SizedBox(width: 6),
          _actionButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onOpenRecycleBin,
            tooltip: '回收站',
          ),
          const SizedBox(width: 6),
          _actionButton(
            icon: const Icon(Icons.settings),
            onPressed: onOpenSettings,
            tooltip: '设置',
          ),
        ],
      ),
    );
  }
}
