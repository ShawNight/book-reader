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

class YueDuApp extends StatelessWidget {
  const YueDuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appSettings = AppSettingsService();
    
    return MaterialApp(
      title: '悦读',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: appSettings.themeMode,
      home: const HomeScreen(),
    );
  }
}
