CLASS ltcl_parser DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS literals FOR TESTING RAISING zcx_sqlite_error.
    METHODS names_and_parameters FOR TESTING RAISING zcx_sqlite_error.
    METHODS unary_and_precedence FOR TESTING RAISING zcx_sqlite_error.
    METHODS comparison_and_boolean FOR TESTING RAISING zcx_sqlite_error.
    METHODS in_between_like FOR TESTING RAISING zcx_sqlite_error.
    METHODS functions FOR TESTING RAISING zcx_sqlite_error.
    METHODS case_and_cast FOR TESTING RAISING zcx_sqlite_error.
    METHODS collate_json_match FOR TESTING RAISING zcx_sqlite_error.
    METHODS syntax_errors FOR TESTING.
    METHODS fixture_ddl FOR TESTING RAISING zcx_sqlite_error.
    METHODS create_table_constraints FOR TESTING RAISING zcx_sqlite_error.
    METHODS create_index_and_drop FOR TESTING RAISING zcx_sqlite_error.
    METHODS ddl_errors FOR TESTING.

    METHODS assert_parse
      IMPORTING iv_sql      TYPE string
                iv_expected TYPE string
      RAISING   zcx_sqlite_error.

    METHODS assert_error
      IMPORTING iv_sql TYPE string.

    METHODS assert_statement_parse
      IMPORTING iv_sql      TYPE string
                iv_expected TYPE string
      RAISING   zcx_sqlite_error.

    METHODS assert_statement_error
      IMPORTING iv_sql TYPE string.
ENDCLASS.


