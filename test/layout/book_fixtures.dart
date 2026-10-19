import 'package:aread/src/application/session/reading_session.dart';
import 'package:aread/src/domain/entities/publication.dart';
import 'package:aread/src/domain/entities/publication_metadata.dart';
import 'package:aread/src/presentation/state/library_controller.dart';
import 'package:flutter/material.dart';

BookItem fakeBook(String id, {String? title, String author = 'Author'}) => BookItem(
      publication: Publication(
        id: id,
        fingerprint: id,
        metadata: PublicationMetadata(title: title ?? 'Book $id', authors: [author], identifier: id),
        packagePath: '',
      ),
      coverGradientStart: Colors.blueGrey,
      coverGradientEnd: Colors.black,
      session: ReadingSession(),
      archiveBytes: const [],
    );
