CLASS ltcl_expr_eval DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS literals FOR TESTING RAISING zcx_sqlite_error.
    METHODS arithmetic FOR TESTING RAISING zcx_sqlite_error.
    METHODS logic FOR TESTING RAISING zcx_sqlite_error.
    METHODS comparisons FOR TESTING RAISING zcx_sqlite_error.
    METHODS coercions FOR TESTING RAISING zcx_sqlite_error.
    METHODS case_expressions FOR TESTING RAISING zcx_sqlite_error.
    METHODS in_between FOR TESTING RAISING zcx_sqlite_error.
    METHODS real_text FOR TESTING RAISING zcx_sqlite_error.
    METHODS bitwise FOR TESTING RAISING zcx_sqlite_error.
    METHODS integer_boundaries FOR TESTING RAISING zcx_sqlite_error.
    METHODS cast_types FOR TESTING RAISING zcx_sqlite_error.
    METHODS collations FOR TESTING RAISING zcx_sqlite_error.
    METHODS like_patterns FOR TESTING RAISING zcx_sqlite_error.
    METHODS glob_patterns FOR TESTING RAISING zcx_sqlite_error.
    METHODS pattern_errors FOR TESTING.
    METHODS hex_error FOR TESTING.
    METHODS scalar_numeric FOR TESTING RAISING zcx_sqlite_error.
    METHODS scalar_text FOR TESTING RAISING zcx_sqlite_error.
    METHODS scalar_conditional FOR TESTING RAISING zcx_sqlite_error.
    METHODS scalar_blobs FOR TESTING RAISING zcx_sqlite_error.
    METHODS function_errors FOR TESTING.
    METHODS random_function FOR TESTING RAISING zcx_sqlite_error.

    METHODS assert_integer
      IMPORTING iv_sql      TYPE string
                iv_expected TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS assert_real
      IMPORTING iv_sql      TYPE string
                iv_expected TYPE f
      RAISING   zcx_sqlite_error.

    METHODS assert_text
      IMPORTING iv_sql      TYPE string
                iv_expected TYPE string
      RAISING   zcx_sqlite_error.

    METHODS assert_null
      IMPORTING iv_sql TYPE string
      RAISING   zcx_sqlite_error.

    METHODS assert_blob
      IMPORTING iv_sql      TYPE string
                iv_expected TYPE xstring
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS ltcl_expr_eval IMPLEMENTATION.

  METHOD literals.
    assert_null( 'SELECT NULL' ).
    assert_integer( iv_sql      = 'SELECT 42'
                    iv_expected = 42 ).
    assert_real( iv_sql      = 'SELECT 1.5'
                 iv_expected = '1.5' ).
    assert_text( iv_sql      = 'SELECT ''abc'''
                 iv_expected = 'abc' ).
    assert_blob( iv_sql      = 'SELECT x''4142'''
                 iv_expected = '4142' ).
    assert_integer( iv_sql      = 'SELECT 0xFFFFFFFFFFFFFFFF'
                    iv_expected = -1 ).
    assert_integer( iv_sql = 'SELECT 0x8000000000000000'
      iv_expected          = -9223372036854775808 ).
    assert_real( iv_sql = 'SELECT 9223372036854775808'
      iv_expected       = '9223372036854775808' ).
  ENDMETHOD.

  METHOD arithmetic.
    assert_integer( iv_sql      = 'SELECT 1 + 2'
                    iv_expected = 3 ).
    assert_real( iv_sql      = 'SELECT 1.5 + 2'
                 iv_expected = '3.5' ).
    assert_integer( iv_sql      = 'SELECT 7 / 2'
                    iv_expected = 3 ).
    assert_integer( iv_sql      = 'SELECT -7 / 2'
                    iv_expected = -3 ).
    assert_integer( iv_sql      = 'SELECT 7 % 2'
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT -7 % 2'
                    iv_expected = -1 ).
    assert_null( 'SELECT 1 / 0' ).
    assert_null( 'SELECT 1.0 / 0' ).
    assert_real( iv_sql      = 'SELECT 5.5 % 2'
                 iv_expected = '1.0' ).
    assert_real( iv_sql      = 'SELECT 5.0 % 2'
                 iv_expected = '1.0' ).
    assert_real( iv_sql = 'SELECT 9223372036854775807 + 1'
      iv_expected       = '9223372036854775808' ).
    assert_real( iv_sql = 'SELECT 9223372036854775807 * 2'
      iv_expected       = '18446744073709551616' ).
  ENDMETHOD.

  METHOD logic.
    assert_integer( iv_sql      = 'SELECT NULL AND 0'
                    iv_expected = 0 ).
    assert_null( 'SELECT NULL AND 1' ).
    assert_integer( iv_sql      = 'SELECT 0 AND (1 / 0)'
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT 1 OR (1 / 0)'
                    iv_expected = 1 ).
    assert_null( 'SELECT NULL OR 0' ).
    assert_integer( iv_sql      = 'SELECT NULL OR 1'
                    iv_expected = 1 ).
    assert_null( 'SELECT NOT NULL' ).
    assert_integer( iv_sql      = 'SELECT NOT 0'
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT NOT ''abc'''
                    iv_expected = 1 ).
  ENDMETHOD.

  METHOD comparisons.
    assert_integer( iv_sql      = 'SELECT 1 = 1.0'
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT 1 = ''1'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT ''1'' = ''1'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT 1 < 1.5'
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT 2 > 1.5'
                    iv_expected = 1 ).
    assert_integer( iv_sql = 'SELECT 9007199254740993 = 9007199254740992.0'
      iv_expected          = 0 ).
    assert_integer( iv_sql      = 'SELECT ''a'' < ''b'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT x''41'' < x''42'''
                    iv_expected = 1 ).
    assert_null( 'SELECT NULL = NULL' ).
    assert_integer( iv_sql      = 'SELECT 1 IS NULL'
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT NULL IS NULL'
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT NULL IS NOT NULL'
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT 1 IS NOT 1'
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT ''1'' IS 1'
                    iv_expected = 0 ).
  ENDMETHOD.

  METHOD coercions.
    assert_integer( iv_sql      = 'SELECT ''12'' + 1'
                    iv_expected = 13 ).
    assert_integer( iv_sql      = 'SELECT ''12abc'' + 1'
                    iv_expected = 13 ).
    assert_real( iv_sql      = 'SELECT ''1.5'' + 1'
                 iv_expected = '2.5' ).
    assert_integer( iv_sql      = 'SELECT ''abc'' + 1'
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''  -12 '' + 1'
                    iv_expected = -11 ).
    assert_real( iv_sql      = 'SELECT ''1e2'' + 1'
                 iv_expected = '101.0' ).
    assert_text( iv_sql      = 'SELECT 1 || 2.0'
                 iv_expected = '12.0' ).
    assert_null( 'SELECT ''a'' || NULL' ).
  ENDMETHOD.

  METHOD case_expressions.
    assert_text( iv_sql = 'SELECT CASE WHEN 1 THEN ''yes'' ELSE ''no'' END'
      iv_expected       = 'yes' ).
    assert_text( iv_sql = 'SELECT CASE 1 WHEN 1.0 THEN ''match'' ELSE ''no'' END'
      iv_expected       = 'match' ).
    assert_text( iv_sql = 'SELECT CASE NULL WHEN NULL THEN ''x'' ELSE ''y'' END'
      iv_expected       = 'y' ).
    assert_text( iv_sql = 'SELECT CASE ''1'' WHEN 1 THEN ''x'' ELSE ''y'' END'
      iv_expected       = 'y' ).
    assert_null( 'SELECT CASE WHEN 0 THEN ''x'' END' ).
  ENDMETHOD.

  METHOD in_between.
    assert_integer( iv_sql      = 'SELECT 1 BETWEEN 1 AND 2'
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT 1 BETWEEN 2 AND 0'
                    iv_expected = 0 ).
    assert_null( 'SELECT NULL BETWEEN 0 AND 1' ).
    assert_integer( iv_sql      = 'SELECT 1 NOT BETWEEN 2 AND 0'
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT 1 IN (2, 1)'
                    iv_expected = 1 ).
    assert_null( 'SELECT 1 IN (2, NULL)' ).
    assert_null( 'SELECT 1 NOT IN (2, NULL)' ).
    assert_null( 'SELECT NULL IN (1)' ).
    assert_integer( iv_sql      = 'SELECT 1 NOT IN (2, 3)'
                    iv_expected = 1 ).
  ENDMETHOD.

  METHOD real_text.
    assert_text( iv_sql      = 'SELECT CAST(1.0 AS TEXT)'
                 iv_expected = '1.0' ).
    assert_text( iv_sql      = 'SELECT CAST(0.1 AS TEXT)'
                 iv_expected = '0.1' ).
    assert_text( iv_sql = 'SELECT CAST(1.2345678901234567 AS TEXT)'
      iv_expected       = '1.23456789012346' ).
    assert_text( iv_sql = 'SELECT CAST(1.0 / 3 AS TEXT)'
      iv_expected       = '0.333333333333333' ).
    assert_text( iv_sql      = 'SELECT CAST(1e15 AS TEXT)'
                 iv_expected = '1.0e+15' ).
    assert_text( iv_sql      = 'SELECT CAST(1e-5 AS TEXT)'
                 iv_expected = '1.0e-05' ).
    assert_text( iv_sql      = 'SELECT CAST(0.0001 AS TEXT)'
                 iv_expected = '0.0001' ).
    assert_text( iv_sql      = 'SELECT CAST(-1.5 AS TEXT)'
                 iv_expected = '-1.5' ).
  ENDMETHOD.

  METHOD bitwise.
    assert_integer( iv_sql      = 'SELECT ~0'
                    iv_expected = -1 ).
    assert_integer( iv_sql      = 'SELECT 1 << 3'
                    iv_expected = 8 ).
    assert_integer( iv_sql = 'SELECT 1 << 63'
      iv_expected          = -9223372036854775808 ).
    assert_integer( iv_sql      = 'SELECT 1 << 64'
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT -1 >> 1'
                    iv_expected = -1 ).
    assert_integer( iv_sql      = 'SELECT -1 >> 64'
                    iv_expected = -1 ).
    assert_integer( iv_sql      = 'SELECT 1 >> -1'
                    iv_expected = 2 ).
    assert_integer( iv_sql      = 'SELECT 8 >> -1'
                    iv_expected = 16 ).
    assert_integer( iv_sql      = 'SELECT -8 << -1'
                    iv_expected = -4 ).
    assert_integer( iv_sql      = 'SELECT -8 >> -1'
                    iv_expected = -16 ).
    assert_integer( iv_sql      = 'SELECT 1 << -1'
                    iv_expected = 0 ).
  ENDMETHOD.

  METHOD integer_boundaries.
    assert_integer( iv_sql = 'SELECT CAST(''-9223372036854775808'' AS INTEGER)'
      iv_expected          = -9223372036854775808 ).
    assert_integer( iv_sql = 'SELECT -9223372036854775808'
      iv_expected          = -9223372036854775808 ).
    assert_integer( iv_sql = 'SELECT - 0009223372036854775808'
      iv_expected          = -9223372036854775808 ).
    assert_real( iv_sql = 'SELECT -9223372036854775809'
      iv_expected       = '-9223372036854775809' ).
    assert_integer( iv_sql = 'SELECT (-9223372036854775808) % -1'
      iv_expected          = 0 ).
  ENDMETHOD.

  METHOD cast_types.
    assert_integer( iv_sql = 'SELECT CAST(''12.9'' AS INTEGER)'
      iv_expected          = 12 ).
    assert_real( iv_sql = 'SELECT CAST(''12.9'' AS REAL)'
      iv_expected       = '12.9' ).
    assert_integer( iv_sql = 'SELECT CAST(''12.0'' AS NUMERIC)'
      iv_expected          = 12 ).
    assert_real( iv_sql = 'SELECT CAST(''12.5'' AS NUMERIC)'
      iv_expected       = '12.5' ).
    assert_text( iv_sql      = 'SELECT CAST(1.5 AS TEXT)'
                 iv_expected = '1.5' ).
    assert_text( iv_sql      = 'SELECT CAST(1 AS TEXT)'
                 iv_expected = '1' ).
    assert_blob( iv_sql      = 'SELECT CAST(''abc'' AS BLOB)'
                 iv_expected = '616263' ).
    assert_text( iv_sql      = 'SELECT CAST(x''4142'' AS TEXT)'
                 iv_expected = 'AB' ).
  ENDMETHOD.

  METHOD collations.
    assert_integer( iv_sql      = 'SELECT ''a'' = ''A'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT ''a'' = ''A'' COLLATE NOCASE'
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''a'' COLLATE NOCASE = ''A'''
                    iv_expected = 1 ).
    assert_integer( iv_sql                                             =
      'SELECT ''a'' COLLATE BINARY = ''A'' COLLATE NOCASE' iv_expected = 0 ).
    assert_integer( iv_sql                                             =
      'SELECT ''a'' COLLATE NOCASE = ''A'' COLLATE BINARY' iv_expected = 1 ).
    assert_integer( iv_sql                                  =
      'SELECT ''abc '' = ''abc'' COLLATE RTRIM' iv_expected = 1 ).
    assert_integer( iv_sql                                    =
      'SELECT ''abc  '' = ''abc '' COLLATE RTRIM' iv_expected = 1 ).
    assert_integer( iv_sql                                 =
      'SELECT ''a'' COLLATE NOCASE IN (''A'')' iv_expected = 1 ).
    assert_integer( iv_sql                                 =
      'SELECT ''a'' IN (''A'' COLLATE NOCASE)' iv_expected = 0 ).
    assert_integer( iv_sql                                              =
      'SELECT ''a'' BETWEEN ''A'' AND ''B'' COLLATE NOCASE' iv_expected = 1 ).
    assert_integer( iv_sql                                              =
      'SELECT ''a'' BETWEEN ''A'' COLLATE NOCASE AND ''B''' iv_expected = 0 ).
    assert_integer( iv_sql =
      'SELECT CASE ''a'' COLLATE NOCASE WHEN ''A'' THEN 1 ELSE 0 END'
      iv_expected          = 1 ).
    assert_integer( iv_sql =
      'SELECT CASE WHEN 1 THEN ''a'' COLLATE NOCASE ELSE ''b'' END = ''A'''
      iv_expected          = 1 ).
    assert_integer( iv_sql                                            =
      'SELECT CAST(''a'' COLLATE NOCASE AS TEXT) = ''A''' iv_expected = 1 ).
    assert_integer( iv_sql                                        =
      'SELECT ''a'' COLLATE NOCASE || ''x'' = ''AX''' iv_expected = 1 ).
    assert_integer( iv_sql =
      'SELECT ''a'' COLLATE BINARY || (''X'' COLLATE NOCASE) = ''Ax'''
      iv_expected          = 0 ).
    assert_integer( iv_sql                                          =
      'SELECT ''x'' || (''a'' COLLATE NOCASE) = ''XA''' iv_expected = 1 ).
    assert_integer( iv_sql                               =
      'SELECT ''a'' COLLATE NOCASE IS ''A''' iv_expected = 1 ).
  ENDMETHOD.

  METHOD like_patterns.
    assert_integer( iv_sql      = 'SELECT ''a'' LIKE ''A'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''A'' LIKE ''a'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' LIKE ''a%'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' LIKE ''a_c'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' LIKE ''a%c'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' LIKE ''%b%'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''ac'' LIKE ''a%b%c'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT '''' LIKE ''%'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT '''' LIKE ''_'''
                    iv_expected = 0 ).
    assert_integer( iv_sql                                    =
      'SELECT ''a%c'' LIKE ''a!%c'' ESCAPE ''!''' iv_expected = 1 ).
    assert_integer( iv_sql                                    =
      'SELECT ''abc'' LIKE ''a!%c'' ESCAPE ''!''' iv_expected = 0 ).
    assert_integer( iv_sql                                    =
      'SELECT ''a_c'' LIKE ''a!_c'' ESCAPE ''!''' iv_expected = 1 ).
    assert_integer( iv_sql                                    =
      'SELECT ''abc'' LIKE ''a!bc'' ESCAPE ''!''' iv_expected = 1 ).
    assert_integer( iv_sql                                 =
      'SELECT ''a!'' LIKE ''a!'' ESCAPE ''!''' iv_expected = 0 ).
    assert_integer( iv_sql                                    =
      'SELECT ''abc'' LIKE ''abc!'' ESCAPE ''!''' iv_expected = 0 ).
    assert_integer( iv_sql                                   =
      'SELECT ''abc'' LIKE ''a_c'' ESCAPE ''A''' iv_expected = 1 ).
    assert_integer( iv_sql                                   =
      'SELECT ''aBc'' LIKE ''a_c'' ESCAPE ''a''' iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT ''a'' LIKE ''a'' ESCAPE 1'
                    iv_expected = 1 ).
    assert_integer( iv_sql = 'SELECT ''a1'' LIKE ''a1'' ESCAPE 1'
      iv_expected          = 0 ).
    assert_integer( iv_sql = 'SELECT ''a'' LIKE ''a'' ESCAPE ''1'''
      iv_expected          = 1 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' NOT LIKE ''a%'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT 1 LIKE ''1'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT 1.5 LIKE ''1.5'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT x''4142'' LIKE ''AB'''
                    iv_expected = 1 ).
    assert_null( 'SELECT NULL LIKE ''a''' ).
    assert_null( 'SELECT ''a'' LIKE NULL' ).
    assert_null( 'SELECT NULL NOT LIKE ''a''' ).
    assert_null( 'SELECT ''abc'' LIKE ''abc'' ESCAPE NULL' ).
  ENDMETHOD.

  METHOD glob_patterns.
    assert_integer( iv_sql      = 'SELECT ''AB'' GLOB ''A*'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''AB'' GLOB ''a*'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' GLOB ''a?c'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' GLOB ''a[bd]c'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' GLOB ''a[b-d]c'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' GLOB ''a[^bd]c'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' GLOB ''a[!bd]c'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' GLOB ''a[b'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT '']'' GLOB ''[]]'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''-'' GLOB ''[a-]'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''b'' GLOB ''[a-]'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT ''a'' GLOB ''[]a]'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''a'' GLOB ''[^a]'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT ''b'' GLOB ''[^a]'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''^'' GLOB ''[^a]'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''^'' GLOB ''[!a]'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT ''a'' GLOB ''[z-a]'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT ''['' GLOB ''[[]'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' GLOB ''a*b*c'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT ''ac'' GLOB ''a*b*c'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT '''' GLOB ''*'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT '''' GLOB ''?'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT ''abc'' NOT GLOB ''a*'''
                    iv_expected = 0 ).
    assert_integer( iv_sql      = 'SELECT 1 GLOB ''1'''
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT x''4142'' GLOB ''AB'''
                    iv_expected = 1 ).
    assert_null( 'SELECT NULL GLOB ''a''' ).
    assert_null( 'SELECT ''a'' GLOB NULL' ).
  ENDMETHOD.

  METHOD pattern_errors.
    TRY.
        zcl_sqlite_expr_eval=>evaluate_sql( 'SELECT ''abc'' LIKE ''abc'' ESCAPE ''!!''' ).
        cl_abap_unit_assert=>fail( 'expected escape error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_escape_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_escape_error->message
          exp = 'ESCAPE expression must be a single character' ).
    ENDTRY.

    TRY.
        zcl_sqlite_expr_eval=>evaluate_sql( 'SELECT ''a'' COLLATE FOO = ''A''' ).
        cl_abap_unit_assert=>fail( 'expected collation error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_collation_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_collation_error->message
          exp = 'no such collation sequence: FOO' ).
    ENDTRY.

    TRY.
        zcl_sqlite_expr_eval=>evaluate_sql( 'SELECT ''a'' GLOB ''a'' ESCAPE ''!''' ).
        cl_abap_unit_assert=>fail( 'expected glob escape error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_glob_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_glob_error->message
          exp = 'wrong number of arguments to function GLOB()' ).
    ENDTRY.
  ENDMETHOD.

  METHOD hex_error.
    TRY.
        zcl_sqlite_expr_eval=>evaluate_sql( 'SELECT 0x10000000000000000' ).
        cl_abap_unit_assert=>fail( 'expected hex literal error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'hex literal too big: 0x10000000000000000' ).
    ENDTRY.
  ENDMETHOD.

  METHOD scalar_numeric.
    assert_integer( iv_sql      = 'SELECT abs(-3)'
                    iv_expected = 3 ).
    assert_real( iv_sql      = 'SELECT abs(-3.5)'
                 iv_expected = '3.5' ).
    assert_real( iv_sql      = 'SELECT abs(''-4x'')'
                 iv_expected = '4.0' ).
    assert_null( 'SELECT abs(NULL)' ).
    assert_real( iv_sql      = 'SELECT round(2.5)'
                 iv_expected = '3.0' ).
    assert_real( iv_sql      = 'SELECT round(-2.5)'
                 iv_expected = '-3.0' ).
    assert_real( iv_sql      = 'SELECT round(123.456, 2)'
                 iv_expected = '123.46' ).
    assert_real( iv_sql      = 'SELECT round(123.456, -1)'
                 iv_expected = '123.0' ).
    assert_null( 'SELECT round(NULL, 2)' ).
    assert_integer( iv_sql      = 'SELECT min(3, 1, 2)'
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT max(3, 1, 2)'
                    iv_expected = 3 ).
    assert_integer( iv_sql      = 'SELECT min(''2'', 10)'
                    iv_expected = 10 ).
    assert_text( iv_sql      = 'SELECT max(''2'', 10)'
                 iv_expected = '2' ).
    assert_real( iv_sql      = 'SELECT min(1, 1.0)'
                 iv_expected = '1.0' ).
    assert_integer( iv_sql      = 'SELECT max(1, 1.0)'
                    iv_expected = 1 ).
    assert_null( 'SELECT min(NULL, 1)' ).
  ENDMETHOD.

  METHOD scalar_text.
    assert_integer( iv_sql      = 'SELECT length(''abc'')'
                    iv_expected = 3 ).
    assert_integer( iv_sql      = 'SELECT length(1.0)'
                    iv_expected = 3 ).
    assert_integer( iv_sql      = 'SELECT length(x''000102'')'
                    iv_expected = 3 ).
    assert_text( iv_sql      = 'SELECT lower(''AbC'')'
                 iv_expected = 'abc' ).
    assert_text( iv_sql      = 'SELECT upper(''AbC'')'
                 iv_expected = 'ABC' ).
    assert_text( iv_sql      = 'SELECT substr(''abcdef'', 2, 3)'
                 iv_expected = 'bcd' ).
    assert_text( iv_sql      = 'SELECT substr(''abcdef'', -2)'
                 iv_expected = 'ef' ).
    assert_text( iv_sql      = 'SELECT substr(''abcdef'', 0, 2)'
                 iv_expected = 'a' ).
    assert_text( iv_sql      = 'SELECT substr(''abcdef'', 2, -1)'
                 iv_expected = 'a' ).
    assert_text( iv_sql      = 'SELECT trim(''  abc  '')'
                 iv_expected = 'abc' ).
    assert_text( iv_sql      = 'SELECT ltrim(''xxabc'', ''x'')'
                 iv_expected = 'abc' ).
    assert_text( iv_sql      = 'SELECT rtrim(''abcxx'', ''x'')'
                 iv_expected = 'abc' ).
    assert_text( iv_sql      = 'SELECT trim(''xxabcxx'', ''x'')'
                 iv_expected = 'abc' ).
    assert_text( iv_sql      = 'SELECT replace(''abcabc'', ''ab'', ''X'')'
                 iv_expected = 'XcXc' ).
    assert_text( iv_sql      = 'SELECT replace(''abc'', '''', ''X'')'
                 iv_expected = 'abc' ).
    assert_integer( iv_sql      = 'SELECT instr(''abcdef'', ''cd'')'
                    iv_expected = 3 ).
    assert_integer( iv_sql      = 'SELECT instr(''abc'', '''')'
                    iv_expected = 1 ).
    assert_integer( iv_sql      = 'SELECT instr(12345, 34)'
                    iv_expected = 3 ).
    assert_text( iv_sql      = 'SELECT hex(''abc'')'
                 iv_expected = '616263' ).
    assert_text( iv_sql      = 'SELECT hex(NULL)'
                 iv_expected = '' ).
    assert_text( iv_sql      = 'SELECT quote(NULL)'
                 iv_expected = 'NULL' ).
    assert_text( iv_sql      = 'SELECT quote(123)'
                 iv_expected = '123' ).
    assert_text( iv_sql      = 'SELECT typeof(NULL)'
                 iv_expected = 'null' ).
    assert_text( iv_sql      = 'SELECT typeof(1.5)'
                 iv_expected = 'real' ).
  ENDMETHOD.

  METHOD scalar_conditional.
    assert_integer( iv_sql      = 'SELECT coalesce(NULL, NULL, 3)'
                    iv_expected = 3 ).
    assert_text( iv_sql      = 'SELECT coalesce(NULL, ''x'')'
                 iv_expected = 'x' ).
    assert_integer( iv_sql      = 'SELECT ifnull(NULL, 2)'
                    iv_expected = 2 ).
    assert_integer( iv_sql      = 'SELECT ifnull(1, 2)'
                    iv_expected = 1 ).
    assert_null( 'SELECT nullif(1, 1)' ).
    assert_integer( iv_sql      = 'SELECT nullif(1, 2)'
                    iv_expected = 1 ).
    assert_text( iv_sql      = 'SELECT iif(1, ''yes'', ''no'')'
                 iv_expected = 'yes' ).
    assert_text( iv_sql      = 'SELECT iif(0, ''yes'', ''no'')'
                 iv_expected = 'no' ).
    assert_null( 'SELECT iif(0, ''yes'')' ).
  ENDMETHOD.

  METHOD scalar_blobs.
    assert_blob( iv_sql      = 'SELECT substr(x''00010203'', 2, 2)'
                 iv_expected = '0102' ).
    assert_blob( iv_sql      = 'SELECT substr(x''00010203'', -2)'
                 iv_expected = '0203' ).
    assert_text( iv_sql      = 'SELECT lower(x''4142'')'
                 iv_expected = 'ab' ).
    assert_text( iv_sql      = 'SELECT trim(x''20612020'')'
                 iv_expected = 'a' ).
    assert_text( iv_sql      = 'SELECT replace(x''616263'', x''62'', x''58'')'
                 iv_expected = 'aXc' ).
    assert_integer( iv_sql      = 'SELECT instr(x''00010203'', x''0102'')'
                    iv_expected = 2 ).
    assert_integer( iv_sql      = 'SELECT instr(x''00010203'', x'''')'
                    iv_expected = 1 ).
    assert_text( iv_sql      = 'SELECT hex(x''00AB'')'
                 iv_expected = '00AB' ).
    assert_text( iv_sql      = 'SELECT quote(x''00AB'')'
                 iv_expected = |X'00AB'| ).
  ENDMETHOD.

  METHOD function_errors.
    TRY.
        zcl_sqlite_expr_eval=>evaluate_sql( 'SELECT abs()' ).
        cl_abap_unit_assert=>fail( 'expected arity error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'wrong number of arguments to function abs()' ).
    ENDTRY.

    TRY.
        zcl_sqlite_expr_eval=>evaluate_sql( 'SELECT abs(-9223372036854775808)' ).
        cl_abap_unit_assert=>fail( 'expected overflow error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_overflow).
        cl_abap_unit_assert=>assert_equals(
          act = lo_overflow->message
          exp = 'integer overflow' ).
    ENDTRY.

    TRY.
        zcl_sqlite_expr_eval=>evaluate_sql( 'SELECT replace()' ).
        cl_abap_unit_assert=>fail( 'expected replace arity error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_replace).
        cl_abap_unit_assert=>assert_equals(
          act = lo_replace->message
          exp = 'wrong number of arguments to function replace()' ).
    ENDTRY.
  ENDMETHOD.

  METHOD random_function.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_expr_eval=>evaluate_sql( 'SELECT random()' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->value_type( )
      exp = zcl_sqlite_value=>c_integer
      msg = 'random() returns an integer' ).
    assert_text( iv_sql      = 'SELECT typeof(random())'
                 iv_expected = 'integer' ).
  ENDMETHOD.

  METHOD assert_integer.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_expr_eval=>evaluate_sql( iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->value_type( )
      exp = zcl_sqlite_value=>c_integer
      msg = iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = iv_expected
      msg = iv_sql ).
  ENDMETHOD.

  METHOD assert_real.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_expr_eval=>evaluate_sql( iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->value_type( )
      exp = zcl_sqlite_value=>c_real
      msg = iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = iv_expected
      msg = iv_sql ).
  ENDMETHOD.

  METHOD assert_text.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_expr_eval=>evaluate_sql( iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->value_type( )
      exp = zcl_sqlite_value=>c_text
      msg = iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = iv_expected
      msg = iv_sql ).
  ENDMETHOD.

  METHOD assert_null.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_expr_eval=>evaluate_sql( iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->value_type( )
      exp = zcl_sqlite_value=>c_null
      msg = iv_sql ).
  ENDMETHOD.

  METHOD assert_blob.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_expr_eval=>evaluate_sql( iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->value_type( )
      exp = zcl_sqlite_value=>c_blob
      msg = iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_blob( )
      exp = iv_expected
      msg = iv_sql ).
  ENDMETHOD.

ENDCLASS.
