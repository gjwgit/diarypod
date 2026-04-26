/// DiaryPod — private encrypted diary on your Solid Pod.
///
// Time-stamp: <2026-04-26>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:solidui/solidui.dart';

import 'package:diarypod/app_scaffold.dart';
import 'package:diarypod/constants/app.dart';
import 'package:diarypod/services/app_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SolidSecurityKeyCentralManager.instance;
  runApp(
    ChangeNotifierProvider(create: (_) => AppProvider(), child: const _App()),
  );
}

class _App extends StatefulWidget {
  const _App();

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  @override
  void initState() {
    super.initState();
    solidThemeNotifier.addListener(() => setState(() {}));
    solidThemeNotifier.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A235A)),
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A235A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      ),
      themeMode: solidThemeNotifier.themeMode,
      home: SolidLogin(
        required: false,
        appDirectory: appDir,
        title: appName.toUpperCase(),
        image: const AssetImage('assets/images/app_image.jpg'),
        logo: const AssetImage('assets/images/app_icon.png'),
        link: 'https://github.com/gjwgit/diarypod',
        child: const AppScaffold(),
      ),
    );
  }
}
