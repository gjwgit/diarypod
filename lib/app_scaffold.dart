/// AppScaffold — main SolidScaffold for DiaryPod.
///
// Time-stamp: <Thursday 2026-10-29 12:48:30 +1100 Graham Williams>
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

    // Register a logout hook so that whenever the user logs out — via the app
    // bar OR the status-bar login indicator — the in-memory entries and the
    // one-shot load guard are cleared. Without this, logging back in as a
    // different WebID (without restarting the app) shows the previous user's
    // data because AppProvider lives above the login flow and its loadFromPod
    // is guarded by _hasLoaded.
    SolidAuthHandler.instance.configure(
      SolidAuthConfig(onLogout: provider.reset),
    );

    // Load data from Pod.
    await provider.loadFromPod();
    // Initialise encryption keys.
    try {
      if (!mounted) return;
      // 20261002 gjw Cancel on the security key prompt is not an error, and
      // must not be treated as success.
      //
      // getKeyFromUserIfRequired returns false when the prompt was dismissed
      // (solidui 1.3.0 widened it from void for exactly this). Before that,
      // _isKeySaved was set true unconditionally, so the status bar claimed a
      // cached key that was not there, and the Pod was then read with no key
      // to decrypt it — "You must first set the security key!", once per
      // file.
      //
      // Returning here leaves the user in the app with the prompt dismissed,
      // which is what Cancel should mean. The key can still be entered from
      // the status bar.

      // NOTE diarypod calls loadFromPod() BEFORE this, unlike the other
      // apps, so there is nothing after the prompt to guard — recording the
      // real answer is the whole fix here. That ordering is worth a look
      // separately: it reads the Pod before the key is asked for.

      final hasKey = await getKeyFromUserIfRequired(context, widget);
      if (!mounted) return;
      setState(() => _isKeySaved = hasKey);
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
          - Export and import entries as JSON
          - Import and export Markdown files
          - Security key management for encrypted data
          - Theme switching (light / dark / system)

          For more information, visit the
          [DiaryPod](https://github.com/gjwgit/diarypod) GitHub repository
          and our [Australian Solid Community](https://solidcommunity.au)
          web site.

          ''',
        docsUrl: 'https://gjwgit.github.io/diarypod',
      ),
      themeToggle: const SolidThemeToggleConfig(enabled: true),
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
