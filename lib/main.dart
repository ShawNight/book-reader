import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/app_settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化设置服务
  await AppSettingsService().init();

  runApp(
    const ProviderScope(
      child: YueDuApp(),
    ),
  );
}

class YueDuApp extends StatefulWidget {
  const YueDuApp({super.key});

  @override
  State<YueDuApp> createState() => _YueDuAppState();
}

class _YueDuAppState extends State<YueDuApp> {
  final AppSettingsService _appSettings = AppSettingsService();

  @override
  void initState() {
    super.initState();
    _appSettings.themeModeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _appSettings.themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '悦读',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _appSettings.themeMode,
      home: const HomeScreen(),
    );
  }
}
