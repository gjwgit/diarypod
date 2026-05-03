/// AppScaffold — main SolidScaffold for DiaryPod.
///
// Time-stamp: <Friday 2026-05-01 14:16:40 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:solidui/solidui.dart';

import 'package:diarypod/constants/app.dart';
import 'package:diarypod/screens/calendar_screen.dart';
import 'package:diarypod/screens/import_screen.dart';
import 'package:diarypod/screens/list_screen.dart';
import 'package:diarypod/screens/upcoming_screen.dart';
import 'package:diarypod/services/app_provider.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _isKeySaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    // Capture context-dependent objects before any await.
    final provider = context.read<AppProvider>();
    // Load data from Pod.
    await provider.loadFromPod();
    // Initialise encryption keys.
    try {
      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);
      if (!mounted) return;
      setState(() => _isKeySaved = true);
    } on Exception catch (e) {
      debugPrint('[AppScaffold] key error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SolidScaffold(
      themeToggle: const SolidThemeToggleConfig(enabled: true),
      appBar: const SolidAppBarConfig(
        title: appName,
        versionConfig: SolidVersionConfig(
          changelogUrl:
              'https://github.com/gjwgit/diarypod/blob/dev/CHANGELOG.md',
        ),
      ),
      menu: const [
        SolidMenuItem(
          title: listTitle,
          icon: Icons.book_outlined,
          tooltip: listTooltip,
          child: ListScreen(),
        ),
        SolidMenuItem(
          title: upcomingTitle,
          icon: Icons.event_outlined,
          tooltip: upcomingTooltip,
          child: UpcomingScreen(),
        ),
        SolidMenuItem(
          title: calendarTitle,
          icon: Icons.calendar_month_outlined,
          tooltip: calendarTooltip,
          child: CalendarScreen(),
        ),
        SolidMenuItem(
          title: importExportTitle,
          icon: Icons.import_export,
          tooltip: importExportTooltip,
          child: ImportScreen(),
        ),
      ],
      statusBar: SolidStatusBarConfig(
        loginStatus: const SolidLoginStatus(),
        serverInfo: const SolidServerInfo(
          serverUri: SolidConfig.defaultServerUrl,
        ),
        securityKeyStatus: SolidSecurityKeyStatus(
          isKeySaved: _isKeySaved,
          title: '$appName Security Keys',
          onKeyStatusChanged: (hasKey) => setState(() => _isKeySaved = hasKey),
        ),
      ),
    );
  }
}
