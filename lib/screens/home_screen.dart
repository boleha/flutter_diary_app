import 'dart:async';
import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/diary_card.dart';
import '../widgets/home_calendar_drawer.dart';
import '../widgets/home_day_page_content.dart';
import '../widgets/home_header_bar.dart';
import '../widgets/home_search_results.dart';
import 'diary_detail_screen.dart';
import 'write_diary_screen.dart';
import 'settings_screen.dart';
import 'recycle_bin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageController _pageController = PageController(initialPage: 10000);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<DiaryEntry>> _events = {};
  List<DiaryEntry> _allEntriesCache = [];
  bool _isAnimating = false;
  bool _isDrawerOpen = false;
  bool _calendarImageRenderingEnabled = false;
  bool _calendarEntryListRenderingEnabled = false;
  bool _isSearching = false;
  bool _isOpeningDrawerEntry = false;
  int _entriesRevision = 0;
  int _latestLoadRequestId = 0;
  String _entriesFingerprint = '';
  String _searchCacheQuery = '';
  int _searchCacheRevision = -1;
  List<DiaryEntry> _filteredEntriesCache = const [];
  Map<String, String> _searchableEntryTextCache = const {};
  Map<String, int> _searchableEntryVersionCache = const {};

  // 搜索防抖定时器
  Timer? _searchDebounceTimer;
  Timer? _calendarImageEnableTimer;
  Timer? _calendarEntryListEnableTimer;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEntries();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    _searchDebounceTimer?.cancel();
    _calendarImageEnableTimer?.cancel();
    _calendarEntryListEnableTimer?.cancel();
    super.dispose();
  }

  List<DiaryEntry> _getAllEntries() {
    return _allEntriesCache;
  }

  List<DiaryEntry> _getFilteredEntries() {
    final searchQuery = _searchQueryNotifier.value;
    if (searchQuery.isEmpty) {
      return [];
    }
    if (_searchCacheQuery == searchQuery && _searchCacheRevision == _entriesRevision) {
      return _filteredEntriesCache;
    }
    final query = searchQuery.toLowerCase();
    _filteredEntriesCache = _getAllEntries().where((entry) {
      return (_searchableEntryTextCache[entry.id] ?? '').contains(query);
    }).toList();
    _searchCacheQuery = searchQuery;
    _searchCacheRevision = _entriesRevision;
    return _filteredEntriesCache;
  }

  void _invalidateSearchCache() {
    _searchCacheQuery = '';
    _searchCacheRevision = -1;
    _filteredEntriesCache = const [];
  }

  String _buildSearchableEntryText(DiaryEntry entry) {
    return [
      entry.title,
      entry.content,
      entry.breakfast,
      entry.lunch,
      entry.dinner,
      entry.snacks,
      entry.mood,
      entry.weather,
      entry.weight,
    ].whereType<String>()
     .where((value) => value.isNotEmpty)
     .join('\n')
     .toLowerCase();
  }

  String _buildEntriesFingerprint(List<DiaryEntry> entries) {
    // 使用哈希替代字符串拼接，性能从 O(N) 字符串操作优化为 O(N) 整数运算
    int hash = entries.length;
    for (final entry in entries) {
      hash = hash * 31 + entry.id.hashCode;
      hash = hash * 31 + entry.updatedAt.hashCode;
      hash = hash * 31 + entry.date.hashCode;
      hash = hash * 31 + (entry.isFavorite ? 1 : 0);
    }
    return hash.toString();
  }

  void _toggleSearch() {
    final nextSearching = !_isSearching;
    setState(() {
      _isSearching = nextSearching;
      if (!nextSearching) {
        _searchController.clear();
        _searchQueryNotifier.value = '';
        _invalidateSearchCache();
      }
    });
    if (nextSearching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isSearching) return;
        _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
    }
  }

  Future<void> _loadEntries() async {
    final requestId = ++_latestLoadRequestId;
    final entries = await _storageService.getAllEntries();
    if (!mounted || requestId != _latestLoadRequestId) return;

    final nextFingerprint = _buildEntriesFingerprint(entries);
    if (nextFingerprint == _entriesFingerprint) return;

    final groupedEvents = <DateTime, List<DiaryEntry>>{};
    final searchableEntryTextCache = <String, String>{};
    final searchableEntryVersionCache = <String, int>{};
    for (final entry in entries) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (groupedEvents[date] == null) {
        groupedEvents[date] = [];
      }
      groupedEvents[date]!.add(entry);
      final entryVersion = entry.updatedAt.microsecondsSinceEpoch;
      searchableEntryVersionCache[entry.id] = entryVersion;
      final cachedVersion = _searchableEntryVersionCache[entry.id];
      final cachedText = _searchableEntryTextCache[entry.id];
      if (cachedVersion == entryVersion && cachedText != null) {
        searchableEntryTextCache[entry.id] = cachedText;
      } else {
        searchableEntryTextCache[entry.id] = _buildSearchableEntryText(entry);
      }
    }

    setState(() {
      _events = groupedEvents;
      _allEntriesCache = entries;
      _entriesFingerprint = nextFingerprint;
      _searchableEntryTextCache = searchableEntryTextCache;
      _searchableEntryVersionCache = searchableEntryVersionCache;
      _entriesRevision++;
      _invalidateSearchCache();
    });
  }

  void _syncFocusedDay(DateTime focusedDay) {
    _focusedDay = focusedDay;
  }

  void _handleDrawerChanged(bool isOpened) {
    _isDrawerOpen = isOpened;
    _calendarImageEnableTimer?.cancel();
    _calendarEntryListEnableTimer?.cancel();

    if (!isOpened) {
      if (_calendarImageRenderingEnabled && mounted) {
        setState(() {
          _calendarImageRenderingEnabled = false;
        });
      }
      if (_calendarEntryListRenderingEnabled && mounted) {
        setState(() {
          _calendarEntryListRenderingEnabled = false;
        });
      }
      return;
    }

    if (_calendarImageRenderingEnabled) return;
    _calendarImageEnableTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || !_isDrawerOpen) return;
      setState(() {
        _calendarImageRenderingEnabled = true;
      });
    });

    if (_calendarEntryListRenderingEnabled) return;
    _calendarEntryListEnableTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted || !_isDrawerOpen) return;
      setState(() {
        _calendarEntryListRenderingEnabled = true;
      });
    });
  }
  void _onPageChanged(int page) {
    if (_isAnimating) return;
    
    final dayOffset = page - 10000;
    final newDate = DateTime.now().add(Duration(days: dayOffset));
    
    setState(() {
      _selectedDay = newDate;
      _focusedDay = newDate;
    });
  }

  void _handleCalendarDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final dayOffset = targetDay.difference(today).inDays;
    final pageIndex = 10000 + dayOffset;

    setState(() {
      _selectedDay = selectedDay;
      _syncFocusedDay(focusedDay);
    });

    _pageController.jumpToPage(pageIndex);
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _handleCalendarPageChanged(DateTime focusedDay) {
    _calendarImageEnableTimer?.cancel();
    if (_calendarImageRenderingEnabled) {
      setState(() {
        _calendarImageRenderingEnabled = false;
        _syncFocusedDay(focusedDay);
      });
    } else {
      setState(() {
        _syncFocusedDay(focusedDay);
      });
    }
    if (_isDrawerOpen) {
      _calendarImageEnableTimer = Timer(const Duration(milliseconds: 180), () {
        if (!mounted || !_isDrawerOpen) return;
        setState(() {
          _calendarImageRenderingEnabled = true;
        });
      });
    }
  }

  void _handleCalendarMonthChanged(DateTime focusedDay) {
    setState(() {
      _syncFocusedDay(focusedDay);
    });
  }

  void _openEntryDetails(DiaryEntry entry) {
    if (_isOpeningDrawerEntry) return;
    _isOpeningDrawerEntry = true;
    final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
    setState(() {
      _selectedDay = date;
      _focusedDay = date;
    });

    // 直接从日历抽屉进入详情，返回时保持日历上下文。
    unawaited(() async {
      if (!mounted) {
        _isOpeningDrawerEntry = false;
        return;
      }
      try {
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => DiaryDetailScreen(entry: entry),
          ),
        );
        if (saved == true) unawaited(_loadEntries());
      } finally {
        _isOpeningDrawerEntry = false;
      }
    }());
  }

  void _handleDrawerEntryDayTap(DiaryEntry entry) {
    _openEntryDetails(entry);
  }

  void _handleSearchEntryTap(DiaryEntry entry) {
    _openEntryDetails(entry);
  }

  Future<void> _navigateToWriteDiary([DateTime? date, DiaryEntry? existingEntry]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriteDiaryScreen(
          selectedDate: date ?? _selectedDay ?? DateTime.now(),
          existingEntry: existingEntry,
        ),
      ),
    );
    
    if (result == true) {
      unawaited(_loadEntries());
    }
  }

  Future<void> _deleteEntry(DiaryEntry entry) async {
    final colors = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这篇日记吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _storageService.deleteEntry(entry.id);
      unawaited(_loadEntries());
    }
  }

  Future<void> _toggleFavorite(DiaryEntry entry) async {
    await _storageService.toggleFavorite(entry.id);
    unawaited(_loadEntries());
  }

  void _locateToToday() {
    if (_isAnimating) return;

    final now = DateTime.now();
    setState(() {
      _selectedDay = now;
      _focusedDay = now;
      if (_isSearching) {
        _isSearching = false;
        _searchController.clear();
        _searchQueryNotifier.value = '';
        _invalidateSearchCache();
      }
    });

    _isAnimating = true;
    _pageController
        .animateToPage(
          10000,
          duration: AppUi.baseDuration,
          curve: Curves.easeInOut,
        )
        .then((_) {
          _isAnimating = false;
        });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bool isSelectedToday =
        _selectedDay != null &&
        _selectedDay!.year == DateTime.now().year &&
        _selectedDay!.month == DateTime.now().month &&
        _selectedDay!.day == DateTime.now().day;
    final Color headerDateColor = isSelectedToday
        ? colors.danger
        : Theme.of(context).colorScheme.onSurface;

    return PopScope<Object?>(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSearching) {
          _toggleSearch();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        onDrawerChanged: _handleDrawerChanged,
        drawer: HomeCalendarDrawer(
          focusedDay: _focusedDay,
          selectedDay: _selectedDay,
          events: _events,
          calendarImageRenderingEnabled: _calendarImageRenderingEnabled,
          calendarEntryListRenderingEnabled: _calendarEntryListRenderingEnabled,
          onCalendarDaySelected: _handleCalendarDaySelected,
          onCalendarPageChanged: _handleCalendarPageChanged,
          onMonthChanged: _handleCalendarMonthChanged,
          onEntryDayTap: _handleDrawerEntryDayTap,
          onGoToToday: _goToToday,
        ),
        body: SafeArea(
          child: Column(
            children: [
              HomeHeaderBar(
                isSearching: _isSearching,
                selectedDay: _selectedDay,
                headerDateColor: headerDateColor,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onToggleSearch: _toggleSearch,
                onDateTap: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                onLocateToday: _locateToToday,
                onOpenRecycleBin: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecycleBinScreen(),
                    ),
                  );
                  if (result == true) {
                    unawaited(_loadEntries());
                  }
                },
                onOpenSettings: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  if (result == true) {
                    unawaited(_loadEntries());
                  }
                },
                onClearSearch: () {
                  _searchController.clear();
                  _searchQueryNotifier.value = '';
                  _invalidateSearchCache();
                },
                onSearchChanged: (value) {
                  _searchDebounceTimer?.cancel();
                  _searchDebounceTimer = Timer(AppUi.shortDebounce, () {
                    if (!mounted || _searchQueryNotifier.value == value) return;
                    _searchQueryNotifier.value = value;
                    _invalidateSearchCache();
                  });
                },
              ),
              Expanded(
                child: RepaintBoundary(
                  child: IndexedStack(
                    index: _isSearching ? 1 : 0,
                    children: [
                      RepaintBoundary(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          physics: const PageScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          allowImplicitScrolling: true,
                          itemBuilder: (context, index) {
                            final dayOffset = index - 10000;
                            final date = DateTime.now().add(Duration(days: dayOffset));
                            return _buildDayPage(date);
                          },
                        ),
                      ),
                      RepaintBoundary(
                        child: HomeSearchResults(
                          searchQueryListenable: _searchQueryNotifier,
                          getFilteredEntries: _getFilteredEntries,
                          itemBuilder: _buildSearchResultCard,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'write_diary_fab',
        onPressed: () => _navigateToWriteDiary(),
        backgroundColor: colors.actionPrimaryBackground,
        foregroundColor: colors.actionPrimaryForeground,
        child: const Icon(Icons.edit),
      ),
      ),
    );
  }

  Widget _buildSearchResultCard(DiaryEntry entry, String searchQuery) {
    return DiaryCard(
      entry: entry,
      onTap: () => _handleSearchEntryTap(entry),
      onToggleFavorite: () => _toggleFavorite(entry),
      onDelete: () => _deleteEntry(entry),
      showDate: true,
      searchQuery: searchQuery,
    );
  }

  Widget _buildDayPage(DateTime date) {
    return RepaintBoundary(
      child: HomeDayPageContent(
        date: date,
        events: _events,
        onNavigateToWriteDiary: _navigateToWriteDiary,
        onDeleteEntry: _deleteEntry,
        onToggleFavorite: _toggleFavorite,
        searchQuery: _searchQueryNotifier.value,
      ),
    );
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _syncFocusedDay(now);
      _selectedDay = now;
    });
    // 只在日历内部跳转到今天，不关闭侧边栏，不跳回主页
  }
}
