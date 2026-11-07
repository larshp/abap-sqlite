CLASS ltcl_tokenizer DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_token TYPE zcl_sqlite_tokenizer=>ty_token.
    TYPES ty_tokens TYPE zcl_sqlite_tokenizer=>ty_tokens.

    METHODS empty_input FOR TESTING.
    METHODS keywords_identifiers FOR TESTING.
    METHODS quoted_identifiers FOR TESTING.
    METHODS strings_and_blobs FOR TESTING.
    METHODS numbers FOR TESTING.
    METHODS parameters FOR TESTING.
    METHODS operators FOR TESTING.
    METHODS comments FOR TESTING.
    METHODS positions FOR TESTING.
    METHODS illegal_tokens FOR TESTING.

    METHODS assert_tokens
      IMPORTING iv_sql      TYPE string
                it_expected TYPE ty_tokens.
    METHODS assert_token
      IMPORTING is_actual   TYPE ty_token
                is_expected TYPE ty_token.
ENDCLASS.


CLASS ltcl_tokenizer IMPLEMENTATION.

  METHOD empty_input.
    assert_tokens(
      iv_sql = ''
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).
  ENDMETHOD.

  METHOD keywords_identifiers.
    assert_tokens(
      iv_sql = |SELECT foo, CURRENT_TIMESTAMP, true FROM _tbl$1|
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_keyword
          text = 'SELECT' value = 'SELECT' )
        ( kind = zcl_sqlite_tokenizer=>c_identifier
          text = 'foo' value = 'foo' )
        ( kind = zcl_sqlite_tokenizer=>c_comma text = ',' value = ',' )
        ( kind = zcl_sqlite_tokenizer=>c_keyword
          text = 'CURRENT_TIMESTAMP' value = 'CURRENT_TIMESTAMP' )
        ( kind = zcl_sqlite_tokenizer=>c_comma text = ',' value = ',' )
        ( kind = zcl_sqlite_tokenizer=>c_identifier
          text = 'true' value = 'true' )
        ( kind = zcl_sqlite_tokenizer=>c_keyword
          text = 'FROM' value = 'FROM' )
        ( kind = zcl_sqlite_tokenizer=>c_identifier
          text = '_tbl$1' value = '_tbl$1' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = 'select SeLeCt "select"'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_keyword
          text = 'select' value = 'SELECT' )
        ( kind = zcl_sqlite_tokenizer=>c_keyword
          text = 'SeLeCt' value = 'SELECT' )
        ( kind = zcl_sqlite_tokenizer=>c_identifier
          text = '"select"' value = 'select' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).
  ENDMETHOD.

  METHOD quoted_identifiers.
    assert_tokens(
      iv_sql = |"a""b" [c d] `e``f` "select"|
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_identifier
          text = '"a""b"' value = 'a"b' )
        ( kind = zcl_sqlite_tokenizer=>c_identifier
          text = '[c d]' value = 'c d' )
        ( kind = zcl_sqlite_tokenizer=>c_identifier
          text = '`e``f`' value = 'e`f' )
        ( kind = zcl_sqlite_tokenizer=>c_identifier
          text = '"select"' value = 'select' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).
  ENDMETHOD.

  METHOD strings_and_blobs.
    assert_tokens(
      iv_sql = |'it''s' '' X'1f' x''|
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_string
          text = |'it''s'| value = |it's| )
        ( kind = zcl_sqlite_tokenizer=>c_string
          text = |''| value = '' )
        ( kind = zcl_sqlite_tokenizer=>c_blob
          text = |X'1f'| value = '1F' )
        ( kind = zcl_sqlite_tokenizer=>c_blob
          text = |x''| value = '' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).
  ENDMETHOD.

  METHOD numbers.
    assert_tokens(
      iv_sql = '0 123 0x1F 1.5 .5 1. 1e5 1E+5 1.2e-3 5.e2'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_integer
          text = '0' value = '0' )
        ( kind = zcl_sqlite_tokenizer=>c_integer
          text = '123' value = '123' )
        ( kind = zcl_sqlite_tokenizer=>c_integer
          text = '0x1F' value = '0x1F' )
        ( kind = zcl_sqlite_tokenizer=>c_float
          text = '1.5' value = '1.5' )
        ( kind = zcl_sqlite_tokenizer=>c_float
          text = '.5' value = '.5' )
        ( kind = zcl_sqlite_tokenizer=>c_float
          text = '1.' value = '1.' )
        ( kind = zcl_sqlite_tokenizer=>c_float
          text = '1e5' value = '1e5' )
        ( kind = zcl_sqlite_tokenizer=>c_float
          text = '1E+5' value = '1E+5' )
        ( kind = zcl_sqlite_tokenizer=>c_float
          text = '1.2e-3' value = '1.2e-3' )
        ( kind = zcl_sqlite_tokenizer=>c_float
          text = '5.e2' value = '5.e2' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).
  ENDMETHOD.

  METHOD parameters.
    assert_tokens(
      iv_sql = '? ?123 :name @name $name $a::b $a(x) :1'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_parameter
          text = '?' value = '' )
        ( kind = zcl_sqlite_tokenizer=>c_parameter
          text = '?123' value = '123' )
        ( kind = zcl_sqlite_tokenizer=>c_parameter
          text = ':name' value = 'name' )
        ( kind = zcl_sqlite_tokenizer=>c_parameter
          text = '@name' value = 'name' )
        ( kind = zcl_sqlite_tokenizer=>c_parameter
          text = '$name' value = 'name' )
        ( kind = zcl_sqlite_tokenizer=>c_parameter
          text = '$a::b' value = 'a::b' )
        ( kind = zcl_sqlite_tokenizer=>c_parameter
          text = '$a(x)' value = 'a(x)' )
        ( kind = zcl_sqlite_tokenizer=>c_parameter
          text = ':1' value = '1' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = '?abc'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_parameter
          text = '?' value = '' )
        ( kind = zcl_sqlite_tokenizer=>c_identifier
          text = 'abc' value = 'abc' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).
  ENDMETHOD.

  METHOD operators.
    assert_tokens(
      iv_sql = '; ( ) , . = == != <> <= >= < > + - * / % || & | << >> ~ -> ->>'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_semicolon text = ';' value = ';' )
        ( kind = zcl_sqlite_tokenizer=>c_lparen text = '(' value = '(' )
        ( kind = zcl_sqlite_tokenizer=>c_rparen text = ')' value = ')' )
        ( kind = zcl_sqlite_tokenizer=>c_comma text = ',' value = ',' )
        ( kind = zcl_sqlite_tokenizer=>c_dot text = '.' value = '.' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '=' value = '=' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '==' value = '==' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '!=' value = '!=' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '<>' value = '<>' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '<=' value = '<=' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '>=' value = '>=' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '<' value = '<' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '>' value = '>' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '+' value = '+' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '-' value = '-' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '*' value = '*' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '/' value = '/' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '%' value = '%' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '||' value = '||' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '&' value = '&' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '|' value = '|' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '<<' value = '<<' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '>>' value = '>>' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '~' value = '~' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '->' value = '->' )
        ( kind = zcl_sqlite_tokenizer=>c_operator text = '->>' value = '->>' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).
  ENDMETHOD.

  METHOD comments.
    DATA lv_sql TYPE string.

    lv_sql = |SELECT 1 -- one| && cl_abap_char_utilities=>newline
      && |/* two */ 2 /* unterminated|.
    assert_tokens(
      iv_sql = lv_sql
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_keyword
          text = 'SELECT' value = 'SELECT' )
        ( kind = zcl_sqlite_tokenizer=>c_integer text = '1' value = '1' )
        ( kind = zcl_sqlite_tokenizer=>c_comment
          text = '-- one' value = '-- one' )
        ( kind = zcl_sqlite_tokenizer=>c_comment
          text = '/* two */' value = '/* two */' )
        ( kind = zcl_sqlite_tokenizer=>c_integer text = '2' value = '2' )
        ( kind = zcl_sqlite_tokenizer=>c_comment
          text = '/* unterminated' value = '/* unterminated' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = '-- tail'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_comment
          text = '-- tail' value = '-- tail' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).
  ENDMETHOD.

  METHOD positions.
    DATA lt_tokens TYPE ty_tokens.
    DATA ls_token TYPE ty_token.

    lt_tokens = zcl_sqlite_tokenizer=>tokenize( |SELECT| && cl_abap_char_utilities=>newline && |  x| ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_tokens ) exp = 3 msg = 'token count' ).

    READ TABLE lt_tokens INTO ls_token INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-offset exp = 1 msg = 'SELECT offset' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-length exp = 6 msg = 'SELECT length' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-line exp = 1 msg = 'SELECT line' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-column exp = 1 msg = 'SELECT column' ).

    READ TABLE lt_tokens INTO ls_token INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-offset exp = 10 msg = 'x offset' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-length exp = 1 msg = 'x length' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-line exp = 2 msg = 'x line' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-column exp = 3 msg = 'x column' ).

    READ TABLE lt_tokens INTO ls_token INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-offset exp = 11 msg = 'EOF offset' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-length exp = 0 msg = 'EOF length' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-line exp = 2 msg = 'EOF line' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_token-column exp = 4 msg = 'EOF column' ).
  ENDMETHOD.

  METHOD illegal_tokens.
    assert_tokens(
      iv_sql = '123abc'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_illegal
          text = '123abc' value = '123abc' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = '1e'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_illegal text = '1e' value = '1e' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = '0x'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_illegal text = '0x' value = '0x' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = |X'1'|
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_illegal
          text = |X'1'| value = |X'1'| )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = |'abc|
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_illegal
          text = |'abc| value = |'abc| )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = |"abc|
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_illegal
          text = |"abc| value = |"abc| )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = 'x'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_identifier text = 'x' value = 'x' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = '!'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_illegal text = '!' value = '!' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = ':'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_illegal text = ':' value = ':' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = '@'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_illegal text = '@' value = '@' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = '$'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_illegal text = '$' value = '$' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).

    assert_tokens(
      iv_sql = '[a]]'
      it_expected = VALUE ty_tokens(
        ( kind = zcl_sqlite_tokenizer=>c_identifier text = '[a]' value = 'a' )
        ( kind = zcl_sqlite_tokenizer=>c_illegal text = ']' value = ']' )
        ( kind = zcl_sqlite_tokenizer=>c_eof text = '' value = '' ) ) ).
  ENDMETHOD.

  METHOD assert_tokens.
    DATA lt_actual TYPE ty_tokens.
    DATA ls_actual TYPE ty_token.
    DATA ls_expected TYPE ty_token.

    lt_actual = zcl_sqlite_tokenizer=>tokenize( iv_sql ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_actual )
      exp = lines( it_expected )
      msg = |unexpected token count for { iv_sql }| ).

    LOOP AT it_expected INTO ls_expected.
      READ TABLE lt_actual INTO ls_actual INDEX sy-tabix.
      assert_token( is_actual = ls_actual is_expected = ls_expected ).
    ENDLOOP.
  ENDMETHOD.

  METHOD assert_token.
    cl_abap_unit_assert=>assert_equals(
      act = is_actual-kind
      exp = is_expected-kind
      msg = |kind for { is_expected-text }| ).
    cl_abap_unit_assert=>assert_equals(
      act = is_actual-text
      exp = is_expected-text
      msg = |text for { is_expected-text }| ).
    cl_abap_unit_assert=>assert_equals(
      act = is_actual-value
      exp = is_expected-value
      msg = |value for { is_expected-text }| ).
  ENDMETHOD.

ENDCLASS.
