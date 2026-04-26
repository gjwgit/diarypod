/// App-wide constants for DairyPod.
///
// Time-stamp: <2026-04-26>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

const String appName = 'DiaryPod';
const String appDir = 'diarypod';

// ── Nav titles ────────────────────────────────────────────────────────────────

const String listTitle = 'Diary';
const String upcomingTitle = 'Upcoming';
const String calendarTitle = 'Calendar';
const String importExportTitle = 'Import / Export';

// ── Nav tooltips ─────────────────────────────────────────────────────────────

const String listTooltip = '**Diary**\n\nBrowse and search your diary entries.';

const String upcomingTooltip =
    '**Upcoming**\n\nView future diary entries and scheduled events.';

const String calendarTooltip =
    '**Calendar**\n\nView diary entries on a monthly calendar.';

const String importExportTooltip =
    '**Import / Export**\n\n'
    'Import entries from a JSON backup, or export your diary '
    'to JSON, Markdown, or PDF.';

// ── Pod storage ───────────────────────────────────────────────────────────────

const String diaryFileName = 'diary.ttl';
const String diaryFilePathSuffix = '$appDir/$diaryFileName';
