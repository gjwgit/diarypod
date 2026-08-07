/// UnsavedChangesGuard — lets an open editor register a check so a
/// whole-window close can be paused to save/discard/keep-editing.
///
// Time-stamp: <Saturday 2026-08-08 10:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

/// Resolves whether it is safe to proceed with closing: `true` once any
/// unsaved changes have been saved or discarded, `false` if the user chose
/// to keep editing (the close should be aborted).
typedef UnsavedChangesResolver = Future<bool> Function();

/// A page with unsaved changes (e.g. `EntryEdit`) registers a resolver on
/// mount and removes it on dispose. [resolveAll] runs each registered
/// resolver, most-recently-opened first, so a window-close listener can ask
/// every open editor before the app actually quits.
class UnsavedChangesGuard {
  UnsavedChangesGuard._();

  static final List<UnsavedChangesResolver> _resolvers = [];

  static void register(UnsavedChangesResolver resolver) =>
      _resolvers.add(resolver);

  static void unregister(UnsavedChangesResolver resolver) =>
      _resolvers.remove(resolver);

  /// Runs each registered resolver, most-recently-registered first, stopping
  /// as soon as one reports "keep editing".
  static Future<bool> resolveAll() async {
    for (final resolver in _resolvers.reversed.toList()) {
      if (!await resolver()) return false;
    }
    return true;
  }
}
