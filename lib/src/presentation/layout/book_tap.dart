import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Tap rules for book tiles on big screens:
/// touch tap opens; mouse click selects (or opens when there is nothing to
/// select into); mouse double click opens; long press / right click shows
/// the book's actions.
class BookTapHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback onOpen;
  final VoidCallback? onSelect;
  final ValueChanged<Offset>? onSecondary;

  const BookTapHandler({super.key, required this.child, required this.onOpen, this.onSelect, this.onSecondary});

  @override
  State<BookTapHandler> createState() => _BookTapHandlerState();
}

class _BookTapHandlerState extends State<BookTapHandler> {
  PointerDeviceKind _kind = PointerDeviceKind.touch;
  DateTime? _lastMouseTap;

  void _onTap() {
    final select = widget.onSelect;
    if (_kind != PointerDeviceKind.mouse || select == null) {
      widget.onOpen();
      return;
    }
    final now = DateTime.now();
    final last = _lastMouseTap;
    if (last != null && now.difference(last) <= kDoubleTapTimeout) {
      _lastMouseTap = null;
      widget.onOpen();
    } else {
      _lastMouseTap = now;
      select();
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = widget.onSecondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _kind = d.kind ?? PointerDeviceKind.touch,
        onTap: _onTap,
        onLongPressStart: secondary == null ? null : (d) => secondary(d.globalPosition),
        onSecondaryTapUp: secondary == null ? null : (d) => secondary(d.globalPosition),
        child: widget.child,
      ),
    );
  }
}
