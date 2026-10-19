/// Word definitions from the free Dictionary API (dictionaryapi.dev).
/// English only, needs a network connection, no API key.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WordSense {
  final String partOfSpeech;
  final List<String> definitions;
  final List<String> examples;
  final List<String> synonyms;

  const WordSense({
    required this.partOfSpeech,
    required this.definitions,
    required this.examples,
    required this.synonyms,
  });
}

class WordDefinition {
  final String word;
  final String? phonetic;
  final List<WordSense> senses;

  const WordDefinition({required this.word, this.phonetic, required this.senses});
}

enum DictionaryFailure { notFound, offline }

class DictionaryException implements Exception {
  final DictionaryFailure failure;
  const DictionaryException(this.failure);
}

class DictionaryService {
  DictionaryService._();
  static final DictionaryService instance = DictionaryService._();

  final Map<String, WordDefinition> _cache = {};

  /// The word to look up from a text selection: the first word, without
  /// surrounding punctuation or quotes, lower-cased. Null if there's none.
  static String? wordFrom(String selection) {
    final match = RegExp(r"[\p{L}][\p{L}'’\-]*", unicode: true).firstMatch(selection);
    if (match == null) return null;
    var word = match.group(0)!.replaceAll('’', "'");
    // "reader's" -> "reader", trailing hyphens from line breaks.
    word = word.replaceAll(RegExp(r"('s|')$"), '').replaceAll(RegExp(r'-+$'), '');
    return word.isEmpty ? null : word.toLowerCase();
  }

  /// Looks [word] up. Throws [DictionaryException] if it isn't found or the
  /// service can't be reached.
  Future<WordDefinition> define(String word) async {
    final cached = _cache[word];
    if (cached != null) return cached;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.https('api.dictionaryapi.dev', '/api/v2/entries/en/${Uri.encodeComponent(word)}');
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 404) throw const DictionaryException(DictionaryFailure.notFound);
      if (response.statusCode != 200) throw const DictionaryException(DictionaryFailure.offline);

      final result = _parse(word, jsonDecode(body));
      if (result.senses.isEmpty) throw const DictionaryException(DictionaryFailure.notFound);
      _cache[word] = result;
      return result;
    } on DictionaryException {
      rethrow;
    } on SocketException {
      throw const DictionaryException(DictionaryFailure.offline);
    } on TimeoutException {
      throw const DictionaryException(DictionaryFailure.offline);
    } on HandshakeException {
      throw const DictionaryException(DictionaryFailure.offline);
    } on HttpException {
      throw const DictionaryException(DictionaryFailure.offline);
    } on FormatException {
      throw const DictionaryException(DictionaryFailure.notFound);
    } finally {
      client.close(force: true);
    }
  }

  static WordDefinition _parse(String word, Object? json) {
    if (json is! List || json.isEmpty) return WordDefinition(word: word, senses: const []);
    String? phonetic;
    final byPart = <String, WordSense>{};
    for (final entry in json.whereType<Map>()) {
      phonetic ??= _nonEmpty(entry['phonetic']) ??
          (entry['phonetics'] as List?)
              ?.whereType<Map>()
              .map((p) => _nonEmpty(p['text']))
              .whereType<String>()
              .firstOrNull;
      for (final meaning in (entry['meanings'] as List? ?? const []).whereType<Map>()) {
        final part = _nonEmpty(meaning['partOfSpeech']) ?? '';
        final defs = <String>[];
        final examples = <String>[];
        for (final d in (meaning['definitions'] as List? ?? const []).whereType<Map>()) {
          final text = _nonEmpty(d['definition']);
          if (text != null) defs.add(text);
          final example = _nonEmpty(d['example']);
          if (example != null) examples.add(example);
        }
        final synonyms = (meaning['synonyms'] as List? ?? const []).whereType<String>().toList();
        final existing = byPart[part];
        byPart[part] = WordSense(
          partOfSpeech: part,
          definitions: [...?existing?.definitions, ...defs],
          examples: [...?existing?.examples, ...examples],
          synonyms: {...?existing?.synonyms, ...synonyms}.toList(),
        );
      }
    }
    return WordDefinition(
      word: (json.first as Map?)?['word'] as String? ?? word,
      phonetic: phonetic,
      senses: byPart.values.where((s) => s.definitions.isNotEmpty).toList(),
    );
  }

  static String? _nonEmpty(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
}
