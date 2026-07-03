import 'package:flutter/material.dart';

/// Adds desktop hover affordances to an interactive widget: a click cursor plus
/// a `hovered` flag the [builder] can use to subtly respond (e.g. brighten a
/// border). Hover events never fire on touch devices, so this is an inert
/// pass-through on mobile.
class HoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;

  /// When true the pointer shows the click cursor. Set false for hover-only
  /// affordances on non-tappable content.
  final bool clickable;

  const HoverBuilder({
    super.key,
    required this.builder,
    this.clickable = true,
  });

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.clickable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: widget.builder(context, _hovered),
    );
  }
}
