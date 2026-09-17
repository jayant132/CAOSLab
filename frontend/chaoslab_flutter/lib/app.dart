import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/repo_input/repo_input_screen.dart';

class ChaosLabApp extends StatelessWidget {
  const ChaosLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChaosLab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const RepoInputScreen(),
    );
  }
}
