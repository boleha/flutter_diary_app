import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/theme_service.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 优化帧率：设置为最高可用帧率
  _setHighRefreshRate();

  // 初始化 ThemeService
  final themeService = ThemeService();
  await themeService.ensureInitialized();

  // 清理超过30天的已删除日记
  final storageService = StorageService();
  await storageService.cleanupOldDeletedEntries();

  // 初始化通知服务
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(const MyApp());
}

void _setHighRefreshRate() {
  if (!kIsWeb && Platform.isAndroid) {
    // Android: 尝试设置为最高刷新率
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // 当屏幕尺寸或刷新率变化时重新优化
    _setHighRefreshRate();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    // 当系统主题变化时，如果设置为跟随系统，则刷新UI
    if (_themeService.themeMode == ThemeModeType.system) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wlog',
      debugShowCheckedModeBanner: false,
      // 性能优化：使用 const 构造函数
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
      theme: AppTheme.buildLightTheme(),
      darkTheme: AppTheme.buildDarkTheme(),
      themeMode: _themeService.flutterThemeMode,
      home: const HomeScreen(),
      // 性能优化：减少不必要的重建
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}
