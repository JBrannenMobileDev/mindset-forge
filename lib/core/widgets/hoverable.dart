import 'package:flutter/material.dart';

/// Wraps a custom tap target with web/desktop hover affordances: a click cursor
/// and a subtle hover highlight, without changing anything on touch platforms
/// (where hover never fires).
///
/// Use for `GestureDetector`-based tap targets (cards, chips, rows) that
/// otherwise feel "dead" on the web — Material buttons already get hover +
/// pointer for free, so they don't need this.
///
/// The [builder] receives the current hover state so callers can drive their
/// own emphasis (brighter border/background, elevation, etc.). For the common
/// case, [Hoverable.highlight] applies a token-friendly overlay automatically.
class Hoverable extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovered) builder;

  /// Cursor shown while pointing at the target. Defaults to a click cursor.
  final MouseCursor cursor;

  /// Called on tap. Optional so [Hoverable] can also wrap non-tap targets that
  /// just want hover feedback (the child handles its own gestures).
  final VoidCallback? onTap;

  const Hoverable({
    super.key,
    required this.builder,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(context, _hovered);
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.onTap == null
          ? child
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: child,
            ),
    );
  }
}
