/// UpcomingScreen — shows diary entries with future event dates.
///
// Time-stamp: <2026-04-26>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:diarypod/screens/list_screen.dart';
import 'package:diarypod/services/app_provider.dart';

/// Thin wrapper around [ListScreen] defaulting to the upcoming filter.
class UpcomingScreen extends ListScreen {
  const UpcomingScreen({super.key})
    : super(initialFilter: DiaryTimeFilter.upcoming);
}
