import 'package:flutter/material.dart';

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

/// Paints [child]'s shapes in a sweeping shimmer. Every shimmer runs on the
/// same clock, so separate placeholders on screen sweep together.
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
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        final base = AppColors.fg.withValues(alpha: 0.06);
        final highlight = AppColors.fg.withValues(alpha: 0.13);
        final t = _shimmer.value * 2 - 0.5; // sweep from left to right
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [base, highlight, base],
            stops: [(t - 0.3).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.3).clamp(0.0, 1.0)],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
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

// Solid white blocks; the shimmer paints them.
Widget _block({required double width, required double height, double radius = 6}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
