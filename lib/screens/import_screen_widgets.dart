/// Import/Export screen widgets for DiaryPod.
///
// Time-stamp: <2026-04-26>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:printing/printing.dart';

/// Push a full-screen PDF preview of [pdfBytes]. Sharing is replaced with a
/// Save action; [onSaved] is called with the chosen save path (or null on
/// web / cancel) so the caller can show feedback. [title] is the app-bar
/// title and [onSaveAs] performs the actual save.
Future<void> showPdfPreviewPage({
  required BuildContext context,
  required Uint8List pdfBytes,
  required String pdfName,
  required String title,
  required Future<String?> Function(Uint8List bytes, String name) onSaveAs,
  required void Function(String? path) onSaved,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: PdfPreview(
          build: (_) async => pdfBytes,
          pdfFileName: pdfName,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          allowSharing: false,
          actions: [
            PdfPreviewAction(
              icon: const Icon(Icons.save_alt),
              onPressed: (ctx, build, pageFormat) async {
                final bytes = await build(pageFormat);
                final path = await onSaveAs(bytes, pdfName);
                onSaved(path);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class ImportActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onTap;

  const ImportActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
        trailing: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: loading ? null : onTap,
      ),
    );
  }
}

class ImportMessageBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final ColorScheme cs;

  const ImportMessageBanner({
    super.key,
    required this.message,
    required this.isError,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? cs.errorContainer : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? cs.onErrorContainer : cs.onSecondaryContainer,
          ),
          const Gap(8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? cs.onErrorContainer : cs.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
