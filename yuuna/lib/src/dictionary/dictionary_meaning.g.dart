// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_meaning.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDictionaryMeaningCollection on Isar {
  IsarCollection<DictionaryMeaning> get dictionaryMeanings => this.collection();
}

const DictionaryMeaningSchema = CollectionSchema(
  name: r'DictionaryMeaning',
  id: 5312116113136065536,
  properties: {
    r'words': PropertySchema(
      id: 0,
      name: r'words',
      type: IsarType.stringList,
    )
  },
  estimateSize: _dictionaryMeaningEstimateSize,
  serialize: _dictionaryMeaningSerialize,
  deserialize: _dictionaryMeaningDeserialize,
  deserializeProp: _dictionaryMeaningDeserializeProp,
  idName: r'id',
  indexes: {
    r'words': IndexSchema(
      id: -8729652909246617716,
      name: r'words',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'words',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _dictionaryMeaningGetId,
  getLinks: _dictionaryMeaningGetLinks,
  attach: _dictionaryMeaningAttach,
  version: '3.1.0+1',
);

int _dictionaryMeaningEstimateSize(
  DictionaryMeaning object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.words.length * 3;
  {
    for (var i = 0; i < object.words.length; i++) {
      final value = object.words[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _dictionaryMeaningSerialize(
  DictionaryMeaning object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeStringList(offsets[0], object.words);
}

DictionaryMeaning _dictionaryMeaningDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DictionaryMeaning(
    id: id,
    words: reader.readStringList(offsets[0]) ?? [],
  );
  return object;
}

P _dictionaryMeaningDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringList(offset) ?? []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _dictionaryMeaningGetId(DictionaryMeaning object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _dictionaryMeaningGetLinks(
    DictionaryMeaning object) {
  return [];
}

void _dictionaryMeaningAttach(
    IsarCollection<dynamic> col, Id id, DictionaryMeaning object) {}

extension DictionaryMeaningQueryWhereSort
    on QueryBuilder<DictionaryMeaning, DictionaryMeaning, QWhere> {
  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhere>
      anyWordsElement() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'words'),
      );
    });
  }
}

extension DictionaryMeaningQueryWhere
    on QueryBuilder<DictionaryMeaning, DictionaryMeaning, QWhereClause> {
  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      wordsElementEqualTo(String wordsElement) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'words',
        value: [wordsElement],
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      wordsElementNotEqualTo(String wordsElement) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'words',
              lower: [],
              upper: [wordsElement],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'words',
              lower: [wordsElement],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'words',
              lower: [wordsElement],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'words',
              lower: [],
              upper: [wordsElement],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      wordsElementGreaterThan(
    String wordsElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'words',
        lower: [wordsElement],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      wordsElementLessThan(
    String wordsElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'words',
        lower: [],
        upper: [wordsElement],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      wordsElementBetween(
    String lowerWordsElement,
    String upperWordsElement, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'words',
        lower: [lowerWordsElement],
        includeLower: includeLower,
        upper: [upperWordsElement],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      wordsElementStartsWith(String WordsElementPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'words',
        lower: [WordsElementPrefix],
        upper: ['$WordsElementPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      wordsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'words',
        value: [''],
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      wordsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'words',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'words',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'words',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'words',
              upper: [''],
            ));
      }
    });
  }
}

extension DictionaryMeaningQueryFilter
    on QueryBuilder<DictionaryMeaning, DictionaryMeaning, QFilterCondition> {
  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'words',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'words',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'words',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'words',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'words',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'words',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'words',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'words',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'words',
        value: '',
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'words',
        value: '',
      ));
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterFilterCondition>
      wordsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension DictionaryMeaningQueryObject
    on QueryBuilder<DictionaryMeaning, DictionaryMeaning, QFilterCondition> {}

extension DictionaryMeaningQueryLinks
    on QueryBuilder<DictionaryMeaning, DictionaryMeaning, QFilterCondition> {}

extension DictionaryMeaningQuerySortBy
    on QueryBuilder<DictionaryMeaning, DictionaryMeaning, QSortBy> {}

extension DictionaryMeaningQuerySortThenBy
    on QueryBuilder<DictionaryMeaning, DictionaryMeaning, QSortThenBy> {
  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }
}

extension DictionaryMeaningQueryWhereDistinct
    on QueryBuilder<DictionaryMeaning, DictionaryMeaning, QDistinct> {
  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QDistinct>
      distinctByWords() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'words');
    });
  }
}

extension DictionaryMeaningQueryProperty
    on QueryBuilder<DictionaryMeaning, DictionaryMeaning, QQueryProperty> {
  QueryBuilder<DictionaryMeaning, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DictionaryMeaning, List<String>, QQueryOperations>
      wordsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'words');
    });
  }
}