CLASS ltcl_parser IMPLEMENTATION.

  METHOD literals.
    assert_parse( iv_sql = 'NULL' iv_expected = 'NULL' ).
    assert_parse( iv_sql = '0' iv_expected = 'INTEGER(0)' ).
    assert_parse( iv_sql = '0x1F' iv_expected = 'INTEGER(0x1F)' ).
    assert_parse( iv_sql = '1.5' iv_expected = 'REAL(1.5)' ).
    assert_parse( iv_sql = '1e5' iv_expected = 'REAL(1e5)' ).
    assert_parse( iv_sql = |''| iv_expected = |STRING('')| ).
    assert_parse( iv_sql = |'it''s'| iv_expected = |STRING('it''s')| ).
    assert_parse( iv_sql = |X'1f'| iv_expected = |BLOB(X'1F')| ).
    assert_parse( iv_sql = 'CURRENT_DATE' iv_expected = 'CURRENT_DATE' ).
    assert_parse( iv_sql = 'CURRENT_TIME' iv_expected = 'CURRENT_TIME' ).
    assert_parse( iv_sql = 'CURRENT_TIMESTAMP' iv_expected = 'CURRENT_TIMESTAMP' ).
    assert_parse( iv_sql = '*' iv_expected = 'STAR' ).
  ENDMETHOD.

  METHOD names_and_parameters.
    assert_parse( iv_sql = 'a' iv_expected = 'COLUMN(a)' ).
    assert_parse( iv_sql = 'a.b' iv_expected = 'COLUMN(a.b)' ).
    assert_parse( iv_sql = 'main.t.c' iv_expected = 'COLUMN(main.t.c)' ).
    assert_parse( iv_sql = '"weird name"' iv_expected = 'COLUMN(weird name)' ).
    assert_parse( iv_sql = 't.*' iv_expected = 'COLUMN(t.*)' ).
    assert_parse( iv_sql = '?' iv_expected = 'PARAM(?)' ).
    assert_parse( iv_sql = '?12' iv_expected = 'PARAM(?12)' ).
    assert_parse( iv_sql = ':name' iv_expected = 'PARAM(:name)' ).
    assert_parse( iv_sql = '@name' iv_expected = 'PARAM(@name)' ).
    assert_parse( iv_sql = '$name' iv_expected = 'PARAM($name)' ).
  ENDMETHOD.

  METHOD unary_and_precedence.
    assert_parse( iv_sql = '-1' iv_expected = 'UNARY(-, INTEGER(1))' ).
    assert_parse( iv_sql = '+1' iv_expected = 'UNARY(+, INTEGER(1))' ).
    assert_parse( iv_sql = '~1' iv_expected = 'UNARY(~, INTEGER(1))' ).
    assert_parse( iv_sql = 'NOT a' iv_expected = 'UNARY(NOT, COLUMN(a))' ).
    assert_parse(
      iv_sql = '1 + 2 * 3'
      iv_expected = 'BINARY(+, INTEGER(1), BINARY(*, INTEGER(2), INTEGER(3)))' ).
    assert_parse(
      iv_sql = '(1 + 2) * 3'
      iv_expected = 'BINARY(*, BINARY(+, INTEGER(1), INTEGER(2)), INTEGER(3))' ).
    assert_parse(
      iv_sql = '1 * 2 + 3'
      iv_expected = 'BINARY(+, BINARY(*, INTEGER(1), INTEGER(2)), INTEGER(3))' ).
    assert_parse(
      iv_sql = 'a || b || c'
      iv_expected = 'BINARY(||, BINARY(||, COLUMN(a), COLUMN(b)), COLUMN(c))' ).
    assert_parse(
      iv_sql = '-a * b'
      iv_expected = 'BINARY(*, UNARY(-, COLUMN(a)), COLUMN(b))' ).
    assert_parse(
      iv_sql = 'NOT a = b'
      iv_expected = 'UNARY(NOT, BINARY(=, COLUMN(a), COLUMN(b)))' ).
    assert_parse(
      iv_sql = 'a AND NOT b'
      iv_expected = 'BINARY(AND, COLUMN(a), UNARY(NOT, COLUMN(b)))' ).
  ENDMETHOD.

  METHOD comparison_and_boolean.
    assert_parse(
      iv_sql = 'a OR b AND c'
      iv_expected = 'BINARY(OR, COLUMN(a), BINARY(AND, COLUMN(b), COLUMN(c)))' ).
    assert_parse(
      iv_sql = 'a = b < c'
      iv_expected = 'BINARY(=, COLUMN(a), BINARY(<, COLUMN(b), COLUMN(c)))' ).
    assert_parse(
      iv_sql = 'a < b = c'
      iv_expected = 'BINARY(=, BINARY(<, COLUMN(a), COLUMN(b)), COLUMN(c))' ).
    assert_parse(
      iv_sql = 'a IS NULL'
      iv_expected = 'BINARY(IS, COLUMN(a), NULL)' ).
    assert_parse(
      iv_sql = 'a IS NOT NULL'
      iv_expected = 'BINARY(IS NOT, COLUMN(a), NULL)' ).
    assert_parse(
      iv_sql = 'a IS b'
      iv_expected = 'BINARY(IS, COLUMN(a), COLUMN(b))' ).
    assert_parse(
      iv_sql = 'a IS NOT b'
      iv_expected = 'BINARY(IS NOT, COLUMN(a), COLUMN(b))' ).
    assert_parse(
      iv_sql = 'a ISNULL'
      iv_expected = 'UNARY(ISNULL, COLUMN(a))' ).
    assert_parse(
      iv_sql = 'a NOTNULL'
      iv_expected = 'UNARY(NOTNULL, COLUMN(a))' ).
    assert_parse(
      iv_sql = 'a NOT NULL'
      iv_expected = 'UNARY(NOTNULL, COLUMN(a))' ).
  ENDMETHOD.

  METHOD in_between_like.
    assert_parse(
      iv_sql = 'a IN (1, 2, 3)'
      iv_expected = 'IN(COLUMN(a), INTEGER(1), INTEGER(2), INTEGER(3))' ).
    assert_parse(
      iv_sql = |a NOT IN (1, 'x')|
      iv_expected = |NOT_IN(COLUMN(a), INTEGER(1), STRING('x'))| ).
    assert_parse(
      iv_sql = 'a BETWEEN 1 AND 2'
      iv_expected = 'BETWEEN(COLUMN(a), INTEGER(1), INTEGER(2))' ).
    assert_parse(
      iv_sql = 'a NOT BETWEEN b + 1 AND c * 2'
      iv_expected = 'NOT_BETWEEN(COLUMN(a), BINARY(+, COLUMN(b), INTEGER(1)), BINARY(*, COLUMN(c), INTEGER(2)))' ).
    assert_parse(
      iv_sql = |a LIKE 'x%'|
      iv_expected = |LIKE(COLUMN(a), STRING('x%'))| ).
    assert_parse(
      iv_sql = |a NOT LIKE 'x%' ESCAPE '\\'|
      iv_expected = |NOT_LIKE(COLUMN(a), STRING('x%'), ESCAPE(STRING('\\')))| ).
    assert_parse(
      iv_sql = |a GLOB 'x*'|
      iv_expected = |GLOB(COLUMN(a), STRING('x*'))| ).
    assert_parse(
      iv_sql = |a NOT GLOB 'x*'|
      iv_expected = |NOT_GLOB(COLUMN(a), STRING('x*'))| ).
  ENDMETHOD.

  METHOD functions.
    assert_parse( iv_sql = 'random()' iv_expected = 'FUNCTION(random)' ).
    assert_parse(
      iv_sql = 'count(*)'
      iv_expected = 'FUNCTION(count, STAR)' ).
    assert_parse(
      iv_sql = 'count(DISTINCT a)'
      iv_expected = 'FUNCTION(count, DISTINCT, COLUMN(a))' ).
    assert_parse(
      iv_sql = 'abs(-1)'
      iv_expected = 'FUNCTION(abs, UNARY(-, INTEGER(1)))' ).
    assert_parse(
      iv_sql = 'coalesce(a, b, 3)'
      iv_expected = 'FUNCTION(coalesce, COLUMN(a), COLUMN(b), INTEGER(3))' ).
    assert_parse(
      iv_sql = |printf('%d', a)|
      iv_expected = |FUNCTION(printf, STRING('%d'), COLUMN(a))| ).
    assert_parse(
      iv_sql = 'sum(a + b)'
      iv_expected = 'FUNCTION(sum, BINARY(+, COLUMN(a), COLUMN(b)))' ).
  ENDMETHOD.

  METHOD case_and_cast.
    assert_parse(
      iv_sql = 'CASE WHEN a THEN 1 ELSE 2 END'
      iv_expected = 'CASE(WHEN(COLUMN(a), INTEGER(1)), ELSE(INTEGER(2)))' ).
    assert_parse(
      iv_sql = |CASE a WHEN 1 THEN 'x' WHEN 2 THEN 'y' END|
      iv_expected = |CASE(COLUMN(a), WHEN(INTEGER(1), STRING('x')), WHEN(INTEGER(2), STRING('y')))| ).
    assert_parse(
      iv_sql = 'CASE WHEN a THEN CASE WHEN b THEN 1 END END'
      iv_expected = 'CASE(WHEN(COLUMN(a), CASE(WHEN(COLUMN(b), INTEGER(1)))))' ).
    assert_parse(
      iv_sql = 'CAST(a AS INTEGER)'
      iv_expected = 'CAST(COLUMN(a), INTEGER)' ).
    assert_parse(
      iv_sql = 'CAST(a AS VARCHAR(10))'
      iv_expected = 'CAST(COLUMN(a), VARCHAR(10))' ).
    assert_parse(
      iv_sql = 'CAST(a AS DECIMAL(10, 2))'
      iv_expected = 'CAST(COLUMN(a), DECIMAL(10,2))' ).
    assert_parse(
      iv_sql = 'CAST(a AS DOUBLE PRECISION)'
      iv_expected = 'CAST(COLUMN(a), DOUBLE PRECISION)' ).
  ENDMETHOD.

  METHOD collate_json_match.
    assert_parse(
      iv_sql = 'a COLLATE NOCASE'
      iv_expected = 'COLLATE(COLUMN(a), NOCASE)' ).
    assert_parse(
      iv_sql = 'a || b COLLATE NOCASE'
      iv_expected = 'BINARY(||, COLUMN(a), COLLATE(COLUMN(b), NOCASE))' ).
    assert_parse(
      iv_sql = 'a COLLATE NOCASE || b'
      iv_expected = 'BINARY(||, COLLATE(COLUMN(a), NOCASE), COLUMN(b))' ).
    assert_parse(
      iv_sql = |a -> '$.x'|
      iv_expected = |BINARY(->, COLUMN(a), STRING('$.x'))| ).
    assert_parse(
      iv_sql = |a ->> '$.x'|
      iv_expected = |BINARY(->>, COLUMN(a), STRING('$.x'))| ).
    assert_parse(
      iv_sql = |a MATCH 'x'|
      iv_expected = |BINARY(MATCH, COLUMN(a), STRING('x'))| ).
    assert_parse(
      iv_sql = |a REGEXP 'x'|
      iv_expected = |BINARY(REGEXP, COLUMN(a), STRING('x'))| ).
  ENDMETHOD.

  METHOD syntax_errors.
    assert_error( '1 +' ).
    assert_error( 'CASE WHEN a THEN 1' ).
    assert_error( 'a IN 1' ).
    assert_error( 'a IN ()' ).
    assert_error( 'a BETWEEN 1' ).
    assert_error( 'f(' ).
    assert_error( 'CAST(a INTEGER)' ).
    assert_error( 'a COLLATE' ).
    assert_error( 'a NOT' ).
    assert_error( '1 2' ).
  ENDMETHOD.

  METHOD fixture_ddl.
    DATA lt_sql TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA lv_sql TYPE string.
    DATA lv_dump TYPE string.

    APPEND |CREATE TABLE items (id INTEGER NOT NULL, value TEXT NOT NULL)| TO lt_sql.
    APPEND |CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT NOT NULL)| TO lt_sql.
    APPEND |CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL)| TO lt_sql.
    APPEND |CREATE TABLE items (value TEXT NOT NULL)| TO lt_sql.
    APPEND |CREATE INDEX items_value ON items(value)| TO lt_sql.
    APPEND |CREATE TABLE keep (id INTEGER NOT NULL, value TEXT NOT NULL)| TO lt_sql.
    APPEND |CREATE INDEX keep_value ON keep(value)| TO lt_sql.
    APPEND |CREATE TABLE m (id INTEGER NOT NULL, a TEXT NOT NULL, b INTEGER NOT NULL, c TEXT NOT NULL)| TO lt_sql.
    APPEND |CREATE INDEX m_a ON m(a)| TO lt_sql.
    APPEND |CREATE INDEX m_ab ON m(a, b)| TO lt_sql.
    APPEND |CREATE INDEX m_b ON m(b)| TO lt_sql.
    APPEND |CREATE INDEX m_ba ON m(b, a)| TO lt_sql.
    APPEND |CREATE INDEX m_c ON m(c)| TO lt_sql.
    APPEND |CREATE TABLE nulls (id INTEGER NOT NULL, a TEXT, b INTEGER, c BLOB)| TO lt_sql.
    APPEND |CREATE INDEX nulls_a ON nulls(a)| TO lt_sql.
    APPEND |CREATE INDEX nulls_ab ON nulls(a, b)| TO lt_sql.
    APPEND |CREATE TABLE payloads (name TEXT NOT NULL, value)| TO lt_sql.
    APPEND |CREATE TABLE serial_types (c_null, c_int8, c_int16, c_int24, c_int32, c_int48, c_int64, c_real, c_zero, c_one, c_blob0, c_text0, c_blob3, c_text3, c_text)| TO lt_sql.
    APPEND |CREATE TABLE wr (k TEXT PRIMARY KEY, v TEXT, n INTEGER) WITHOUT ROWID| TO lt_sql.
    APPEND |CREATE INDEX wr_v ON wr(v)| TO lt_sql.

    LOOP AT lt_sql INTO lv_sql.
      TRY.
          lv_dump = zcl_sqlite_parser=>dump_statement( lv_sql ).
        CATCH zcx_sqlite_error INTO DATA(lo_error).
          cl_abap_unit_assert=>fail( msg = |fixture DDL did not parse: { lv_sql }: { lo_error->get_text( ) }| ).
      ENDTRY.
      cl_abap_unit_assert=>assert_true(
        act = boolc( lv_dump IS NOT INITIAL )
        msg = |fixture DDL did not parse: { lv_sql }| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD create_table_constraints.
    assert_statement_parse(
      iv_sql = |CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL)|
      iv_expected = |CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL)| ).
    assert_statement_parse(
      iv_sql = |CREATE TABLE IF NOT EXISTS main.t (id INTEGER, name TEXT, PRIMARY KEY (id, name)) WITHOUT ROWID|
      iv_expected = |CREATE TABLE IF NOT EXISTS main.t (id INTEGER, name TEXT, PRIMARY KEY (id, name)) WITHOUT ROWID| ).
    assert_statement_parse(
      iv_sql = |CREATE TABLE t (a INTEGER, b TEXT, CONSTRAINT pk PRIMARY KEY (a, b) ON CONFLICT ABORT, CONSTRAINT uq UNIQUE (b COLLATE NOCASE DESC))|
      iv_expected = |CREATE TABLE t (a INTEGER, b TEXT, CONSTRAINT pk PRIMARY KEY (a, b) ON CONFLICT ABORT, CONSTRAINT uq UNIQUE (b COLLATE NOCASE DESC))| ).
    assert_statement_parse(
      iv_sql = |CREATE TABLE c (id INTEGER CONSTRAINT pk PRIMARY KEY DESC ON CONFLICT ROLLBACK AUTOINCREMENT, code TEXT COLLATE NOCASE, n INTEGER NOT NULL ON CONFLICT IGNORE, x INTEGER CHECK(x > 0), y TEXT DEFAULT 'a', z INTEGER DEFAULT (1 + 2))|
      iv_expected = |CREATE TABLE c (id INTEGER CONSTRAINT pk PRIMARY KEY DESC ON CONFLICT ROLLBACK AUTOINCREMENT, code TEXT COLLATE NOCASE, n INTEGER NOT NULL ON CONFLICT IGNORE, x INTEGER CHECK(BINARY(>, COLUMN(x), INTEGER(0))), y TEXT DEFAULT(STRING('a')), z INTEGER DEFAULT(BINARY(+, INTEGER(1), INTEGER(2))))| ).
    assert_statement_parse(
      iv_sql = |CREATE TABLE child (id INTEGER, parent_id INTEGER, CONSTRAINT fk FOREIGN KEY (parent_id) REFERENCES parent(id) ON DELETE CASCADE ON UPDATE SET NULL MATCH simple DEFERRABLE INITIALLY DEFERRED)|
      iv_expected = |CREATE TABLE child (id INTEGER, parent_id INTEGER, CONSTRAINT fk FOREIGN KEY (parent_id) REFERENCES parent (id) ON DELETE CASCADE ON UPDATE SET NULL MATCH simple DEFERRABLE INITIALLY DEFERRED)| ).
    assert_statement_parse(
      iv_sql = |CREATE TABLE g (a INTEGER, b INTEGER GENERATED ALWAYS AS (a + 1) STORED, c AS (a * 2) VIRTUAL)|
      iv_expected = |CREATE TABLE g (a INTEGER, b INTEGER GENERATED ALWAYS AS (BINARY(+, COLUMN(a), INTEGER(1))) STORED, c GENERATED ALWAYS AS (BINARY(*, COLUMN(a), INTEGER(2))) VIRTUAL)| ).
    assert_statement_parse(
      iv_sql = |CREATE TABLE types (a DECIMAL(10, 2), b DOUBLE PRECISION, c VARCHAR(10))|
      iv_expected = |CREATE TABLE types (a DECIMAL(10,2), b DOUBLE PRECISION, c VARCHAR(10))| ).
    assert_statement_parse(
      iv_sql = |CREATE TEMP TABLE t (a) WITHOUT ROWID, STRICT|
      iv_expected = |CREATE TEMP TABLE t (a) WITHOUT ROWID, STRICT| ).
  ENDMETHOD.

  METHOD create_index_and_drop.
    assert_statement_parse(
      iv_sql = |CREATE UNIQUE INDEX IF NOT EXISTS idx ON main.items (a COLLATE NOCASE DESC, b) WHERE a > 0|
      iv_expected = |CREATE UNIQUE INDEX IF NOT EXISTS idx ON main.items (a COLLATE NOCASE DESC, b) WHERE BINARY(>, COLUMN(a), INTEGER(0))| ).
    assert_statement_parse(
      iv_sql = |CREATE INDEX idx ON t(a)|
      iv_expected = |CREATE INDEX idx ON t (a)| ).
    assert_statement_parse(
      iv_sql = |DROP TABLE IF EXISTS main.items|
      iv_expected = |DROP TABLE IF EXISTS main.items| ).
    assert_statement_parse(
      iv_sql = |DROP INDEX IF EXISTS idx|
      iv_expected = |DROP INDEX IF EXISTS idx| ).
    assert_statement_parse(
      iv_sql = |CREATE TABLE t (a);|
      iv_expected = |CREATE TABLE t (a)| ).
    assert_statement_parse(
      iv_sql = |DROP INDEX idx;|
      iv_expected = |DROP INDEX idx| ).
  ENDMETHOD.

  METHOD ddl_errors.
    assert_statement_error( |CREATE VIEW v AS SELECT 1| ).
    assert_statement_error( |CREATE TABLE| ).
    assert_statement_error( |CREATE TABLE t ()| ).
    assert_statement_error( |CREATE TABLE t (a INTEGER PRIMARY)| ).
    assert_statement_error( |CREATE TABLE t (a INTEGER DEFAULT)| ).
    assert_statement_error( |CREATE TABLE t (a INTEGER CHECK a)| ).
    assert_statement_error( |CREATE TABLE t (a INTEGER REFERENCES p ON DELETE)| ).
    assert_statement_error( |CREATE INDEX idx t(a)| ).
    assert_statement_error( |CREATE INDEX idx ON t ()| ).
    assert_statement_error( |DROP TABLE| ).
    assert_statement_error( |DROP VIEW v| ).
    assert_statement_error( |CREATE TABLE t (a INTEGER) WITH ROWID| ).
    assert_statement_error( |CREATE TABLE t (a INTEGER) WITHOUT| ).
    assert_statement_error( |CREATE TABLE t (a INTEGER) EXTRA| ).
    assert_statement_error( |CREATE TABLE t (a INTEGER| ).
    assert_statement_error( |CREATE TABLE t (a INTEGER, )| ).
    assert_statement_error( |CREATE TABLE t (PRIMARY KEY (a))| ).
    assert_statement_error( |CREATE TABLE t (a INTEGER, PRIMARY KEY ())| ).
    assert_statement_error( |CREATE UNIQUE TABLE t (a)| ).
    assert_statement_error( |CREATE TEMP INDEX idx ON t(a)| ).
  ENDMETHOD.

  METHOD assert_parse.
    DATA lv_actual TYPE string.

    lv_actual = zcl_sqlite_parser=>dump_expression( iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_actual
      exp = iv_expected
      msg = |dump for { iv_sql }| ).
  ENDMETHOD.

  METHOD assert_error.
    TRY.
        zcl_sqlite_parser=>dump_expression( iv_sql ).
        cl_abap_unit_assert=>fail( msg = |expected a syntax error for { iv_sql }| ).
      CATCH zcx_sqlite_error.
    ENDTRY.
  ENDMETHOD.

  METHOD assert_statement_parse.
    DATA lv_actual TYPE string.

    lv_actual = zcl_sqlite_parser=>dump_statement( iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_actual
      exp = iv_expected
      msg = |statement dump for { iv_sql }| ).
  ENDMETHOD.

  METHOD assert_statement_error.
    TRY.
        zcl_sqlite_parser=>dump_statement( iv_sql ).
        cl_abap_unit_assert=>fail( msg = |expected a statement error for { iv_sql }| ).
      CATCH zcx_sqlite_error.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
