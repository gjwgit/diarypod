/// Tag input widget with autocomplete for DiaryPod.
///
// Time-stamp: <2026-05-12>
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
  final _scrollController = ScrollController();
  final _fieldKey = GlobalKey();

  FocusNode get _focus => widget.focusNode ?? _internalFocus;

  OverlayEntry? _overlay;
  List<String> _options = [];
  int _hi = -1; // highlighted index

  static const double _itemH = 40.0;
  static const double _maxH = 200.0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _ctrl.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    _ctrl.dispose();
    _internalFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) {
      _rebuildOptions();
    } else {
      _removeOverlay();
    }
  }

  void _onTextChanged() => _rebuildOptions();

  List<String> _computeOptions() {
    final q = _ctrl.text.toLowerCase();
    return widget.suggestions
        .where(
          (s) =>
              (q.isEmpty || s.toLowerCase().contains(q)) &&
              !widget.tags.contains(s),
        )
        .toList();
  }

  void _rebuildOptions() {
    if (!mounted) return;
    final opts = _computeOptions();
    setState(() {
      _options = opts;
      _hi = -1;
    });
    if (opts.isEmpty) {
      _removeOverlay();
    } else {
      if (_overlay == null) {
        _overlay = OverlayEntry(builder: (_) => _buildDropdown());
        Overlay.of(context).insert(_overlay!);
      } else {
        _overlay!.markNeedsBuild();
      }
    }
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _scrollToHighlighted() {
    if (!_scrollController.hasClients || _hi < 0) return;
    final target = _hi * _itemH;
    final vp = _scrollController.position.viewportDimension;
    final off = _scrollController.offset;
    if (target < off) {
      _scrollController.jumpTo(target);
    } else if (target + _itemH > off + vp) {
      _scrollController.jumpTo(target + _itemH - vp);
    }
  }

  void _selectTag(String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isEmpty) return;
    _removeOverlay();
    if (!widget.tags.contains(t)) {
      widget.onChanged(List<String>.from(widget.tags)..add(t));
    }
    _ctrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _rebuildOptions();
    });
  }

  void _removeTag(String tag) =>
      widget.onChanged(widget.tags.where((t) => t != tag).toList());

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_options.isEmpty) return KeyEventResult.ignored;
      setState(() => _hi = (_hi + 1).clamp(0, _options.length - 1));
      _overlay?.markNeedsBuild();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToHighlighted(),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_options.isEmpty) return KeyEventResult.ignored;
      setState(() => _hi = (_hi - 1).clamp(0, _options.length - 1));
      _overlay?.markNeedsBuild();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToHighlighted(),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_hi >= 0 && _hi < _options.length) {
        _selectTag(_options[_hi]);
      } else if (_ctrl.text.trim().isNotEmpty) {
        _selectTag(_ctrl.text);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _removeOverlay();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildDropdown() {
    final cs = Theme.of(context).colorScheme;

    // Measure the field's position to decide whether to open up or down.
    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.of(context).size;
    const fieldHeight = 40.0;
    double spaceBelow = screenSize.height / 2; // fallback
    double spaceAbove = screenSize.height / 2;
    if (renderBox != null) {
      final pos = renderBox.localToGlobal(Offset.zero);
      spaceBelow = screenSize.height - pos.dy - fieldHeight - 8;
      spaceAbove = pos.dy - 8;
    }

    final openUpward = spaceBelow < 120 && spaceAbove > spaceBelow;
    final availableSpace = openUpward ? spaceAbove : spaceBelow;
    final dropdownHeight = (_options.length * _itemH).clamp(
      0.0,
      availableSpace.clamp(0.0, _maxH),
    );

    final offset = openUpward
        ? Offset(0, -dropdownHeight - 4)
        : const Offset(0, 40);

    return Positioned(
      width: 300,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: offset,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: dropdownHeight,
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: _options.length,
              itemExtent: _itemH,
              itemBuilder: (_, i) {
                final highlighted = i == _hi;
                return InkWell(
                  onTap: () => _selectTag(_options[i]),
                  child: Container(
                    height: _itemH,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: highlighted
                        ? cs.primaryContainer.withValues(alpha: 0.5)
                        : null,
                    child: Text(
                      _options[i],
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: highlighted
                            ? FontWeight.w600
                            : FontWeight.normal,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.tags.map((t) {
              return InputChip(
                label: Text(t),
                onDeleted: () => _removeTag(t),
                deleteIconColor: cs.onSurfaceVariant,
              );
            }).toList(),
          ),
        if (widget.tags.isNotEmpty) const Gap(6),
        CompositedTransformTarget(
          key: _fieldKey,
          link: _layerLink,
          child: Focus(
            onKeyEvent: _onKey,
            child: MarkdownTooltip(
              message:
                  '**Tags**\n\nType a tag and press Enter or tap + to add. '
                  'Arrow keys navigate suggestions. '
                  'Tap × on a chip to remove it.',
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
                      onPressed: () => _selectTag(_ctrl.text),
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
