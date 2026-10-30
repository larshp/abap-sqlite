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

    METHODS assert_parse
      IMPORTING iv_sql      TYPE string
                iv_expected TYPE string
      RAISING   zcx_sqlite_error.

    METHODS assert_error
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

ENDCLASS.
