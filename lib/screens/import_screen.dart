/// ImportScreen — import from JSON and export to JSON, Markdown and PDF.
///
// Time-stamp: <2026-04-26>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:uuid/uuid.dart';

import 'package:diarypod/models/diary_entry.dart';
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

  String _ts() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  // ── Import JSON ─────────────────────────────────────────────────────────────

  Future<void> _importJson(BuildContext context, AppProvider provider) async {
    setState(() {
      _loading = true;
      _importMsg = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select DiaryPod JSON backup',
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _setImportMsg('Could not read file.', error: true);
        setState(() => _loading = false);
        return;
      }
      final List<dynamic> raw = jsonDecode(utf8.decode(bytes));
      final incoming =
          raw.map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>)).toList();
      if (incoming.isEmpty) {
        _setImportMsg('No entries found in "${file.name}".', error: true);
        setState(() => _loading = false);
        return;
      }
      final added = provider.importEntries(incoming);
      await provider.saveToPod();
      _setImportMsg(
        'Imported $added new entr${added == 1 ? 'y' : 'ies'} '
        '(${incoming.length - added} skipped as duplicates).',
      );
    } catch (e, st) {
      debugPrint('[Import JSON] $e\n$st');
      _setImportMsg('Import failed: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Import Org ──────────────────────────────────────────────────────────────

  /// Parses an org-mode diary file.
  ///
  /// Each heading must start with `* YYYYMMDD_HHMM DAYNAME REST` where REST
  /// becomes the entry title.  Lines between headings become the note.
  static List<DiaryEntry> _parseOrg(String content) {
    final headingRe = RegExp(
      r'^\*+\s+(\d{8})_(\d{4})\s+\w{2,4}\s+(.*)',
    );
    final entries = <DiaryEntry>[];
    DiaryEntry? current;
    final noteLines = <String>[];

    void flush() {
      if (current == null) return;
      final note = noteLines
          .join('\n')
          .trim()
          .replaceAll(RegExp(r'\n{3,}'), '\n\n');
      entries.add(current!.copyWith(note: note));
      current = null;
      noteLines.clear();
    }

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trimRight();
      final m = headingRe.firstMatch(line);
      if (m != null) {
        flush();
        final datePart = m.group(1)!; // YYYYMMDD
        final timePart = m.group(2)!; // HHMM
        final title = m.group(3)!.trim();
        final year = int.parse(datePart.substring(0, 4));
        final month = int.parse(datePart.substring(4, 6));
        final day = int.parse(datePart.substring(6, 8));
        final hour = int.parse(timePart.substring(0, 2));
        final minute = int.parse(timePart.substring(2, 4));
        final eventDate = DateTime(year, month, day, hour, minute);
        final now = DateTime.now();
        current = DiaryEntry(
          id: const Uuid().v4(),
          eventDate: eventDate,
          title: title,
          createdAt: now,
          modifiedAt: now,
        );
      } else if (current != null) {
        // Skip org directives / property drawers.
        if (!line.startsWith('#+') &&
            !line.startsWith(':') &&
            !(line.startsWith('#') && line.length < 3)) {
          noteLines.add(line);
        }
      }
    }
    flush();
    return entries;
  }

  Future<void> _importOrg(BuildContext context, AppProvider provider) async {
    setState(() {
      _loading = true;
      _importMsg = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Org diary file',
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _setImportMsg('Could not read file.', error: true);
        setState(() => _loading = false);
        return;
      }
      final incoming = _parseOrg(utf8.decode(bytes));
      if (incoming.isEmpty) {
        _setImportMsg(
          'No diary entries found in "${file.name}".\n'
          'Expected headings like: * 20260424_1400 Fri Title here',
          error: true,
        );
        setState(() => _loading = false);
        return;
      }
      final added = provider.importEntries(incoming);
      await provider.saveToPod();
      final plural = added == 1 ? 'y' : 'ies';
      _setImportMsg(
        'Imported $added entr$plural from "${file.name}" '
        '(${incoming.length - added} skipped as duplicates).',
      );
    } catch (e, st) {
      debugPrint('[Import Org] $e\n$st');
      _setImportMsg('Import failed: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Export JSON ─────────────────────────────────────────────────────────────

  Future<void> _exportJson(AppProvider provider) async {
    setState(() {
      _loading = true;
      _exportMsg = null;
    });
    try {
      final json = const JsonEncoder.withIndent('  ')
          .convert(provider.entries.map((e) => e.toJson()).toList());
      final bytes = utf8.encode(json);
      final fileName = 'diarypod_backup_${_ts()}.json';
      if (kIsWeb) {
        _setExportMsg('File export is not supported on web.', error: true);
        return;
      }
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save JSON backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (savePath != null) {
        await File(savePath).writeAsBytes(bytes);
        _setExportMsg('Saved to $savePath');
      }
    } catch (e, st) {
      debugPrint('[Export JSON] $e\n$st');
      _setExportMsg('Export failed: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Export Markdown ─────────────────────────────────────────────────────────

  Future<void> _exportMarkdown(AppProvider provider) async {
    setState(() {
      _loading = true;
      _exportMsg = null;
    });
    try {
      final dateFmt = DateFormat('EEE d MMM yyyy  HH:mm');
      final buf = StringBuffer();
      for (final e in provider.entries) {
        buf.writeln('# ${e.title}');
        buf.writeln();
        buf.writeln('**Date:** ${dateFmt.format(e.eventDate)}');
        if (e.location != null) buf.writeln('**Location:** ${e.location}');
        if (e.tags.isNotEmpty) {
          buf.writeln('**Tags:** ${e.tags.join(', ')}');
        }
        buf.writeln();
        if (e.hasNote) {
          buf.writeln(e.note);
          buf.writeln();
        }
        buf.writeln('---');
        buf.writeln();
      }
      final bytes = utf8.encode(buf.toString());
      final fileName = 'diarypod_diary_${_ts()}.md';
      if (kIsWeb) {
        _setExportMsg('File export is not supported on web.', error: true);
        return;
      }
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Markdown file',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['md'],
      );
      if (savePath != null) {
        await File(savePath).writeAsBytes(bytes);
        _setExportMsg('Saved to $savePath');
      }
    } catch (e, st) {
      debugPrint('[Export MD] $e\n$st');
      _setExportMsg('Export failed: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Export PDF ──────────────────────────────────────────────────────────────

  Future<void> _exportPdf(AppProvider provider) async {
    setState(() {
      _loading = true;
      _exportMsg = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('d MMMM yyyy').format(now);
      final dateFmt = DateFormat('EEE d MMM yyyy  HH:mm');
      final entries = provider.entries;
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'DiaryPod - Diary Export',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Generated $dateStr  -  '
                '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Divider(),
              pw.SizedBox(height: 4),
            ],
          ),
          build: (_) => [
            for (final e in entries) ...[
              pw.Text(
                e.title,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                dateFmt.format(e.eventDate),
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              if (e.location != null)
                pw.Text(
                  'Location: ${e.location}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              if (e.tags.isNotEmpty)
                pw.Text(
                  'Tags: ${e.tags.join(', ')}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              if (e.hasNote) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  e.note,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
            ],
          ],
        ),
      );

      final pdfBytes = await doc.save();
      final pdfName = 'diarypod_diary_${_ts()}.pdf';

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: pdfName,
        );
        _setExportMsg('PDF ready - use the dialog to save or print.');
        return;
      }
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF',
        fileName: pdfName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (savePath != null) {
        await File(savePath).writeAsBytes(pdfBytes);
        _setExportMsg('Saved to $savePath');
      }
    } catch (e, st) {
      debugPrint('[Export PDF] $e\n$st');
      messenger.showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final count = provider.entries.length;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Import ─────────────────────────────────────────────────
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

            // ── Export ─────────────────────────────────────────────────
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
              subtitle:
                  'Saves all $count entr${count == 1 ? 'y' : 'ies'} as a JSON backup.',
              loading: _loading,
              onTap: () => _exportJson(provider),
            ),
            const SizedBox(height: 12),
            ImportActionCard(
              icon: Icons.description_outlined,
              title: 'Export to Markdown',
              subtitle:
                  'Save all $count entr${count == 1 ? 'y' : 'ies'} as a single .md file.',
              loading: _loading,
              onTap: () => _exportMarkdown(provider),
            ),
            const SizedBox(height: 12),
            ImportActionCard(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Export to PDF',
              subtitle:
                  'Save or print all $count entr${count == 1 ? 'y' : 'ies'} as a PDF.',
              loading: _loading,
              onTap: () => _exportPdf(provider),
            ),
          ],
        ),
      ),
    );
  }
}
