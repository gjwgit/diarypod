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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/services/app_provider.dart';

class DiaryIO {
  DiaryIO._();

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
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select DiaryPod JSON backup',
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) throw Exception('Could not read file.');
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
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select Org diary file',
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) throw Exception('Could not read file.');
    final incoming = parseOrg(utf8.decode(bytes));
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
    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Save JSON backup',
      fileName: 'diarypod_backup_${_ts()}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (savePath == null) return null;
    await File(savePath).writeAsBytes(utf8.encode(json));
    return savePath;
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
    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Save Markdown file',
      fileName: 'diarypod_diary_${_ts()}.md',
      type: FileType.custom,
      allowedExtensions: ['md'],
    );
    if (savePath == null) return null;
    await File(savePath).writeAsBytes(utf8.encode(buf.toString()));
    return savePath;
  }

  // ── PDF export ─────────────────────────────────────────────────────────────

  static Future<String?> exportPdf(AppProvider provider) async {
    final fmt = DateFormat('EEE d MMM yyyy  HH:mm');
    final now = DateTime.now();
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
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
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
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
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
              pw.Text(e.note, style: const pw.TextStyle(fontSize: 10)),
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
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: pdfName);
      return null; // web: printed via dialog, no file path
    }

    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Save PDF',
      fileName: pdfName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (savePath == null) return null;
    await File(savePath).writeAsBytes(pdfBytes);
    return savePath;
  }
}
