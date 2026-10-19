import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../src/core/constants/app_constants.dart';
import '../src/core/constants/asset_constants.dart';
import '../src/data/database/app_settings_repository.dart';
import '../src/presentation/screens/main_navigation_shell.dart';
import '../src/presentation/utils/book_import_actions.dart';
import '../src/presentation/theme/app_colors.dart';
import '../src/presentation/widgets/app_chrome.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isImporting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToMain() {
    // Mark onboarding as seen so future launches skip straight to the
    // library instead of showing this carousel every time.
    unawaited(
      AppSettingsRepository().setBool(
        AppConstants.settingOnboardingComplete,
        true,
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
    );
  }

  // Both import paths are shared with the Import dialog (BookImportActions):
  // same formats, same folder-access request, same messages. Onboarding
  // finishes once something was imported.
  Future<void> _selectFolders() => _import(BookImportActions.scanFolder);

  Future<void> _addBooks() => _import(BookImportActions.pickFiles);

  Future<void> _import(Future<ImportOutcome> Function(BuildContext) action) async {
    setState(() => _isImporting = true);
    final outcome = await action(context);
    if (!mounted) return;
    setState(() => _isImporting = false);
    if (outcome.imported > 0) _navigateToMain();
  }

  /// Figma frame size the intro is laid out in (startup_page/startup_import).
  static const double _designWidth = 440;
  static const double _designHeight = 956;

  static const Color _background = Color(0xFF090909);
  static const Color _headlineLime = Color(0xFFC7F06F);

  void _next() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeInOutCubic,
    );
  }

  /// 0 on startup_page, 1 on startup_import, fractional mid-swipe - every
  /// element below is interpolated from this so the two screens morph into
  /// each other and track the finger during a swipe.
  double get _progress {
    if (!_pageController.hasClients ||
        !_pageController.position.haveDimensions) {
      return _currentPage.toDouble();
    }
    return (_pageController.page ?? 0).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final s = w / _designWidth;

          // Top-anchored design y (artwork, logo) vs bottom-anchored design y
          // (copy, buttons, dots) so the layout holds on shorter/taller phones.
          double top(double y) => y * s;
          double bottom(double y) => h - (_designHeight - y) * s;

          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, _) => _buildScene(
                    t: _progress,
                    w: w,
                    h: h,
                    s: s,
                    top: top,
                    bottom: bottom,
                  ),
                ),
              ),

              // Invisible pager on top of the artwork: it only supplies the
              // swipe gesture + page physics that drive the morph.
              Positioned.fill(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  children: const [SizedBox.expand(), SizedBox.expand()],
                ),
              ),

              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, _) => _buildControls(
                    t: _progress,
                    w: w,
                    s: s,
                    top: top,
                    bottom: bottom,
                  ),
                ),
              ),

              if (_isImporting)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.figmaLime,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Non-interactive layers: artwork window, fades, copy.
  Widget _buildScene({
    required double t,
    required double w,
    required double h,
    required double s,
    required double Function(double) top,
    required double Function(double) bottom,
  }) {
    final e = Curves.easeInOutCubic.transform(t);

    // startup_import's card (378x469 @ 31,130), kept clear of the headline
    // on shorter screens.
    final cardTop = top(130);
    final cardHeight = math.max(
      0.0,
      math.min(469 * s, bottom(665) - 36 * s - cardTop),
    );
    final cardRect = Rect.fromLTWH(31 * s, cardTop, 378 * s, cardHeight);
    final fullRect = Rect.fromLTWH(0, 0, w, h);
    final window = Rect.lerp(fullRect, cardRect, e)!;
    final radius = 20 * s * e;

    // Both artworks sit in *screen* coordinates, not inside the card: the
    // import card is literally a window onto the same image that's shown
    // dimmed behind it (image 94 at -11,0 462x829 in Figma), so shrinking
    // the window reveals the dimmed backdrop around it.
    final startupArt = Rect.fromLTWH(-3 * s, 0, 445 * s, 791 * s);
    final importArt = Rect.fromLTWH(-11 * s, 0, 462 * s, 829 * s);

    Widget art(String asset, Rect r) => Positioned.fromRect(
      rect: r,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    );

    final outgoing = (1 - t * 2).clamp(0.0, 1.0);
    final incoming = (t * 2 - 1).clamp(0.0, 1.0);

    return Stack(
      children: [
        // startup_import backdrop: the same art at 20%.
        Positioned.fill(
          child: Opacity(
            opacity: e,
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: importArt,
                  child: Opacity(
                    opacity: 0.2,
                    child: Image.asset(
                      AssetConstants.startupImportBg,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // The window: startup art cross-fading into the bookshelf art.
        Positioned.fromRect(
          rect: window,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -window.left,
                  top: -window.top,
                  width: w,
                  height: h,
                  child: Stack(
                    children: [
                      art(AssetConstants.startupImportBg, importArt),
                      Opacity(
                        opacity: 1 - Curves.easeIn.transform(t),
                        child: Stack(
                          children: [
                            art(AssetConstants.startupPageBg, startupArt),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Lime soft-light wash + 5pt white-10% rim (Rectangle 684).
                // Faded via the colour's alpha, not an Opacity widget: Opacity
                // isolates its child in a layer, so the soft-light blend would
                // mix with transparency and paint flat lime mid-transition.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _headlineLime.withValues(alpha: e),
                      backgroundBlendMode: BlendMode.softLight,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: e,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 5 * s,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Fade to the page colour behind the copy (Rectangle 595).
        Positioned(
          left: 0,
          right: 0,
          top: top(221),
          bottom: 0,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.60577],
                  colors: [Color(0x00090909), _background],
                ),
              ),
            ),
          ),
        ),

        // Hairline under the top bar - startup_page only (Line 11).
        Positioned(
          left: 19 * s,
          top: top(107),
          width: 403 * s,
          height: 1,
          child: Opacity(
            opacity: outgoing,
            child: const ColoredBox(color: Color(0x0DFFFFFF)),
          ),
        ),

        // Headline + subtitle: the outgoing pair drifts up and fades, the
        // incoming pair rises into place after it.
        _slidingCopy(
          opacity: outgoing,
          dy: -24 * s * t,
          top: bottom(675),
          s: s,
          headline: _headline(
            s,
            lead: l10n.your,
            trail: ',',
            second: l10n.alwaysWithYou,
          ),
          subtitle:
              l10n.openYourBooksReadOfflineAnd,
          subtitleTop: bottom(757),
        ),
        _slidingCopy(
          opacity: incoming,
          dy: 24 * s * (1 - t),
          top: bottom(665),
          s: s,
          headline: _headline(
            s,
            lead: l10n.importYour,
            trail: '.',
            trailSerif: true,
          ),
          // Figma copy says "FourPage supports EPUB and PDF." - FourPage is
          // the old template name and PDF can't actually be opened.
          subtitle: l10n.fourpagesSupportsEpubBooks,
          subtitleTop: bottom(711),
        ),
      ],
    );
  }

  Widget _headline(
    double s, {
    required String lead,
    required String trail,
    String second = '',
    bool trailSerif = false,
  }) {
    final sans = GoogleFonts.sora(
      fontSize: 30 * s,
      height: 35 / 30,
      letterSpacing: -0.6 * s,
      color: Colors.white,
    );
    final serif = GoogleFonts.robotoSerif(
      fontSize: 30 * s,
      height: 35 / 30,
      fontWeight: FontWeight.w300,
      fontStyle: FontStyle.italic,
      color: _headlineLime,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: lead, style: sans),
          TextSpan(text: l10n.books, style: serif),
          TextSpan(
            text: trail,
            style: trailSerif ? serif.copyWith(color: Colors.white) : sans,
          ),
          if (second.isNotEmpty) TextSpan(text: second, style: sans),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _slidingCopy({
    required double opacity,
    required double dy,
    required double top,
    required double s,
    required Widget headline,
    required String subtitle,
    required double subtitleTop,
  }) {
    // Must stay a positioned child even when hidden - a bare SizedBox here
    // would be the scene Stack's only non-positioned child and shrink the
    // whole Stack (and everything painted in it) to zero size.
    if (opacity <= 0)
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Stack(
              children: [
                Positioned(left: 0, right: 0, top: top, child: headline),
                Positioned(
                  left: 0,
                  right: 0,
                  top: subtitleTop,
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(
                      fontSize: 13 * s,
                      height: 20 / 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Interactive layers: logo/Skip, the morphing primary button, Add Books, dots.
  Widget _buildControls({
    required double t,
    required double w,
    required double s,
    required double Function(double) top,
    required double Function(double) bottom,
  }) {
    final e = Curves.easeInOutCubic.transform(t);
    final outgoing = (1 - t * 2).clamp(0.0, 1.0);
    final incoming = (t * 2 - 1).clamp(0.0, 1.0);
    final onImport = t > 0.5;

    final labelStyle = GoogleFonts.sora(
      fontSize: 17 * s,
      height: 14 / 17,
      letterSpacing: -0.34 * s,
      color: Colors.white,
    );

    return Stack(
      children: [
        // Logo (Group 67602 2) and Skip.
        Positioned(
          left: 31 * s,
          top: top(67),
          child: Image.asset(
            AssetConstants.logoBookWhite,
            width: 27 * s,
            height: 17 * s,
          ),
        ),
        if (incoming > 0)
          Positioned(
            right: (440 - 409) * s,
            top: top(62),
            child: Opacity(
              opacity: incoming,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onImport ? _navigateToMain : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 7 * s),
                  child: Text(
                    l10n.skip,
                    style: GoogleFonts.sora(
                      fontSize: 20 * s,
                      height: 14 / 20,
                      letterSpacing: -0.4 * s,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Primary button: "Get Started →" glides up and becomes "Select Folders".
        Positioned(
          left: 41 * s,
          width: 359 * s,
          top: lerpDouble(bottom(836), bottom(761), e),
          height: 56 * s,
          child: _GlassButton(
            radius: 20 * s,
            onTap: onImport ? _selectFolders : _next,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: outgoing,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 23 * s),
                    child: Row(
                      children: [
                        Text(l10n.getStarted, style: labelStyle),
                        const Spacer(),
                        CustomPaint(
                          size: Size(34 * s, 12 * s),
                          painter: _LongArrowPainter(),
                        ),
                      ],
                    ),
                  ),
                ),
                Opacity(
                  opacity: incoming,
                  child: Padding(
                    padding: EdgeInsets.only(left: 24 * s, right: 26 * s),
                    child: Row(
                      children: [
                        Text(l10n.selectFolders, style: labelStyle),
                        const Spacer(),
                        FigmaIcon(
                          AssetConstants.iconFolderAdd,
                          width: 21 * s,
                          height: 21 * s,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Secondary "Add Books" (startup_import only).
        if (incoming > 0)
          Positioned(
            left: 0,
            right: 0,
            top: bottom(829) + 16 * s * (1 - incoming),
            height: 56 * s,
            child: Opacity(
              opacity: incoming,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onImport ? _addBooks : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12 * s,
                      vertical: 18 * s,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.addBooks, style: labelStyle),
                        SizedBox(width: 8 * s),
                        FigmaIcon(
                          AssetConstants.iconAddBookPlain,
                          width: 15.3 * s,
                          height: 16 * s,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Page dots (Group 599): two 12.6x3 bars, the active one white.
        Positioned(
          left: 0,
          right: 0,
          top: bottom(921),
          height: 3 * s,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dot(s, active: 1 - t),
              SizedBox(width: 4.2 * s),
              _dot(s, active: t),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot(double s, {required double active}) {
    return Container(
      width: 12.6 * s,
      height: 3 * s,
      decoration: BoxDecoration(
        color: Color.lerp(
          Colors.white.withValues(alpha: 0.2),
          Colors.white,
          active,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

/// #161615 card button with the design's hairline border, soft drop shadow
/// and backdrop blur (Frame 140 / Frame 172).
class _GlassButton extends StatelessWidget {
  final double radius;
  final VoidCallback onTap;
  final Widget child;

  const _GlassButton({
    required this.radius,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            spreadRadius: -15,
            offset: const Offset(0, 35),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Material(
            color: const Color(0xFF161615),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: InkWell(onTap: onTap, child: child),
          ),
        ),
      ),
    );
  }
}

/// The long "⟶" on the Get Started button.
class _LongArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    final head = size.height / 2;
    canvas.drawLine(
      Offset(size.width - head, y - head),
      Offset(size.width, y),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - head, y + head),
      Offset(size.width, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
