import 'package:flutter/material.dart';

/// Placeholder page (text-line bars with a soft shimmer) shown over the
/// book while it is being laid out, so the reader never sees the half-styled
/// first render flash before the real layout.
class ReaderPageSkeleton extends StatefulWidget {
  final Color pageColor;
  final Color inkColor;
  final double padding;

  const ReaderPageSkeleton({
    super.key,
    required this.pageColor,
    required this.inkColor,
    required this.padding,
  });

  @override
  State<ReaderPageSkeleton> createState() => _ReaderPageSkeletonState();
}

class _ReaderPageSkeletonState extends State<ReaderPageSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  // Line widths (fraction of the text column): paragraphs end short.
  static const _lines = [
    0.55, 0, 1, 0.97, 1, 0.94, 1, 0.6, 0, 1, 0.98, 1, 0.92, 1, 0.99, 0.45, 0, //
    1, 0.96, 1, 0.93, 1, 0.7, 0, 1, 0.97, 1, 0.95, 0.5,
  ];

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bar = widget.inkColor.withValues(alpha: 0.09);
    final glow = widget.inkColor.withValues(alpha: 0.16);
    return ColoredBox(
      color: widget.pageColor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(widget.padding, 28, widget.padding, 16),
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) {
              final t = _shimmer.value * 2 - 0.5;
              return LinearGradient(
                begin: Alignment(-1 + t * 2, -0.3),
                end: Alignment(t * 2, 0.3),
                colors: [bar, glow, bar],
                stops: const [0.2, 0.5, 0.8],
              ).createShader(rect);
            },
            child: child,
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              const lineH = 12.0, gap = 13.0;
              final count = (c.maxHeight / (lineH + gap)).floor();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < count; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: gap),
                      child: Container(
                        height: lineH,
                        width: c.maxWidth * _lines[i % _lines.length],
                        decoration: BoxDecoration(
                          color: bar,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
