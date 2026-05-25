/// Markdown to PDF widget converter for DiaryPod.
///
/// Converts a markdown string into a list of [pw.Widget] objects suitable
/// for use inside a [pw.MultiPage] build function. Handles the common
/// elements used in diary notes: headings, paragraphs, bold/italic inline
/// styles, bullet lists, ordered lists, code blocks, blockquotes, and
/// horizontal rules.
///
// Time-stamp: <2026-05-25>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Convert [markdownText] to a list of [pw.Widget]s for use in a PDF page.
List<pw.Widget> markdownToPdf(String markdownText) {
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
  ).parse(markdownText);
  return nodes.map(_blockNode).expand((w) => w).toList();
}

// ── Block-level nodes ─────────────────────────────────────────────────────────

List<pw.Widget> _blockNode(md.Node node) {
  if (node is md.Element) {
    switch (node.tag) {
      case 'h1':
        return [
          pw.SizedBox(height: 8),
          pw.Text(
            _plainText(node),
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 4),
        ];
      case 'h2':
        return [
          pw.SizedBox(height: 6),
          pw.Text(
            _plainText(node),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 3),
        ];
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return [
          pw.SizedBox(height: 4),
          pw.Text(
            _plainText(node),
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 2),
        ];
      case 'p':
        return [
          pw.Paragraph(
            text: '', // placeholder — we use RichText instead for inline styles
            margin: pw.EdgeInsets.zero,
          ),
          pw.RichText(
            text: pw.TextSpan(children: _inlineSpans(node.children ?? [])),
          ),
          pw.SizedBox(height: 6),
        ]..removeAt(0); // drop the empty Paragraph placeholder
      case 'ul':
        return _listItems(node, ordered: false);
      case 'ol':
        return _listItems(node, ordered: true);
      case 'blockquote':
        return [
          pw.Container(
            margin: const pw.EdgeInsets.only(left: 10, bottom: 6),
            padding: const pw.EdgeInsets.only(left: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.grey400, width: 3),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final child in node.children ?? []) ..._blockNode(child),
              ],
            ),
          ),
        ];
      case 'pre':
        // Code block — child is a <code> element.
        final codeNode = (node.children ?? [])
            .whereType<md.Element>()
            .firstWhere((e) => e.tag == 'code', orElse: () => node);
        return [
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              _plainText(codeNode),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ];
      case 'hr':
        return [
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 4),
        ];
      default:
        // Unknown block — render as paragraph.
        final text = _plainText(node).trim();
        if (text.isEmpty) return [pw.SizedBox(height: 4)];
        return [
          pw.Paragraph(
            text: text,
            style: const pw.TextStyle(fontSize: 11),
            margin: const pw.EdgeInsets.only(bottom: 4),
          ),
        ];
    }
  }
  // Text node at block level (rare).
  if (node is md.Text) {
    final text = node.textContent.trim();
    if (text.isEmpty) return [];
    return [
      pw.Paragraph(
        text: text,
        style: const pw.TextStyle(fontSize: 11),
        margin: const pw.EdgeInsets.only(bottom: 4),
      ),
    ];
  }
  return [];
}

// ── List items ────────────────────────────────────────────────────────────────

List<pw.Widget> _listItems(md.Element list, {required bool ordered}) {
  final items = (list.children ?? [])
      .whereType<md.Element>()
      .where((e) => e.tag == 'li')
      .toList();
  final widgets = <pw.Widget>[];
  for (var i = 0; i < items.length; i++) {
    final bullet = ordered ? '${i + 1}.' : '•';
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12, bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 16,
              child: pw.Text(bullet, style: const pw.TextStyle(fontSize: 11)),
            ),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  children: _inlineSpans(items[i].children ?? []),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  widgets.add(pw.SizedBox(height: 4));
  return widgets;
}

// ── Inline spans ──────────────────────────────────────────────────────────────

const _baseStyle = pw.TextStyle(fontSize: 11);

List<pw.InlineSpan> _inlineSpans(
  List<md.Node> nodes, {
  bool bold = false,
  bool italic = false,
  bool code = false,
}) {
  final spans = <pw.InlineSpan>[];
  for (final node in nodes) {
    if (node is md.Text) {
      spans.add(
        pw.TextSpan(
          text: node.textContent,
          style: _buildStyle(bold: bold, italic: italic, code: code),
        ),
      );
    } else if (node is md.Element) {
      switch (node.tag) {
        case 'strong':
          spans.addAll(
            _inlineSpans(
              node.children ?? [],
              bold: true,
              italic: italic,
              code: code,
            ),
          );
        case 'em':
          spans.addAll(
            _inlineSpans(
              node.children ?? [],
              bold: bold,
              italic: true,
              code: code,
            ),
          );
        case 'code':
          spans.addAll(
            _inlineSpans(
              node.children ?? [],
              bold: bold,
              italic: italic,
              code: true,
            ),
          );
        case 'a':
          // Render links as underlined text — PDF links need special handling.
          spans.add(
            pw.TextSpan(
              text: _plainText(node),
              style: _buildStyle(
                bold: bold,
                italic: italic,
                code: code,
              ).copyWith(color: PdfColors.blue700),
            ),
          );
        case 'br':
          spans.add(const pw.TextSpan(text: '\n'));
        default:
          spans.addAll(
            _inlineSpans(
              node.children ?? [],
              bold: bold,
              italic: italic,
              code: code,
            ),
          );
      }
    }
  }
  return spans;
}

pw.TextStyle _buildStyle({
  required bool bold,
  required bool italic,
  required bool code,
}) {
  if (code) {
    return pw.TextStyle(
      fontSize: 9,
      fontBold: code ? null : null, // monospace handled by background only
      color: PdfColors.grey800,
      background: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }
  if (bold && italic) {
    return pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      fontStyle: pw.FontStyle.italic,
    );
  }
  if (bold) return _baseStyle.copyWith(fontWeight: pw.FontWeight.bold);
  if (italic) {
    return pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic);
  }
  return _baseStyle;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Extract plain text content from a node (strips all inline markup).
String _plainText(md.Node node) {
  if (node is md.Text) return node.textContent;
  if (node is md.Element) {
    return (node.children ?? []).map(_plainText).join();
  }
  return '';
}
