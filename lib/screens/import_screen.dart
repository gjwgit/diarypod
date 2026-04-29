/// ImportScreen — import/export UI for DiaryPod.
///
// Time-stamp: <2026-04-30>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:diarypod/screens/diary_io.dart';
import 'package:diarypod/screens/import_screen_widgets.dart';
import 'package:diarypod/services/app_provider.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _loading = false;
  String? _importMsg;
  bool _importError = false;
  String? _exportMsg;
  bool _exportError = false;

  void _setImportMsg(String msg, {bool error = false}) => setState(() {
    _importMsg = msg;
    _importError = error;
  });

  void _setExportMsg(String msg, {bool error = false}) => setState(() {
    _exportMsg = msg;
    _exportError = error;
  });

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<void> _importJson(BuildContext ctx, AppProvider provider) async {
    setState(() {
      _loading = true;
      _importMsg = null;
    });
    try {
      final r = await DiaryIO.importJson(ctx, provider);
      if (r == null) return;
      _setImportMsg(
        'Imported ${r.added} new entr${r.added == 1 ? 'y' : 'ies'} '
        '(${r.total - r.added} skipped as duplicates).',
      );
    } catch (e) {
      _setImportMsg('$e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _importOrg(BuildContext ctx, AppProvider provider) async {
    setState(() {
      _loading = true;
      _importMsg = null;
    });
    try {
      final r = await DiaryIO.importOrg(ctx, provider);
      if (r == null) return;
      final plural = r.added == 1 ? 'y' : 'ies';
      _setImportMsg(
        'Imported ${r.added} entr$plural from "${r.name}" '
        '(${r.total - r.added} skipped as duplicates).',
      );
    } catch (e) {
      _setImportMsg('$e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  Future<void> _exportJson(AppProvider provider) async {
    setState(() {
      _loading = true;
      _exportMsg = null;
    });
    try {
      final path = await DiaryIO.exportJson(provider);
      _setExportMsg(
        path != null
            ? 'Saved to $path'
            : 'File export is not supported on web.',
        error: path == null,
      );
    } catch (e) {
      _setExportMsg('Export failed: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _exportMarkdown(AppProvider provider) async {
    setState(() {
      _loading = true;
      _exportMsg = null;
    });
    try {
      final path = await DiaryIO.exportMarkdown(provider);
      _setExportMsg(
        path != null
            ? 'Saved to $path'
            : 'File export is not supported on web.',
        error: path == null,
      );
    } catch (e) {
      _setExportMsg('Export failed: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf(AppProvider provider) async {
    setState(() {
      _loading = true;
      _exportMsg = null;
    });
    try {
      final path = await DiaryIO.exportPdf(provider);
      _setExportMsg(
        path != null
            ? 'Saved to $path'
            : 'PDF ready - use the dialog to save or print.',
      );
    } catch (e) {
      _setExportMsg('PDF export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final count = provider.entries.length;
    final ies = count == 1 ? 'y' : 'ies';

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Import diary entries from a JSON backup or org-mode file. '
              'Imported entries are merged with your existing diary.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (_importMsg != null) ...[
              const SizedBox(height: 12),
              ImportMessageBanner(
                message: _importMsg!,
                isError: _importError,
                cs: cs,
              ),
            ],
            const SizedBox(height: 16),
            ImportActionCard(
              icon: Icons.upload_file_outlined,
              title: 'Import from JSON',
              subtitle: 'Select a DiaryPod JSON backup file to import.',
              loading: _loading,
              onTap: () => _importJson(context, provider),
            ),
            const SizedBox(height: 12),
            ImportActionCard(
              icon: Icons.upload_file_outlined,
              title: 'Import from Org file',
              subtitle:
                  'Select an org-mode file with headings like:\n'
                  '* 20260424_1400 Fri Title here',
              loading: _loading,
              onTap: () => _importOrg(context, provider),
            ),
            const SizedBox(height: 32),
            Text(
              'Export / Backup',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_exportMsg != null) ...[
              const SizedBox(height: 12),
              ImportMessageBanner(
                message: _exportMsg!,
                isError: _exportError,
                cs: cs,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Save a timestamped backup of your diary.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ImportActionCard(
              icon: Icons.download_outlined,
              title: 'Export to JSON',
              subtitle: 'Saves all $count entr$ies as a JSON backup.',
              loading: _loading,
              onTap: () => _exportJson(provider),
            ),
            const SizedBox(height: 12),
            ImportActionCard(
              icon: Icons.description_outlined,
              title: 'Export to Markdown',
              subtitle: 'Save all $count entr$ies as a single .md file.',
              loading: _loading,
              onTap: () => _exportMarkdown(provider),
            ),
            const SizedBox(height: 12),
            ImportActionCard(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Export to PDF',
              subtitle: 'Save or print all $count entr$ies as a PDF.',
              loading: _loading,
              onTap: () => _exportPdf(provider),
            ),
          ],
        ),
      ),
    );
  }
}
