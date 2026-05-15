/// Tag input widget with autocomplete for DiaryPod.
///
// Time-stamp: <2026-05-15>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

/// A labelled section header with an optional [MarkdownTooltip] info icon.
Widget editSectionLabel(BuildContext context, String text, {String? tooltip}) {
  final label = Text(
    text,
    style: TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
      fontSize: 13,
      letterSpacing: 0.5,
    ),
  );
  if (tooltip == null) return label;
  return Row(
    children: [
      label,
      const Gap(4),
      MarkdownTooltip(
        message: tooltip,
        child: Icon(
          Icons.info_outline,
          size: 13,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    ],
  );
}

/// Displays the current [tags] as chips and an autocomplete text field.
class TagField extends StatefulWidget {
  final List<String> tags;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;
  final FocusNode? focusNode;

  const TagField({
    super.key,
    required this.tags,
    required this.suggestions,
    required this.onChanged,
    this.focusNode,
  });

  @override
  State<TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<TagField> {
  final _ctrl = TextEditingController();
  final _internalFocus = FocusNode();
  final _layerLink = LayerLink();
  final _scrollCtrl = ScrollController();

  FocusNode get _focus => widget.focusNode ?? _internalFocus;

  OverlayEntry? _entry;
  List<String> _options = [];
  int _hi = -1;

  static const double _kItemH = 40.0;
  static const double _kMaxH = 200.0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _close();
    _ctrl.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    _ctrl.dispose();
    _internalFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Options list ─────────────────────────────────────────────────────────

  List<String> _compute() {
    final q = _ctrl.text.toLowerCase();
    return widget.suggestions
        .where(
          (s) =>
              (q.isEmpty || s.toLowerCase().contains(q)) &&
              !widget.tags.contains(s),
        )
        .toList();
  }

  void _onTextChanged() => _refresh();
  void _onFocusChanged() {
    if (_focus.hasFocus) {
      _refresh();
    } else {
      // Delay closing so a mouse tap on a dropdown item can fire before
      // the overlay is removed.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focus.hasFocus) _close();
      });
    }
  }

  void _refresh() {
    if (!mounted) return;
    final opts = _compute();
    setState(() {
      _options = opts;
      _hi = -1;
    });
    if (opts.isEmpty) {
      _close();
    } else if (_entry == null) {
      _entry = OverlayEntry(builder: (_) => _dropdown());
      Overlay.of(context).insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  // ── Keyboard ─────────────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode _, KeyEvent ev) {
    if (ev is! KeyDownEvent) return KeyEventResult.ignored;
    final k = ev.logicalKey;

    if (k == LogicalKeyboardKey.arrowDown) {
      if (_options.isEmpty) return KeyEventResult.ignored;
      setState(() => _hi = (_hi + 1).clamp(0, _options.length - 1));
      _entry?.markNeedsBuild();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_hi));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      if (_options.isEmpty) return KeyEventResult.ignored;
      setState(() => _hi = (_hi - 1).clamp(0, _options.length - 1));
      _entry?.markNeedsBuild();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_hi));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (_hi >= 0 && _hi < _options.length) {
        _pick(_options[_hi]);
      } else if (_ctrl.text.trim().isNotEmpty) {
        _pick(_ctrl.text);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollTo(int i) {
    if (!_scrollCtrl.hasClients || i < 0) return;
    final target = i * _kItemH;
    final vp = _scrollCtrl.position.viewportDimension;
    final off = _scrollCtrl.offset;
    if (target < off) {
      _scrollCtrl.jumpTo(target);
    } else if (target + _kItemH > off + vp) {
      _scrollCtrl.jumpTo(target + _kItemH - vp);
    }
  }

  // ── Tag management ───────────────────────────────────────────────────────

  void _pick(String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isEmpty) return;
    _close();
    if (!widget.tags.contains(t)) {
      widget.onChanged(List<String>.from(widget.tags)..add(t));
    }
    _ctrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
        _refresh();
      }
    });
  }

  void _remove(String tag) =>
      widget.onChanged(widget.tags.where((t) => t != tag).toList());

  // ── Dropdown overlay ─────────────────────────────────────────────────────

  Widget _dropdown() {
    final cs = Theme.of(context).colorScheme;
    final opts = List<String>.from(_options);
    final hi = _hi;
    final count = opts.length;
    final dropH = (count * _kItemH).clamp(0.0, _kMaxH);

    return Positioned(
      width: 300,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 40),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: dropH,
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: EdgeInsets.zero,
              itemCount: count,
              itemExtent: _kItemH,
              itemBuilder: (_, i) {
                final sel = i == hi;
                return InkWell(
                  onTap: () => _pick(opts[i]),
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: sel
                        ? cs.primaryContainer.withValues(alpha: 0.5)
                        : null,
                    child: Text(
                      opts[i],
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.tags
                .map(
                  (t) => InputChip(
                    label: Text(t),
                    onDeleted: () => _remove(t),
                    deleteIconColor: cs.onSurfaceVariant,
                  ),
                )
                .toList(),
          ),
          const Gap(6),
        ],
        CompositedTransformTarget(
          link: _layerLink,
          child: Focus(
            onKeyEvent: _onKey,
            child: MarkdownTooltip(
              message:
                  '**Tags**\n\nType a tag and press Enter or tap + '
                  'to add it. Arrow keys navigate suggestions. '
                  'Tap × on a chip to remove a tag.',
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                decoration: InputDecoration(
                  hintText: 'Add tag…',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  suffixIcon: MarkdownTooltip(
                    message: '**Add tag**\n\nAdd the typed text as a tag.',
                    child: IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => _pick(_ctrl.text),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
