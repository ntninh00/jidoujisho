import 'package:flutter/material.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Media type that encapsulates text-based media, like books or articles.
class ReaderMediaType extends MediaType {
  /// Initialise this media type.
  ReaderMediaType._privateConstructor()
      : super(
          uniqueKey: 'reader_media_type',
          icon: Ui.library_books,
          outlinedIcon: Ui.library_books_outlined,
        );

  /// Get the singleton instance of this media type.
  static ReaderMediaType get instance => _instance;

  static final ReaderMediaType _instance =
      ReaderMediaType._privateConstructor();

  @override
  Widget get home => const HomeReaderPage();
}
