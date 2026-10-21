/// Backend, network, engine, and app configuration constants.
library;

class AppConstants {
  AppConstants._();

  // Application Info
  static const String appName = 'Fourpage';
  static const String appVersion = '1.0.0';

  // Links (Settings › About)
  /// GitHub owner/repo: "Star on GitHub" and the GitHub build's update check
  /// (latest release). The repo doesn't exist yet; until it does, the update
  /// check just finds nothing.
  static const String githubRepo = 'sthrnilshaaa/fourpage';
  static const String githubUrl = 'https://github.com/$githubRepo';
  static const String githubLatestReleaseApi = 'https://api.github.com/repos/$githubRepo/releases/latest';
  static const String kofiUrl = 'https://ko-fi.com/L2L124TL7L';

  // Backend & Database Config
  static const String databaseName = 'aread_v1.db';
  static const int databaseVersion = 4;
  static const int defaultNetworkTimeoutMs = 15000;
  static const int defaultSyncIntervalSeconds = 30;

  // App Settings Keys (see AppSettingsRepository)
  static const String settingOnboardingComplete = 'onboarding_complete';

  // Reader Engine Config
  static const String epubMimetype = 'application/epub+zip';
  static const String containerXmlPath = 'META-INF/container.xml';
  static const int maxSearchSnippets = 50;

  // Typography Defaults
  static const String defaultFontFamily = 'Merriweather';
  static const double defaultFontSize = 16.0;
  static const double defaultLineHeight = 1.5;
  static const String defaultLanguage = 'en';
}
