import 'package:flutter/material.dart';
import 'l10n/l10n.dart';
import 'screens/intro_screen.dart';
import 'src/core/constants/app_constants.dart';
import 'src/data/database/app_settings_repository.dart';
import 'src/presentation/screens/main_navigation_shell.dart';
import 'src/presentation/state/app_preferences.dart';
import 'src/presentation/state/usage_tracker.dart';
import 'src/presentation/theme/app_colors.dart';
import 'src/presentation/theme/app_theme.dart';
import 'src/presentation/theme/app_theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the saved light/dark choice before the first frame so the app
  // doesn't flash the wrong theme (also sets the status-bar icon colour).
  await AppThemeController.instance.load();
  await AppPreferences.instance.load();
  UsageTracker.instance
    ..start()
    ..applyReminderSettings();
  runApp(const AreadApp());
}

class AreadApp extends StatefulWidget {
  /// Overridable for tests, so they don't have to touch the real database.
  /// Defaults to the real "has onboarding been completed?" check.
  final Future<bool> Function()? checkOnboardingComplete;

  const AreadApp({super.key, this.checkOnboardingComplete});

  @override
  State<AreadApp> createState() => _AreadAppState();
}

class _AreadAppState extends State<AreadApp> {
  @override
  void initState() {
    super.initState();
    AppThemeController.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  // AppColors tokens are read directly (not through Theme.of), so const and
  // non-dependent widgets wouldn't repaint on their own. Mark the whole tree
  // dirty instead - keeps routes and state, unlike re-keying the app.
  void _onThemeChanged() {
    setState(() {});
    void markAll(Element element) {
      element.markNeedsBuild();
      element.visitChildren(markAll);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final root = WidgetsBinding.instance.rootElement;
      if (root != null) markAll(root);
    });
  }

  @override
  Widget build(BuildContext context) {
    final light = AppThemeController.instance.isLight;
    return MaterialApp(
      title: 'Fourpages',
      debugShowCheckedModeBanner: false,
      theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Keep the context-free `l10n` accessor in step with the active locale.
      builder: (context, child) {
        updateL10n(AppLocalizations.of(context));
        return child!;
      },
      home: AppStartupRouter(checkOnboardingComplete: widget.checkOnboardingComplete),
    );
  }
}

/// Decides whether to show onboarding or go straight to the library, based
/// on a persisted "has the user finished onboarding before?" flag. Without
/// this, every launch (not just the first) would show the intro carousel.
class AppStartupRouter extends StatefulWidget {
  final Future<bool> Function()? checkOnboardingComplete;

  const AppStartupRouter({super.key, this.checkOnboardingComplete});

  @override
  State<AppStartupRouter> createState() => _AppStartupRouterState();
}

class _AppStartupRouterState extends State<AppStartupRouter> {
  late final Future<bool> _onboardingComplete =
      (widget.checkOnboardingComplete ?? _loadOnboardingComplete)();

  static Future<bool> _loadOnboardingComplete() async {
    try {
      return await AppSettingsRepository().getBool(AppConstants.settingOnboardingComplete);
    } catch (_) {
      // If the flag can't be read for any reason, fail open to onboarding
      // rather than crashing app startup.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _onboardingComplete,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(backgroundColor: AppColors.darkBackground);
        }
        return snapshot.data! ? const MainNavigationShell() : const IntroScreen();
      },
    );
  }
}
