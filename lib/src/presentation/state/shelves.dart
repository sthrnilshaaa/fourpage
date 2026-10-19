/// User-made shelves. A book sits on at most one shelf; books on no shelf
/// show as "Unshelved". Stored as JSON in app_settings by LibraryController.
library;

import 'dart:convert';

class Shelf {
  final String id;
  final String name;

  /// Publication ids, in the order they were added.
  final List<String> bookIds;

  const Shelf({required this.id, required this.name, this.bookIds = const []});

  Shelf copyWith({String? name, List<String>? bookIds}) =>
      Shelf(id: id, name: name ?? this.name, bookIds: bookIds ?? this.bookIds);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'books': bookIds};

  static Shelf? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    final books = json['books'];
    return Shelf(
      id: id,
      name: name,
      bookIds: books is List ? [for (final b in books) if (b is String) b] : const [],
    );
  }
}

/// The ordered list of shelves and every change you can make to it. Each
/// change returns nothing and edits in place; the caller saves [encode()].
class ShelfCollection {
  final List<Shelf> _shelves;

  ShelfCollection([List<Shelf>? shelves]) : _shelves = [...?shelves];

  factory ShelfCollection.decode(String? json) {
    if (json == null || json.isEmpty) return ShelfCollection();
    try {
      final list = jsonDecode(json);
      if (list is! List) return ShelfCollection();
      final shelves = <Shelf>[];
      final seenBooks = <String>{};
      for (final raw in list) {
        final shelf = Shelf.fromJson(raw);
        if (shelf == null) continue;
        // A book on two shelves (hand-edited data): keep the first.
        final ids = [for (final b in shelf.bookIds) if (seenBooks.add(b)) b];
        shelves.add(shelf.copyWith(bookIds: ids));
      }
      return ShelfCollection(shelves);
    } catch (_) {
      return ShelfCollection();
    }
  }

  String encode() => jsonEncode([for (final s in _shelves) s.toJson()]);

  List<Shelf> get shelves => List.unmodifiable(_shelves);

  Shelf? byId(String id) {
    for (final s in _shelves) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The shelf [bookId] is on, or null when it's unshelved.
  Shelf? shelfOf(String bookId) {
    for (final s in _shelves) {
      if (s.bookIds.contains(bookId)) return s;
    }
    return null;
  }

  bool nameTaken(String name, {String? exceptId}) {
    final key = name.trim().toLowerCase();
    return _shelves.any((s) => s.id != exceptId && s.name.trim().toLowerCase() == key);
  }

  /// Adds an empty shelf at the end and returns it.
  Shelf create(String name, {required String id}) {
    final shelf = Shelf(id: id, name: name.trim());
    _shelves.add(shelf);
    return shelf;
  }

  void rename(String id, String name) {
    final i = _shelves.indexWhere((s) => s.id == id);
    if (i >= 0) _shelves[i] = _shelves[i].copyWith(name: name.trim());
  }

  /// Removes the shelf; its books become unshelved (they stay in the library).
  void delete(String id) => _shelves.removeWhere((s) => s.id == id);

  /// Moves a shelf to [newIndex] (index in the list after removal).
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _shelves.length) return;
    final shelf = _shelves.removeAt(oldIndex);
    _shelves.insert(newIndex.clamp(0, _shelves.length), shelf);
  }

  /// Puts [bookId] on shelf [shelfId] (taking it off any other shelf), or
  /// unshelves it when [shelfId] is null.
  void moveBook(String bookId, String? shelfId) {
    for (var i = 0; i < _shelves.length; i++) {
      final s = _shelves[i];
      if (s.id == shelfId) {
        if (!s.bookIds.contains(bookId)) _shelves[i] = s.copyWith(bookIds: [...s.bookIds, bookId]);
      } else if (s.bookIds.contains(bookId)) {
        _shelves[i] = s.copyWith(bookIds: [...s.bookIds]..remove(bookId));
      }
    }
  }

  /// Forgets a book everywhere (it was deleted from the library).
  void forgetBook(String bookId) => moveBook(bookId, null);

  void clear() => _shelves.clear();
}
