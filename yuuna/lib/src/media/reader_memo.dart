import 'package:isar/isar.dart';

part 'reader_memo.g.dart';

/// A note saved at a position in a book in ッツ Ebook Reader. Memos are kept
/// by the app because ッツ itself only stores one position per book.
@Collection()
class ReaderMemo {
  /// Create a memo at a position in a book.
  ReaderMemo({
    required this.bookKey,
    required this.bookTitle,
    required this.exploredCharCount,
    required this.progress,
    required this.memo,
    required this.excerpt,
    required this.createdAt,
    this.id = Isar.autoIncrement,
  });

  /// Identifier for database purposes.
  Id id;

  /// Identifies the book: the ッツ port and its book id, as `port/id`.
  @Index(type: IndexType.hash)
  String bookKey;

  /// Title of the book when the memo was written.
  String bookTitle;

  /// ッツ's character position of the page the memo was written on.
  int exploredCharCount;

  /// Position as a fraction of the book, from 0 to 1.
  double progress;

  /// What the reader wrote. May be empty.
  String memo;

  /// The selected text the memo is attached to.
  String excerpt;

  /// When the memo was written.
  DateTime createdAt;
}
