import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import '../../data/models/paragraph.dart';

enum EpubViewLoadingState { loading, success, error }

typedef EpubViewBuilder = Widget Function(
  BuildContext context,
  EpubViewBuilders builders,
  EpubViewLoadingState state,
  WidgetBuilder loadedBuilder,
  Exception? loadingError,
);

typedef EpubViewChapterBuilder = Widget Function(
  BuildContext context,
  EpubViewBuilders builders,
  EpubBook document,
  List<EpubChapter> chapters,
  List<Paragraph> paragraphs,
  int index,
  int chapterIndex,
  int paragraphIndex,
  void Function(String href) onExternalLinkPressed,
);

class DefaultBuilderOptions {
  const DefaultBuilderOptions({
    this.loaderSwitchDuration = const Duration(milliseconds: 250),
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
    this.paragraphPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.textStyle = const TextStyle(
      height: 1.5,
      fontSize: 16,
      color: Colors.black,
    ),
    this.textAlign = TextAlign.left,
    this.toolbarSelectionActionsColor = const [
      Color(0xFFFFFF00),
      Color(0xFF00FFFF),
      Color(0xFFFF69B4),
      Color(0xFF90EE90),
      Color(0xFFFFA07A),
      Color(0xFFDDA0DD),
    ],
  });

  final Duration loaderSwitchDuration;
  final AnimatedSwitcherTransitionBuilder transitionBuilder;
  final EdgeInsetsGeometry paragraphPadding;
  final TextStyle textStyle;
  final TextAlign textAlign;
  final List<Color> toolbarSelectionActionsColor;
}

class EpubViewBuilders<T extends DefaultBuilderOptions> {
  const EpubViewBuilders({
    required this.options,
    this.builder = EpubViewBuilders._defaultBuilder,
    this.chapterBuilder = EpubViewBuilders._defaultChapterBuilder,
    this.chapterDividerBuilder = EpubViewBuilders._defaultChapterDividerBuilder,
    this.loaderBuilder = EpubViewBuilders._defaultLoaderBuilder,
    this.errorBuilder = EpubViewBuilders._defaultErrorBuilder,
  });

  final T options;
  final EpubViewBuilder builder;
  final EpubViewChapterBuilder chapterBuilder;
  final Widget Function(EpubChapter chapter) chapterDividerBuilder;
  final WidgetBuilder? loaderBuilder;
  final Widget Function(BuildContext context, Exception error)? errorBuilder;

  static Widget _defaultBuilder(
    BuildContext context,
    EpubViewBuilders builders,
    EpubViewLoadingState state,
    WidgetBuilder loadedBuilder,
    Exception? loadingError,
  ) {
    Widget content;
    switch (state) {
      case EpubViewLoadingState.loading:
        content = KeyedSubtree(
          key: const Key('epubx.root.loading'),
          child: builders.loaderBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator()),
        );
        break;
      case EpubViewLoadingState.error:
        content = KeyedSubtree(
          key: const Key('epubx.root.error'),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: builders.errorBuilder?.call(context, loadingError!) ??
                Center(child: Text(loadingError.toString())),
          ),
        );
        break;
      case EpubViewLoadingState.success:
        content = KeyedSubtree(
          key: const Key('epubx.root.success'),
          child: loadedBuilder(context),
        );
        break;
    }

    final options = builders.options;

    return AnimatedSwitcher(
      duration: options.loaderSwitchDuration,
      transitionBuilder: options.transitionBuilder,
      child: content,
    );
  }

  static Widget _defaultChapterDividerBuilder(EpubChapter chapter) => Container(
        height: 56,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0x24000000),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          chapter.Title ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      );

  static Widget _defaultLoaderBuilder(BuildContext context) => const Center(
        child: CircularProgressIndicator(),
      );

  static Widget _defaultErrorBuilder(BuildContext context, Exception error) => Center(
        child: Text(
          'Failed to load document: $error',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );

  static Widget _defaultChapterBuilder(
    BuildContext context,
    EpubViewBuilders builders,
    EpubBook document,
    List<EpubChapter> chapters,
    List<Paragraph> paragraphs,
    int index,
    int chapterIndex,
    int paragraphIndex,
    void Function(String href) onExternalLinkPressed,
  ) {
    return Container();
  }
}
