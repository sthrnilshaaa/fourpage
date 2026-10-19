import 'package:aread/src/presentation/state/shelves.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a book moves between shelves and can be unshelved', () {
    final c = ShelfCollection();
    final a = c.create('Novels', id: 'a');
    final b = c.create('Biography', id: 'b');
    c.moveBook('book1', a.id);
    expect(c.shelfOf('book1')?.id, 'a');
    c.moveBook('book1', b.id);
    expect(c.byId('a')!.bookIds, isEmpty);
    expect(c.shelfOf('book1')?.id, 'b');
    c.moveBook('book1', null);
    expect(c.shelfOf('book1'), isNull);
  });

  test('deleting a shelf unshelves its books; rename and reorder', () {
    final c = ShelfCollection()
      ..create('One', id: '1')
      ..create('Two', id: '2')
      ..create('Three', id: '3');
    c.moveBook('x', '2');
    c.delete('2');
    expect(c.shelfOf('x'), isNull);
    c.rename('1', '  First ');
    expect(c.byId('1')!.name, 'First');
    c.reorder(0, 1);
    expect(c.shelves.map((s) => s.id), ['3', '1']);
    expect(c.nameTaken('first'), isTrue);
    expect(c.nameTaken('first', exceptId: '1'), isFalse);
  });

  test('encode/decode round trip; bad data is ignored', () {
    final c = ShelfCollection()..create('Novels', id: 'a');
    c.moveBook('b1', 'a');
    final back = ShelfCollection.decode(c.encode());
    expect(back.shelves.single.name, 'Novels');
    expect(back.shelfOf('b1')?.id, 'a');
    expect(ShelfCollection.decode('not json').shelves, isEmpty);
    // A book listed on two shelves keeps the first.
    final dup = ShelfCollection.decode('[{"id":"a","name":"A","books":["x"]},{"id":"b","name":"B","books":["x"]}]');
    expect(dup.byId('b')!.bookIds, isEmpty);
  });
}
