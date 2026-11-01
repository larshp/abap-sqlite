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
    METHODS select_core FOR TESTING RAISING zcx_sqlite_error.
    METHODS select_joins FOR TESTING RAISING zcx_sqlite_error.
    METHODS select_values FOR TESTING RAISING zcx_sqlite_error.
    METHODS select_errors FOR TESTING.
    METHODS select_compound FOR TESTING RAISING zcx_sqlite_error.
    METHODS select_with FOR TESTING RAISING zcx_sqlite_error.
    METHODS select_subqueries FOR TESTING RAISING zcx_sqlite_error.
    METHODS select_advanced_errors FOR TESTING.
    METHODS insert_statements FOR TESTING RAISING zcx_sqlite_error.
    METHODS update_statements FOR TESTING RAISING zcx_sqlite_error.
    METHODS delete_statements FOR TESTING RAISING zcx_sqlite_error.
    METHODS dml_with FOR TESTING RAISING zcx_sqlite_error.
    METHODS dml_errors FOR TESTING.

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

  METHOD select_core.
    assert_statement_parse(
      iv_sql = |SELECT a, b + 1 FROM t WHERE c > 5|
      iv_expected = |SELECT COLUMN(a), BINARY(+, COLUMN(b), INTEGER(1)) FROM t WHERE BINARY(>, COLUMN(c), INTEGER(5))| ).
    assert_statement_parse(
      iv_sql = |SELECT DISTINCT t.*, * FROM main.t AS x|
      iv_expected = |SELECT DISTINCT COLUMN(t.*), STAR FROM main.t AS x| ).
    assert_statement_parse(
      iv_sql = |SELECT a AS x, b y FROM t;|
      iv_expected = |SELECT COLUMN(a) AS x, COLUMN(b) AS y FROM t| ).
    assert_statement_parse(
      iv_sql = |SELECT count(*) AS n FROM t GROUP BY a, b HAVING count(*) > 1 ORDER BY n DESC, 1 LIMIT 10 OFFSET 2|
      iv_expected = |SELECT FUNCTION(count, STAR) AS n FROM t GROUP BY COLUMN(a), COLUMN(b) HAVING BINARY(>, FUNCTION(count, STAR), INTEGER(1)) ORDER BY COLUMN(n) DESC, INTEGER(1) LIMIT INTEGER(10) OFFSET INTEGER(2)| ).
    assert_statement_parse(
      iv_sql = |SELECT ALL a FROM t|
      iv_expected = |SELECT COLUMN(a) FROM t| ).
    assert_statement_parse(
      iv_sql = |SELECT 1 + 2|
      iv_expected = |SELECT BINARY(+, INTEGER(1), INTEGER(2))| ).
    assert_statement_parse(
      iv_sql = |SELECT a FROM t ORDER BY a ASC NULLS LAST, b|
      iv_expected = |SELECT COLUMN(a) FROM t ORDER BY COLUMN(a) ASC NULLS LAST, COLUMN(b)| ).
    assert_statement_parse(
      iv_sql = |SELECT a FROM t LIMIT 5, 10|
      iv_expected = |SELECT COLUMN(a) FROM t LIMIT INTEGER(10) OFFSET INTEGER(5)| ).
    assert_statement_parse(
      iv_sql = |SELECT a FROM t LIMIT 10|
      iv_expected = |SELECT COLUMN(a) FROM t LIMIT INTEGER(10)| ).
    assert_statement_parse(
      iv_sql = |SELECT 'x' AS label|
      iv_expected = |SELECT STRING('x') AS label| ).
  ENDMETHOD.

  METHOD select_joins.
    assert_statement_parse(
      iv_sql = |SELECT * FROM a INNER JOIN b ON a.id = b.id LEFT OUTER JOIN c USING (id, x) CROSS JOIN d|
      iv_expected = |SELECT STAR FROM a INNER JOIN b ON BINARY(=, COLUMN(a.id), COLUMN(b.id)) LEFT JOIN c USING (id, x) CROSS JOIN d| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM a, b AS x, c y|
      iv_expected = |SELECT STAR FROM a, b AS x, c AS y| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM a JOIN b USING (id)|
      iv_expected = |SELECT STAR FROM a INNER JOIN b USING (id)| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM main.a AS x LEFT JOIN main.b y ON x.id = y.id|
      iv_expected = |SELECT STAR FROM main.a AS x LEFT JOIN main.b AS y ON BINARY(=, COLUMN(x.id), COLUMN(y.id))| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM a CROSS JOIN b|
      iv_expected = |SELECT STAR FROM a CROSS JOIN b| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM a, b JOIN c ON b.id = c.id|
      iv_expected = |SELECT STAR FROM a, b INNER JOIN c ON BINARY(=, COLUMN(b.id), COLUMN(c.id))| ).
  ENDMETHOD.

  METHOD select_values.
    assert_statement_parse(
      iv_sql = |VALUES (1, 'x'), (2, NULL)|
      iv_expected = |VALUES (INTEGER(1), STRING('x')), (INTEGER(2), NULL)| ).
    assert_statement_parse(
      iv_sql = |VALUES (1 + 2)|
      iv_expected = |VALUES (BINARY(+, INTEGER(1), INTEGER(2)))| ).
    assert_statement_parse(
      iv_sql = |VALUES (?)|
      iv_expected = |VALUES (PARAM(?))| ).
    assert_statement_parse(
      iv_sql = |VALUES (1, 2), (3, 4);|
      iv_expected = |VALUES (INTEGER(1), INTEGER(2)), (INTEGER(3), INTEGER(4))| ).
    assert_statement_parse(
      iv_sql = |VALUES (CURRENT_TIMESTAMP)|
      iv_expected = |VALUES (CURRENT_TIMESTAMP)| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM t;|
      iv_expected = |SELECT STAR FROM t| ).
  ENDMETHOD.

  METHOD select_errors.
    assert_statement_error( |SELECT| ).
    assert_statement_error( |SELECT FROM t| ).
    assert_statement_error( |SELECT a FROM| ).
    assert_statement_error( |SELECT a FROM t WHERE| ).
    assert_statement_error( |SELECT a FROM t GROUP| ).
    assert_statement_error( |SELECT a FROM t GROUP BY| ).
    assert_statement_error( |SELECT a FROM t HAVING| ).
    assert_statement_error( |SELECT a FROM t ORDER| ).
    assert_statement_error( |SELECT a FROM t ORDER BY| ).
    assert_statement_error( |SELECT a FROM t ORDER BY a NULLS| ).
    assert_statement_error( |SELECT a FROM t LIMIT| ).
    assert_statement_error( |SELECT a FROM t LIMIT 1 OFFSET| ).
    assert_statement_error( |SELECT a FROM t LIMIT 1,| ).
    assert_statement_error( |SELECT a FROM t WHERE a =| ).
    assert_statement_error( |SELECT a FROM t,| ).
    assert_statement_error( |SELECT a FROM t JOIN| ).
    assert_statement_error( |SELECT a FROM a INNER b| ).
    assert_statement_error( |SELECT a FROM a LEFT OUTER b| ).
    assert_statement_error( |SELECT a FROM a JOIN b USING id| ).
    assert_statement_error( |SELECT a FROM a JOIN b USING (id,)| ).
    assert_statement_error( |VALUES| ).
    assert_statement_error( |VALUES ()| ).
    assert_statement_error( |VALUES (1| ).
    assert_statement_error( |VALUES (1,)| ).
    assert_statement_error( |VALUES (1) (2)| ).
  ENDMETHOD.

  METHOD select_compound.
    assert_statement_parse(
      iv_sql = |SELECT 1 UNION SELECT 2|
      iv_expected = |SELECT INTEGER(1) UNION SELECT INTEGER(2)| ).
    assert_statement_parse(
      iv_sql = |SELECT 1 UNION ALL SELECT 2 INTERSECT SELECT 3 EXCEPT SELECT 4|
      iv_expected = |SELECT INTEGER(1) UNION ALL SELECT INTEGER(2) INTERSECT SELECT INTEGER(3) EXCEPT SELECT INTEGER(4)| ).
    assert_statement_parse(
      iv_sql = |SELECT a FROM t UNION SELECT a FROM u ORDER BY a DESC LIMIT 5 OFFSET 2|
      iv_expected = |SELECT COLUMN(a) FROM t UNION SELECT COLUMN(a) FROM u ORDER BY COLUMN(a) DESC LIMIT INTEGER(5) OFFSET INTEGER(2)| ).
    assert_statement_parse(
      iv_sql = |(SELECT 1 UNION SELECT 2) EXCEPT SELECT 3|
      iv_expected = |(SELECT INTEGER(1) UNION SELECT INTEGER(2)) EXCEPT SELECT INTEGER(3)| ).
    assert_statement_parse(
      iv_sql = |SELECT 1 UNION (SELECT 2 ORDER BY 1 LIMIT 1)|
      iv_expected = |SELECT INTEGER(1) UNION (SELECT INTEGER(2) ORDER BY INTEGER(1) LIMIT INTEGER(1))| ).
    assert_statement_parse(
      iv_sql = |VALUES (1) UNION SELECT 2|
      iv_expected = |VALUES (INTEGER(1)) UNION SELECT INTEGER(2)| ).
    assert_statement_parse(
      iv_sql = |VALUES (1), (2) ORDER BY 1|
      iv_expected = |VALUES (INTEGER(1)), (INTEGER(2)) ORDER BY INTEGER(1)| ).
    assert_statement_parse(
      iv_sql = |VALUES (1) LIMIT 2|
      iv_expected = |VALUES (INTEGER(1)) LIMIT INTEGER(2)| ).
  ENDMETHOD.

  METHOD select_with.
    assert_statement_parse(
      iv_sql = |WITH cte AS (SELECT 1) SELECT * FROM cte|
      iv_expected = |WITH cte AS (SELECT INTEGER(1)) SELECT STAR FROM cte| ).
    assert_statement_parse(
      iv_sql = |WITH cte(x, y) AS (SELECT 1, 2) SELECT x FROM cte|
      iv_expected = |WITH cte (x, y) AS (SELECT INTEGER(1), INTEGER(2)) SELECT COLUMN(x) FROM cte| ).
    assert_statement_parse(
      iv_sql = |WITH RECURSIVE cnt(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM cnt WHERE x < 10) SELECT x FROM cnt|
      iv_expected = |WITH RECURSIVE cnt (x) AS (SELECT INTEGER(1) UNION ALL SELECT BINARY(+, COLUMN(x), INTEGER(1)) FROM cnt WHERE BINARY(<, COLUMN(x), INTEGER(10))) SELECT COLUMN(x) FROM cnt| ).
    assert_statement_parse(
      iv_sql = |WITH a AS (SELECT 1), b AS (SELECT 2) SELECT * FROM a, b|
      iv_expected = |WITH a AS (SELECT INTEGER(1)), b AS (SELECT INTEGER(2)) SELECT STAR FROM a, b| ).
    assert_statement_parse(
      iv_sql = |WITH cte AS NOT MATERIALIZED (SELECT 1) SELECT * FROM cte|
      iv_expected = |WITH cte AS NOT MATERIALIZED (SELECT INTEGER(1)) SELECT STAR FROM cte| ).
    assert_statement_parse(
      iv_sql = |WITH cte AS (SELECT 1 UNION SELECT 2) SELECT * FROM cte|
      iv_expected = |WITH cte AS (SELECT INTEGER(1) UNION SELECT INTEGER(2)) SELECT STAR FROM cte| ).
    assert_statement_parse(
      iv_sql = |WITH a AS (WITH b AS (SELECT 1) SELECT * FROM b) SELECT * FROM a|
      iv_expected = |WITH a AS (WITH b AS (SELECT INTEGER(1)) SELECT STAR FROM b) SELECT STAR FROM a| ).
  ENDMETHOD.

  METHOD select_subqueries.
    assert_statement_parse(
      iv_sql = |SELECT (SELECT max(x) FROM t) AS m|
      iv_expected = |SELECT SUBQUERY(SELECT FUNCTION(max, COLUMN(x)) FROM t) AS m| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM t WHERE a IN (SELECT b FROM u)|
      iv_expected = |SELECT STAR FROM t WHERE IN(COLUMN(a), SELECT COLUMN(b) FROM u)| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM t WHERE a NOT IN (SELECT b FROM u WHERE c = 1)|
      iv_expected = |SELECT STAR FROM t WHERE NOT_IN(COLUMN(a), SELECT COLUMN(b) FROM u WHERE BINARY(=, COLUMN(c), INTEGER(1)))| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM t WHERE EXISTS (SELECT 1 FROM u)|
      iv_expected = |SELECT STAR FROM t WHERE EXISTS(SELECT INTEGER(1) FROM u)| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM t WHERE NOT EXISTS (SELECT 1)|
      iv_expected = |SELECT STAR FROM t WHERE UNARY(NOT, EXISTS(SELECT INTEGER(1)))| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM (SELECT a FROM t) AS x|
      iv_expected = |SELECT STAR FROM (SELECT COLUMN(a) FROM t) AS x| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM (SELECT a FROM t) x JOIN u ON x.a = u.a|
      iv_expected = |SELECT STAR FROM (SELECT COLUMN(a) FROM t) AS x INNER JOIN u ON BINARY(=, COLUMN(x.a), COLUMN(u.a))| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM (SELECT 1 UNION SELECT 2) AS x|
      iv_expected = |SELECT STAR FROM (SELECT INTEGER(1) UNION SELECT INTEGER(2)) AS x| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM (WITH cte AS (SELECT 1) SELECT * FROM cte) AS x|
      iv_expected = |SELECT STAR FROM (WITH cte AS (SELECT INTEGER(1)) SELECT STAR FROM cte) AS x| ).
    assert_statement_parse(
      iv_sql = |SELECT (SELECT 1 UNION SELECT 2)|
      iv_expected = |SELECT SUBQUERY(SELECT INTEGER(1) UNION SELECT INTEGER(2))| ).
    assert_statement_parse(
      iv_sql = |SELECT (VALUES (1))|
      iv_expected = |SELECT SUBQUERY(VALUES (INTEGER(1)))| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM t WHERE a IN (WITH cte AS (SELECT b FROM u) SELECT b FROM cte)|
      iv_expected = |SELECT STAR FROM t WHERE IN(COLUMN(a), WITH cte AS (SELECT COLUMN(b) FROM u) SELECT COLUMN(b) FROM cte)| ).
    assert_statement_parse(
      iv_sql = |SELECT * FROM t WHERE EXISTS (SELECT 1 UNION SELECT 2)|
      iv_expected = |SELECT STAR FROM t WHERE EXISTS(SELECT INTEGER(1) UNION SELECT INTEGER(2))| ).
  ENDMETHOD.

  METHOD select_advanced_errors.
    assert_statement_error( |SELECT 1 UNION| ).
    assert_statement_error( |SELECT 1 UNION ALL| ).
    assert_statement_error( |SELECT 1 UNION DISTINCT SELECT 2| ).
    assert_statement_error( |SELECT 1 INTERSECT| ).
    assert_statement_error( |SELECT 1 UNION (SELECT 2| ).
    assert_statement_error( |SELECT 1 UNION ()| ).
    assert_statement_error( |WITH| ).
    assert_statement_error( |WITH RECURSIVE| ).
    assert_statement_error( |WITH cte AS| ).
    assert_statement_error( |WITH cte AS ()| ).
    assert_statement_error( |WITH cte AS (SELECT 1)| ).
    assert_statement_error( |WITH cte AS (SELECT 1), SELECT 2| ).
    assert_statement_error( |WITH cte(x,) AS (SELECT 1) SELECT * FROM cte| ).
    assert_statement_error( |WITH cte AS MATERIALIZED SELECT 1| ).
    assert_statement_error( |WITH cte AS NOT (SELECT 1) SELECT * FROM cte| ).
    assert_statement_error( |SELECT * FROM (SELECT 1| ).
    assert_statement_error( |SELECT * FROM ()| ).
    assert_statement_error( |SELECT * FROM (SELECT 1) AS| ).
    assert_statement_error( |SELECT (SELECT 1| ).
    assert_statement_error( |SELECT EXISTS| ).
    assert_statement_error( |SELECT EXISTS (1)| ).
    assert_statement_error( |SELECT * FROM t WHERE a IN (SELECT 1| ).
    assert_statement_error( |VALUES (1) ORDER| ).
    assert_statement_error( |VALUES (1) LIMIT| ).
  ENDMETHOD.

  METHOD insert_statements.
    assert_statement_parse(
      iv_sql = |INSERT INTO items (id, value) VALUES (1, 'a'), (2, NULL)|
      iv_expected = |INSERT INTO items (id, value) VALUES (INTEGER(1), STRING('a')), (INTEGER(2), NULL)| ).
    assert_statement_parse(
      iv_sql = |INSERT OR REPLACE INTO main.t VALUES (NULL)|
      iv_expected = |INSERT OR REPLACE INTO main.t VALUES (NULL)| ).
    assert_statement_parse(
      iv_sql = |INSERT OR IGNORE INTO t (a, b) VALUES (1, 2)|
      iv_expected = |INSERT OR IGNORE INTO t (a, b) VALUES (INTEGER(1), INTEGER(2))| ).
    assert_statement_parse(
      iv_sql = |INSERT INTO t DEFAULT VALUES|
      iv_expected = |INSERT INTO t DEFAULT VALUES| ).
    assert_statement_parse(
      iv_sql = |INSERT INTO t (a) SELECT a FROM u WHERE b > 0|
      iv_expected = |INSERT INTO t (a) SELECT COLUMN(a) FROM u WHERE BINARY(>, COLUMN(b), INTEGER(0))| ).
    assert_statement_parse(
      iv_sql = |INSERT INTO t WITH cte AS (SELECT 1) SELECT * FROM cte|
      iv_expected = |INSERT INTO t WITH cte AS (SELECT INTEGER(1)) SELECT STAR FROM cte| ).
    assert_statement_parse(
      iv_sql = |INSERT INTO t VALUES (1), (2)|
      iv_expected = |INSERT INTO t VALUES (INTEGER(1)), (INTEGER(2))| ).
  ENDMETHOD.

  METHOD update_statements.
    assert_statement_parse(
      iv_sql = |UPDATE t SET a = 1, b = b + 1 WHERE id = 2|
      iv_expected = |UPDATE t SET a = INTEGER(1), b = BINARY(+, COLUMN(b), INTEGER(1)) WHERE BINARY(=, COLUMN(id), INTEGER(2))| ).
    assert_statement_parse(
      iv_sql = |UPDATE OR REPLACE main.t AS x SET a = NULL|
      iv_expected = |UPDATE OR REPLACE main.t AS x SET a = NULL| ).
    assert_statement_parse(
      iv_sql = |UPDATE t SET a = (SELECT max(x) FROM u) WHERE id IN (SELECT id FROM v)|
      iv_expected = |UPDATE t SET a = SUBQUERY(SELECT FUNCTION(max, COLUMN(x)) FROM u) WHERE IN(COLUMN(id), SELECT COLUMN(id) FROM v)| ).
    assert_statement_parse(
      iv_sql = |UPDATE t SET a = 1 FROM u WHERE t.id = u.id|
      iv_expected = |UPDATE t SET a = INTEGER(1) FROM u WHERE BINARY(=, COLUMN(t.id), COLUMN(u.id))| ).
    assert_statement_parse(
      iv_sql = |UPDATE t SET a = 1, b = 2|
      iv_expected = |UPDATE t SET a = INTEGER(1), b = INTEGER(2)| ).
  ENDMETHOD.

  METHOD delete_statements.
    assert_statement_parse(
      iv_sql = |DELETE FROM t|
      iv_expected = |DELETE FROM t| ).
    assert_statement_parse(
      iv_sql = |DELETE FROM main.t AS x WHERE x.id = 1|
      iv_expected = |DELETE FROM main.t AS x WHERE BINARY(=, COLUMN(x.id), INTEGER(1))| ).
    assert_statement_parse(
      iv_sql = |DELETE FROM t WHERE id IN (SELECT id FROM u)|
      iv_expected = |DELETE FROM t WHERE IN(COLUMN(id), SELECT COLUMN(id) FROM u)| ).
    assert_statement_parse(
      iv_sql = |DELETE FROM t WHERE EXISTS (SELECT 1)|
      iv_expected = |DELETE FROM t WHERE EXISTS(SELECT INTEGER(1))| ).
  ENDMETHOD.

  METHOD dml_with.
    assert_statement_parse(
      iv_sql = |WITH cte AS (SELECT 1) INSERT INTO t SELECT * FROM cte|
      iv_expected = |WITH cte AS (SELECT INTEGER(1)) INSERT INTO t SELECT STAR FROM cte| ).
    assert_statement_parse(
      iv_sql = |WITH cte AS (SELECT 1) UPDATE t SET a = 1|
      iv_expected = |WITH cte AS (SELECT INTEGER(1)) UPDATE t SET a = INTEGER(1)| ).
    assert_statement_parse(
      iv_sql = |WITH cte AS (SELECT 1) DELETE FROM t|
      iv_expected = |WITH cte AS (SELECT INTEGER(1)) DELETE FROM t| ).
  ENDMETHOD.

  METHOD dml_errors.
    assert_statement_error( |INSERT| ).
    assert_statement_error( |INSERT INTO| ).
    assert_statement_error( |INSERT INTO t| ).
    assert_statement_error( |INSERT OR INTO t| ).
    assert_statement_error( |INSERT INTO t DEFAULT| ).
    assert_statement_error( |INSERT INTO t DEFAULT VALUES RETURNING *| ).
    assert_statement_error( |INSERT INTO t (a,) VALUES (1)| ).
    assert_statement_error( |INSERT INTO t (a) VALUES| ).
    assert_statement_error( |INSERT INTO t VALUES (1) RETURNING *| ).
    assert_statement_error( |INSERT INTO t SELECT| ).
    assert_statement_error( |UPDATE| ).
    assert_statement_error( |UPDATE t| ).
    assert_statement_error( |UPDATE t SET| ).
    assert_statement_error( |UPDATE t SET a| ).
    assert_statement_error( |UPDATE t SET a =| ).
    assert_statement_error( |UPDATE t SET a = 1,| ).
    assert_statement_error( |UPDATE t SET a = 1 WHERE| ).
    assert_statement_error( |UPDATE OR t SET a = 1| ).
    assert_statement_error( |UPDATE t SET a = 1 RETURNING *| ).
    assert_statement_error( |DELETE| ).
    assert_statement_error( |DELETE FROM| ).
    assert_statement_error( |DELETE FROM t WHERE| ).
    assert_statement_error( |DELETE FROM t RETURNING *| ).
    assert_statement_error( |DELETE t| ).
    assert_statement_error( |WITH cte AS (SELECT 1) INSERT| ).
    assert_statement_error( |WITH cte AS (SELECT 1)| ).
    assert_statement_error( |WITH cte AS (SELECT 1) UPDATE| ).
    assert_statement_error( |WITH cte AS (SELECT 1) DELETE| ).
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
