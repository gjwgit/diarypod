/// DiaryPod — private encrypted diary on your Solid Pod.
///
// Time-stamp: <Thursday 2026-04-30 12:29:28 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Tony Chen, Graham Williams

library;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:solidui/solidui.dart';
import 'package:window_manager/window_manager.dart';

import 'package:diarypod/app_scaffold.dart';
import 'package:diarypod/constants/app.dart';
import 'package:diarypod/services/app_provider.dart';

// 20260402 gjw Below is the main entry point for the application.  For main()
// we require [async] because we asynchronously [await] the window manager as
// below. Often, `main()` will include just the call [runApp].

void main() async {
  // 20260402 gjw Optionally for development we utilise [debugPrint] to trace
  // execution, and note that the output is not shown on a `--release`. To
  // quieten the `--debug` running we can globally remove [debugPrint] messages
  // by mapping it to null (no op).
  //
  // debugPrint = (String? message, {int? wrapWidth}) {
  //   null;
  // };

  // 20260402 gjw We want to ensure Flutter bindings are initialized for async
  // operations particularly to set the Linux desktop window [title] as we do
  // below.

  WidgetsFlutterBinding.ensureInitialized();
  SolidSecurityKeyCentralManager.instance;
  if (isDesktop) {
    await windowManager.ensureInitialized();

    // 20260402 gjw For our desktop app we tune various window oriented
    // settings.

    const windowOptions = WindowOptions(
      title: appTitle,
      minimumSize: Size(500, 800),
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    // 20260402 gjw Now we await the window being shown and receiving the focus,
    // to then proceed to run the app.

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

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
      title: appTitle,
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
        title: appTitle.replaceAll(' - ', '\n'),
        image: const AssetImage('assets/images/app_image.jpg'),
        logo: const AssetImage('assets/images/app_icon.png'),
        link: 'https://github.com/gjwgit/diarypod',
        child: const AppScaffold(),
      ),
    );
  }
}
