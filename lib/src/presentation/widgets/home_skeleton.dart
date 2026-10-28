import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_colors.dart';

/// Placeholder for the home screen before the list of books is known: the
/// same shapes as the real layout (section headers, the Recent Reading row
/// of covers, the Books list), with a soft shimmer sweeping across.
///
/// Once the list is known, Home shows the real layout and uses
/// [RecentCardSkeleton] / [BookRowSkeleton] / [BookTileSkeleton] for each
/// book still loading, swapping each one out as it's ready.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 2, bottom: 140),
        children: [
          _header(),
          const SizedBox(height: 20),
          SizedBox(
            height: 244,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 19),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 20),
              itemBuilder: (_, _) => const _RecentCardShape(),
            ),
          ),
          const SizedBox(height: 45),
          _header(),
          const SizedBox(height: 18),
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.fromLTRB(21, 0, 22, 20),
              child: _BookRowShape(),
            ),
        ],
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _block(width: 170, height: 24),
            const SizedBox(height: 10),
            _block(width: 210, height: 14),
          ],
        ),
      );
}

/// Placeholder for one Recent Reading card (121 wide).
class RecentCardSkeleton extends StatelessWidget {
  const RecentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SkeletonShimmer(child: _RecentCardShape());
}

/// Placeholder for one Home "Books" row (114 tall).
class BookRowSkeleton extends StatelessWidget {
  const BookRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SkeletonShimmer(child: _BookRowShape());
}

/// Placeholder for one cover-grid tile; fills the tile it's given.
class BookTileSkeleton extends StatelessWidget {
  const BookTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _block(width: double.infinity, height: double.infinity, radius: 7)),
            const SizedBox(height: 10),
            _block(width: double.infinity, height: 13),
            const SizedBox(height: 6),
            _block(width: 80, height: 11),
            const SizedBox(height: 10),
            _block(width: double.infinity, height: 3),
            const SizedBox(height: 4),
          ],
        ),
      );
}

/// Gives the blocks inside [child] a sweeping shimmer. Every shimmer runs on
/// the same clock and sweeps across the whole window, so separate
/// placeholders on screen sweep together.
///
/// The blocks paint the gradient themselves; there's no ShaderMask, which
/// drew every placeholder into its own offscreen layer each frame.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer> with SingleTickerProviderStateMixin {
  static const _period = Duration(milliseconds: 1400);

  late final AnimationController _shimmer = AnimationController(vsync: this, duration: _period)
    ..value = (DateTime.now().millisecondsSinceEpoch % _period.inMilliseconds) / _period.inMilliseconds
    ..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ticks repaint only the blocks, not what's around the placeholder.
    return RepaintBoundary(child: _ShimmerScope(shimmer: _shimmer, child: widget.child));
  }
}

class _ShimmerScope extends InheritedWidget {
  final Animation<double> shimmer;

  const _ShimmerScope({required this.shimmer, required super.child});

  static Animation<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.shimmer ?? const AlwaysStoppedAnimation(0);

  @override
  bool updateShouldNotify(_ShimmerScope old) => old.shimmer != shimmer;
}

/// One rounded placeholder shape, painted with the shimmer of the nearest
/// [SkeletonShimmer].
class _Block extends LeafRenderObjectWidget {
  final double width;
  final double height;
  final double radius;

  const _Block({required this.width, required this.height, required this.radius});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBlock(
        shimmer: _ShimmerScope.of(context),
        width: width,
        height: height,
        radius: radius,
        sweepWidth: MediaQuery.sizeOf(context).width,
        base: AppColors.fg.withValues(alpha: 0.06),
        highlight: AppColors.fg.withValues(alpha: 0.13),
      );

  @override
  void updateRenderObject(BuildContext context, _RenderBlock renderObject) {
    renderObject
      ..shimmer = _ShimmerScope.of(context)
      ..width = width
      ..height = height
      ..radius = radius
      ..sweepWidth = MediaQuery.sizeOf(context).width
      ..base = AppColors.fg.withValues(alpha: 0.06)
      ..highlight = AppColors.fg.withValues(alpha: 0.13);
  }
}

class _RenderBlock extends RenderBox {
  _RenderBlock({
    required Animation<double> shimmer,
    required double width,
    required double height,
    required this.radius,
    required this.sweepWidth,
    required this.base,
    required this.highlight,
  })  : _shimmer = shimmer,
        _width = width,
        _height = height;

  Animation<double> _shimmer;
  set shimmer(Animation<double> value) {
    if (value == _shimmer) return;
    if (attached) _shimmer.removeListener(markNeedsPaint);
    _shimmer = value;
    if (attached) _shimmer.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _width;
  set width(double value) {
    if (value == _width) return;
    _width = value;
    markNeedsLayout();
  }

  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  // Painted every tick anyway, so these just take effect on the next frame.
  double radius;
  double sweepWidth;
  Color base;
  Color highlight;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _shimmer.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _shimmer.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() => size = constraints.constrain(Size(_width, _height));

  @override
  void paint(PaintingContext context, Offset offset) {
    final t = _shimmer.value * 2 - 0.5; // sweep from left to right
    // The gradient spans the window, not this block: where the window's
    // left edge is, in this canvas.
    final left = offset.dx - localToGlobal(Offset.zero).dx;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [base, highlight, base],
        stops: [(t - 0.3).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.3).clamp(0.0, 1.0)],
      ).createShader(Rect.fromLTWH(left, offset.dy, sweepWidth <= 0 ? size.width : sweepWidth, size.height));
    context.canvas.drawRRect(RRect.fromRectAndRadius(offset & size, Radius.circular(radius)), paint);
  }
}

class _RecentCardShape extends StatelessWidget {
  const _RecentCardShape();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 121,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _block(width: 121, height: 182, radius: 4),
            const SizedBox(height: 11),
            _block(width: 100, height: 13),
            const SizedBox(height: 8),
            _block(width: 70, height: 11),
            const SizedBox(height: 10),
            _block(width: 121, height: 3),
          ],
        ),
      );
}

class _BookRowShape extends StatelessWidget {
  const _BookRowShape();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 114,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _block(width: 76, height: 114, radius: 2),
            const SizedBox(width: 17),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 11),
                  _block(width: double.infinity, height: 15),
                  const SizedBox(height: 8),
                  _block(width: 140, height: 15),
                  const Spacer(),
                  _block(width: 110, height: 12),
                  const SizedBox(height: 14),
                  _block(width: double.infinity, height: 3),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      );
}

Widget _block({required double width, required double height, double radius = 6}) =>
    _Block(width: width, height: height, radius: radius);
