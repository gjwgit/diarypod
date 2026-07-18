/// Diary Pod - app-wide constants.
///
// Time-stamp: <Saturday 2026-07-18 11:02:59 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3
///
/// License: https://opensource.org/license/gpl-3-0
//
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
/// Authors: Graham Williams

library;

const String appName = 'DiaryPod';
const String appDir = 'diarypod';

/// Application title displayed as the window title.

const String appTitle = 'DiaryPod - Notes from Meetings';

// ── Nav titles ────────────────────────────────────────────────────────────────

const String listTitle = 'Diary';
const String upcomingTitle = 'Upcoming';
const String calendarTitle = 'Calendar';
const String importExportTitle = 'Export/Import';

// ── Nav tooltips ─────────────────────────────────────────────────────────────

const String listTooltip = '**Diary**\n\nBrowse and search your diary entries.';

const String upcomingTooltip =
    '**Upcoming**\n\nView future diary entries and scheduled events.';

const String calendarTooltip =
    '**Calendar**\n\nView diary entries on a monthly calendar.';

const String importExportTooltip =
    '**Export/Import**\n\n'
    'Export and import all entries as JSON, or view your diary as a PDF, '
    'or import and export Markdown.';

// ── Pod storage ───────────────────────────────────────────────────────────────

const String diaryFileName = 'diary.ttl';
const String diaryFilePathSuffix = '$appDir/$diaryFileName';
