/// DiaryIO — static import/export helpers for DiaryPod.
///
// Time-stamp: <Thursday 2026-04-30 12:33:10 +1000 Graham Williams>
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
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/screens/diary_pdf_markdown.dart';
import 'package:diarypod/services/app_provider.dart';

class DiaryIO {
  DiaryIO._();

  /// Create a [pw.Document] with Noto Sans as the default font.
  /// Noto Sans supports the full Unicode range including bullet characters
  /// and avoids the "Helvetica has no Unicode support" warnings.
  static Future<pw.Document> _makeDoc() async {
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();
    final boldItalic = await PdfGoogleFonts.notoSansBoldItalic();
    return pw.Document(
      theme: pw.ThemeData.withFont(
        base: base,
        bold: bold,
        italic: italic,
        boldItalic: boldItalic,
      ),
    );
  }

  static String _ts() {
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${p(n.month)}${p(n.day)}_${p(n.hour)}${p(n.minute)}';
  }

  // ── JSON import ────────────────────────────────────────────────────────────

  static Future<({int added, int total, String name})?> importJson(
    BuildContext context,
    AppProvider provider,
  ) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Select DiaryPod JSON backup',
      type: FileType.any,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final raw = jsonDecode(utf8.decode(bytes)) as List<dynamic>;
    final incoming = raw
        .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    if (incoming.isEmpty) {
      throw Exception('No entries found in "${file.name}".');
    }
    final added = provider.importEntries(incoming);
    await provider.saveToPod();
    return (added: added, total: incoming.length, name: file.name);
  }

  // ── Org import ─────────────────────────────────────────────────────────────

  static List<DiaryEntry> parseOrg(String content) {
    final re = RegExp(r'^\*+\s+(\d{8})_(\d{4})\s+\w{2,4}\s+(.*)');
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
      final m = re.firstMatch(line);
      if (m != null) {
        flush();
        final dp = m.group(1)!;
        final tp = m.group(2)!;
        final now = DateTime.now();
        current = DiaryEntry(
          id: const Uuid().v4(),
          eventDate: DateTime(
            int.parse(dp.substring(0, 4)),
            int.parse(dp.substring(4, 6)),
            int.parse(dp.substring(6, 8)),
            int.parse(tp.substring(0, 2)),
            int.parse(tp.substring(2, 4)),
          ),
          title: m.group(3)!.trim(),
          createdAt: now,
          modifiedAt: now,
        );
      } else if (current != null) {
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

  static Future<({int added, int total, String name})?> importOrg(
    BuildContext context,
    AppProvider provider,
  ) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Select Org diary file',
      type: FileType.any,
    );
    if (file == null) return null;
    final incoming = parseOrg(utf8.decode(await file.readAsBytes()));
    if (incoming.isEmpty) {
      throw Exception(
        'No diary entries found in "${file.name}".\n'
        'Expected headings like: * 20260424_1400 Fri Title here',
      );
    }
    final added = provider.importEntries(incoming);
    await provider.saveToPod();
    return (added: added, total: incoming.length, name: file.name);
  }

  // ── JSON export ────────────────────────────────────────────────────────────

  static Future<String?> exportJson(AppProvider provider) async {
    if (kIsWeb) return null;
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(provider.entries.map((e) => e.toJson()).toList());
    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Save JSON backup',
      fileName: 'diarypod_backup_${_ts()}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(json),
    );
    if (savedUri == null) return null;
    return _displayPath(savedUri);
  }

  // ── Markdown export ────────────────────────────────────────────────────────

  static Future<String?> exportMarkdown(AppProvider provider) async {
    if (kIsWeb) return null;
    final fmt = DateFormat('EEE d MMM yyyy  HH:mm');
    final buf = StringBuffer();
    for (final e in provider.entries) {
      buf.writeln('# ${e.title}');
      buf.writeln();
      buf.writeln('**Date:** ${fmt.format(e.eventDate)}');
      if (e.location != null) buf.writeln('**Location:** ${e.location}');
      if (e.tags.isNotEmpty) buf.writeln('**Tags:** ${e.tags.join(', ')}');
      buf.writeln();
      if (e.hasNote) {
        buf.writeln(e.note);
        buf.writeln();
      }
      buf.writeln('---');
      buf.writeln();
    }
    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Save Markdown file',
      fileName: 'diarypod_diary_${_ts()}.md',
      type: FileType.custom,
      allowedExtensions: ['md'],
      bytes: utf8.encode(buf.toString()),
    );
    if (savedUri == null) return null;
    return _displayPath(savedUri);
  }

  // ── Single-entry PDF ────────────────────────────────────────────────────────

  /// Generate a PDF for a single [entry], open it in the system PDF viewer,
  /// and (on non-web platforms) offer a separate Save dialog after the viewer
  /// closes if the user chooses to keep a copy.
  static Future<void> entryPdf(BuildContext context, DiaryEntry entry) async {
    final fmt = DateFormat('EEE d MMM yyyy  HH:mm');
    final doc = await _makeDoc();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => [
          pw.Text(
            entry.title,
            style: const pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            fmt.format(entry.eventDate),
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          if (entry.location != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Location: ${entry.location}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ],
          if (entry.tags.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Tags: ${entry.tags.join(', ')}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
            ),
          ],
          if (entry.hasNote) ...[
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            // Render note as formatted markdown (headings, bold, italic,
            // lists, code blocks, blockquotes, etc.)
            ...markdownToPdf(entry.note),
          ],
        ],
      ),
    );

    final pdfBytes = await doc.save();
    final safeName = entry.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '')
        .trim()
        .replaceAll(' ', '_')
        .toLowerCase();
    final pdfName = 'diarypod_${safeName}_${_ts()}.pdf';

    if (kIsWeb) {
      // Web: use the print/preview dialog — no temp file available.
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: pdfName);
      return;
    }

    // Write to a temp file and open in the system PDF viewer.
    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File('${tmpDir.path}/$pdfName');
    await tmpFile.writeAsBytes(pdfBytes);
    final result = await OpenFilex.open(tmpFile.path);

    if (!context.mounted) return;
    if (result.type != ResultType.done) {
      // Viewer not available — fall back to save dialog.
      _showSaveError(context, result.message, pdfBytes, pdfName);
    }
  }

  /// Show an error with option to save directly when the viewer failed.
  static Future<void> _showSaveError(
    BuildContext context,
    String message,
    List<int> pdfBytes,
    String pdfName,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Could not open viewer'),
        content: Text(
          '$message\n\nWould you like to save the PDF to a file instead?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _saveFile(context, pdfBytes, pdfName);
            },
            child: const Text('Save file'),
          ),
        ],
      ),
    );
  }

  /// Save [pdfBytes] to a user-chosen path via [FilePicker].
  static Future<void> _saveFile(
    BuildContext context,
    List<int> pdfBytes,
    String pdfName,
  ) async {
    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Save PDF',
      fileName: pdfName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: Uint8List.fromList(pdfBytes),
    );
    if (savedUri == null) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to ${_displayPath(savedUri)}')),
    );
  }

  // ── PDF export ─────────────────────────────────────────────────────────────

  /// Build the diary PDF bytes for all entries in [provider]. Used by the
  /// View section to show an in-app preview.
  static Future<Uint8List> buildDiaryPdfBytes(AppProvider provider) async {
    final fmt = DateFormat('EEE d MMM yyyy  HH:mm');
    final now = DateTime.now();
    final entries = provider.entries;
    final doc = await _makeDoc();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'DiaryPod - Diary Export',
              style: const pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Generated ${DateFormat('d MMMM yyyy').format(now)}  -  '
              '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Divider(),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (_) => [
          for (final e in entries) ...[
            pw.Text(
              e.title,
              style: const pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              fmt.format(e.eventDate),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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
              ...markdownToPdf(e.note),
            ],
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );

    return doc.save();
  }

  /// Default filename for a full-diary PDF export.
  static String diaryPdfName() => 'diarypod_diary_${_ts()}.pdf';

  /// Save [pdfBytes] to a user-chosen file. Returns the saved path, or null
  /// if cancelled or on web (where it falls back to the print/share sheet).
  static Future<String?> savePdfBytes(
    Uint8List pdfBytes,
    String pdfName,
  ) async {
    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: pdfName);
      return null;
    }
    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Save PDF',
      fileName: pdfName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: pdfBytes,
    );
    if (savedUri == null) return null;
    return _displayPath(savedUri);
  }

  /// The path to show the user for a [uri] returned by the file picker.
  ///
  /// file_picker writes the bytes itself and hands back a URI, whose scheme
  /// varies by platform. A `file:` URI is converted back to a native path;
  /// anything else (`content:` on Android, `blob:` on the web) is shown as is.
  static String _displayPath(Uri uri) =>
      uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
}
