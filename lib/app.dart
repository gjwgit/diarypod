/// DiaryPod — the primary [MaterialApp] widget.
///
// Time-stamp: <Friday 2026-07-17 11:57:42 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
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
// this program. If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Graham Williams

library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:solidui/solidui.dart';

import 'package:diarypod/app_scaffold.dart';
import 'package:diarypod/constants/app.dart';

// 20260429 gjw This widget is the root of the application. On startup it will
// call upon [SolidLogin] to connect to the user's Pod stored within the user's
// data vault on their chosen Solid server.

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => AppState();
}

class AppState extends State<App> {
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
        clientId: 'https://gjwgit.github.io/diarypod/client-profile.jsonld',
        redirectUris: kIsWeb
            ? ['${Uri.base.origin}/redirect.html']
            : const [
                'com.togaware.diarypod://redirect',
                'http://localhost:4400/redirect.html',
              ],
        child: const SolidWriteFailureListener(child: AppScaffold()),
      ),
    );
  }
}
