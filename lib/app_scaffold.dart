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
import 'package:diarypod/widgets/pod_refresh_action.dart';

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
      aboutConfig: SolidAboutConfig(
        applicationName: appName,
        applicationIcon: Image.asset(
          'assets/images/app_icon.png',
          width: 64,
          height: 64,
        ),
        applicationLegalese: '''

          © 2026 Togaware Pty Ltd

          ''',
        text: '''

          DiaryPod is a personal diary and meeting-notes manager that stores
          your entries encrypted in your personal Solid Pod, so your data
          stays under your control. Your Solid Pod can be hosted on any Solid
          server and being encrypted it is protected against casual access by
          anyone, including the server administrators.

          ### Key features

          - Browse and search diary entries by title, tag, or date
          - Upcoming view of future entries and scheduled events
          - Monthly calendar view with entries marked
          - Markdown notes with inline preview
          - Tags for categorising entries
          - PDF export of your diary for any date range
          - Backup and restore all entries as JSON
          - Import and export Markdown files
          - Security key management for encrypted data
          - Theme switching (light / dark / system)

          For more information, visit the
          [DiaryPod](https://github.com/gjwgit/diarypod) GitHub repository
          and our [Australian Solid Community](https://solidcommunity.au)
          web site.

          ''',
        readmeUrl: 'https://gjwgit.github.io/diarypod',
      ),
      themeToggle: const SolidThemeToggleConfig(enabled: true),
      onLogout: (context) {
        // Clear the previous user's in-memory entries (and the load guard) so
        // logging in as a different WebID does not show stale data, then run
        // the standard solidui logout flow.
        context.read<AppProvider>().reset();
        SolidAuthHandler.instance.handleLogout(context);
      },
      appBar: SolidAppBarConfig(
        title: appName,
        versionConfig: const SolidVersionConfig(
          changelogUrl:
              'https://github.com/gjwgit/diarypod/blob/dev/CHANGELOG.md',
        ),
        actions: [
          buildPodRefreshAction(
            context: context,
            onRefresh: context.read<AppProvider>().refreshFromPod,
          ),
        ],
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
          icon: Icons.save_alt,
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
