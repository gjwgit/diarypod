/// ImportScreen — import/export UI for DiaryPod.
///
// Time-stamp: <Saturday 2026-07-18 11:02:04 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:markdown_tooltip/markdown_tooltip.dart';
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
  String? _backupMsg;
  bool _backupError = false;
  String? _viewMsg;
  bool _viewError = false;

  void _setImportMsg(String msg, {bool error = false}) => setState(() {
    _importMsg = msg;
    _importError = error;
  });

  void _setExportMsg(String msg, {bool error = false}) => setState(() {
    _exportMsg = msg;
    _exportError = error;
  });

  void _setBackupMsg(String msg, {bool error = false}) => setState(() {
    _backupMsg = msg;
    _backupError = error;
  });

  void _setViewMsg(String msg, {bool error = false}) => setState(() {
    _viewMsg = msg;
    _viewError = error;
  });

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<void> _importJson(BuildContext ctx, AppProvider provider) async {
    setState(() {
      _loading = true;
      _backupMsg = null;
    });
    try {
      final r = await DiaryIO.importJson(ctx, provider);
      if (r == null) return;
      _setBackupMsg(
        'Restored ${r.added} new entr${r.added == 1 ? 'y' : 'ies'} '
        '(${r.total - r.added} skipped as duplicates).',
      );
    } catch (e) {
      _setBackupMsg('$e', error: true);
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
      _backupMsg = null;
    });
    try {
      final path = await DiaryIO.exportJson(provider);
      _setBackupMsg(
        path != null
            ? 'JSON saved to $path'
            : 'File export is not supported on web.',
        error: path == null,
      );
    } catch (e) {
      _setBackupMsg('JSON export failed: $e', error: true);
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

  Future<void> _viewPdf(BuildContext context, AppProvider provider) async {
    setState(() {
      _loading = true;
      _viewMsg = null;
    });
    try {
      final pdfBytes = await DiaryIO.buildDiaryPdfBytes(provider);
      final pdfName = DiaryIO.diaryPdfName();
      if (!context.mounted) return;
      await showPdfPreviewPage(
        context: context,
        pdfBytes: pdfBytes,
        pdfName: pdfName,
        title: 'Diary',
        onSaveAs: DiaryIO.savePdfBytes,
        onSaved: (path) {
          if (mounted && path != null) _setViewMsg('Saved to $path');
        },
      );
      _setViewMsg('PDF generated.');
    } catch (e) {
      _setViewMsg('PDF generation failed: $e', error: true);
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
            // ── Backup & Restore ────────────────────────────────────────
            Text(
              'Export & Import',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Save a complete JSON version of all your diary entries, or '
              'restore everything from a previously saved JSON file. '
              'Also note the encrypted backup option available through '
              'your profile menu.',

              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (_backupMsg != null) ...[
              const SizedBox(height: 12),
              ImportMessageBanner(
                message: _backupMsg!,
                isError: _backupError,
                cs: cs,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                MarkdownTooltip(
                  message:
                      '**Export JSON**\n\n'
                      'Save all $count entr$ies to a DiaryPod JSON backup '
                      'file on this device. Keep it somewhere safe so you '
                      'can restore everything later.',
                  child: FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Export JSON'),
                    onPressed: _loading ? null : () => _exportJson(provider),
                  ),
                ),
                const SizedBox(width: 12),
                MarkdownTooltip(
                  message:
                      '**Import JSON**\n\n'
                      'Restore diary entries from a previously saved DiaryPod '
                      'JSON backup file. Restored entries are merged with '
                      'your existing diary.',
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload),
                    label: const Text('Import JSON'),
                    onPressed: _loading
                        ? null
                        : () => _importJson(context, provider),
                  ),
                ),
              ],
            ),

            // ── View ────────────────────────────────────────────────────
            const SizedBox(height: 32),
            Text('View', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'View your diary as a PDF on screen. You can save or print '
              'from the preview.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (_viewMsg != null) ...[
              const SizedBox(height: 12),
              ImportMessageBanner(
                message: _viewMsg!,
                isError: _viewError,
                cs: cs,
              ),
            ],
            const SizedBox(height: 16),
            ImportActionCard(
              icon: Icons.picture_as_pdf_outlined,
              title: 'View as PDF',
              subtitle: 'View all $count entr$ies as a PDF.',
              loading: _loading,
              onTap: () => _viewPdf(context, provider),
            ),

            // ── Export ──────────────────────────────────────────────────
            const SizedBox(height: 32),
            Text('Export', style: Theme.of(context).textTheme.titleLarge),
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
              'Save a timestamped copy of your diary as Markdown.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ImportActionCard(
              icon: Icons.description_outlined,
              title: 'Export to Markdown',
              subtitle: 'Save all $count entr$ies as a single .md file.',
              loading: _loading,
              onTap: () => _exportMarkdown(provider),
            ),

            // ── Import ──────────────────────────────────────────────────
            const SizedBox(height: 32),
            Text('Import', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Import diary entries from an org-mode file. Imported entries '
              'are merged with your existing diary.',
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
              title: 'Import from Org file',
              subtitle:
                  'Select an org-mode file with headings like:\n'
                  '* 20260424_1400 Fri Title here',
              loading: _loading,
              onTap: () => _importOrg(context, provider),
            ),
          ],
        ),
      ),
    );
  }
}
