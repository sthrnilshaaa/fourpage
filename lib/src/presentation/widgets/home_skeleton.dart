import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Placeholder for the home screen while the library loads at startup:
/// the same shapes as the real layout (section headers, the Recent Reading
/// row of covers, the Books list), with a soft shimmer sweeping across.
class HomeSkeleton extends StatefulWidget {
  const HomeSkeleton({super.key});

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

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
        final t = _shimmer.value * 2 - 0.5; // sweep from left of screen to right
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
              itemBuilder: (_, _) => SizedBox(
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
              ),
            ),
          ),
          const SizedBox(height: 45),
          _header(),
          const SizedBox(height: 18),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(21, 0, 22, 20),
              child: SizedBox(
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
              ),
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

  // Solid white blocks; the ShaderMask above paints them in the shimmer.
  Widget _block({required double width, required double height, double radius = 6}) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
