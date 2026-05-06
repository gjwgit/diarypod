/// Tooltip strings for DiaryPod — kept here so long help text does not
/// inflate the line count of widget files.
///
// Time-stamp: <Thursday 2026-04-30 09:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

// ── Entry edit ────────────────────────────────────────────────────────────────

const entryDateTooltip =
    '**Date & Time**\n\n'
    'The date and time of this event. '
    'Future dates mark the entry as scheduled.';

const entryTitleTooltip = '**Title**\n\nA short headline for this diary entry.';

const entryNotesTooltip =
    '**Notes — Emacs keys**\n\n'
    '**Move:** C-a/e line · C-f/b char · C-n/p line · M-f/b word\n\n'
    '**Edit:** C-d del · M-d/M-BS kill-word · C-k kill-line '
    '· C-w kill-sel · C-y yank · M-Enter bullet\n\n'
    '**Chords:** C-c d insert date (yyyymmdd) · C-x C-s save entry\n\n'
    '**Other:** C-g deselect · C-z/C-/ undo';

const entryTagsTooltip =
    '**Tags**\n\n'
    'Keywords to categorise this entry. '
    'Use tag:health in the search bar to filter by tag.';

const entryLocationTooltip =
    '**Location**\n\nOptional venue or place for this event.';
