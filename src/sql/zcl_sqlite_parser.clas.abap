* SQLite expression parser. This is a hand-written Pratt parser following
* the operator precedence documented at
* https://www.sqlite.org/lang_expr.html.
CLASS zcl_sqlite_parser DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS parse_expression
      IMPORTING iv_sql               TYPE string
      RETURNING VALUE(ro_expression) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    CLASS-METHODS dump_expression
      IMPORTING iv_sql         TYPE string
      RETURNING VALUE(rv_text) TYPE string
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    CONSTANTS:
      c_prec_or         TYPE i VALUE 1,
      c_prec_and        TYPE i VALUE 2,
      c_prec_not        TYPE i VALUE 3,
      c_prec_equality   TYPE i VALUE 4,
      c_prec_relational TYPE i VALUE 5,
      c_prec_bitwise    TYPE i VALUE 6,
      c_prec_additive   TYPE i VALUE 7,
      c_prec_multiply   TYPE i VALUE 8,
      c_prec_concat     TYPE i VALUE 9,
      c_prec_collate    TYPE i VALUE 10,
      c_prec_unary      TYPE i VALUE 11.

    DATA mt_tokens TYPE zcl_sqlite_tokenizer=>ty_tokens.
    DATA mv_index TYPE i.

    METHODS constructor
      IMPORTING iv_sql TYPE string.

    METHODS parse_expression_internal
      IMPORTING iv_min_precedence TYPE i
      RETURNING VALUE(ro_node)    TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_prefix
      RETURNING VALUE(ro_node) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_primary
      RETURNING VALUE(ro_node) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_parenthesized
      RETURNING VALUE(ro_node) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_name_or_function
      RETURNING VALUE(ro_node) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_function
      IMPORTING iv_name        TYPE string
      RETURNING VALUE(ro_node) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_case
      RETURNING VALUE(ro_node) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_cast
      RETURNING VALUE(ro_node) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_type_name
      RETURNING VALUE(rv_type) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS parse_in
      IMPORTING io_expression  TYPE REF TO zcl_sqlite_ast_node
                iv_negated     TYPE abap_bool
      RETURNING VALUE(ro_node) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_between
      IMPORTING io_expression  TYPE REF TO zcl_sqlite_ast_node
                iv_negated     TYPE abap_bool
      RETURNING VALUE(ro_node) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_like
      IMPORTING io_expression  TYPE REF TO zcl_sqlite_ast_node
                iv_operator    TYPE string
                iv_negated     TYPE abap_bool
      RETURNING VALUE(ro_node) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_collate
      IMPORTING io_expression  TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(ro_node) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_postfix
      IMPORTING io_expression     TYPE REF TO zcl_sqlite_ast_node
                iv_min_precedence TYPE i
      RETURNING VALUE(ro_node)    TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_comparison
      IMPORTING io_expression     TYPE REF TO zcl_sqlite_ast_node
                iv_min_precedence TYPE i
      RETURNING VALUE(ro_node)    TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_binary
      IMPORTING io_expression     TYPE REF TO zcl_sqlite_ast_node
                iv_min_precedence TYPE i
      RETURNING VALUE(ro_node)    TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS current
      RETURNING VALUE(rs_token) TYPE zcl_sqlite_tokenizer=>ty_token.

    METHODS token_at
      IMPORTING iv_ahead        TYPE i
      RETURNING VALUE(rs_token) TYPE zcl_sqlite_tokenizer=>ty_token.

    METHODS advance.

    METHODS is_keyword
      IMPORTING iv_keyword       TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS is_keyword_at
      IMPORTING iv_ahead         TYPE i
                iv_keyword       TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS is_operator
      IMPORTING iv_operator      TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS is_kind
      IMPORTING iv_kind          TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS expect_keyword
      IMPORTING iv_keyword TYPE string
      RAISING   zcx_sqlite_error.

    METHODS expect_operator
      IMPORTING iv_operator TYPE string
      RAISING   zcx_sqlite_error.

    METHODS expect_kind
      IMPORTING iv_kind     TYPE string
                iv_expected TYPE string
      RAISING   zcx_sqlite_error.

    METHODS binary_precedence
      IMPORTING iv_operator          TYPE string
      RETURNING VALUE(rv_precedence) TYPE i.

    METHODS fail
      IMPORTING iv_message TYPE string
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_parser IMPLEMENTATION.

  METHOD constructor.
    DATA lt_tokens TYPE zcl_sqlite_tokenizer=>ty_tokens.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    lt_tokens = zcl_sqlite_tokenizer=>tokenize( iv_sql ).
    LOOP AT lt_tokens INTO ls_token.
      IF ls_token-kind = zcl_sqlite_tokenizer=>c_comment.
        CONTINUE.
      ENDIF.
      APPEND ls_token TO mt_tokens.
    ENDLOOP.
    mv_index = 1.
  ENDMETHOD.

  METHOD parse_expression.
    DATA lo_parser TYPE REF TO zcl_sqlite_parser.

    lo_parser = NEW #( iv_sql ).
    ro_expression = lo_parser->parse_expression_internal( 0 ).
    IF lo_parser->is_kind( zcl_sqlite_tokenizer=>c_eof ) = abap_false.
      lo_parser->fail( 'syntax error' ).
    ENDIF.
  ENDMETHOD.

  METHOD dump_expression.
    rv_text = parse_expression( iv_sql )->dump( ).
  ENDMETHOD.

  METHOD parse_expression_internal.
    DATA lo_left TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_replacement TYPE REF TO zcl_sqlite_ast_node.

    lo_left = parse_prefix( ).

    WHILE current( )-kind <> zcl_sqlite_tokenizer=>c_eof.
      lo_replacement = parse_postfix(
        io_expression    = lo_left
        iv_min_precedence = iv_min_precedence ).
      IF lo_replacement IS BOUND.
        lo_left = lo_replacement.
        CONTINUE.
      ENDIF.

      lo_replacement = parse_comparison(
        io_expression    = lo_left
        iv_min_precedence = iv_min_precedence ).
      IF lo_replacement IS BOUND.
        lo_left = lo_replacement.
        CONTINUE.
      ENDIF.

      lo_replacement = parse_binary(
        io_expression    = lo_left
        iv_min_precedence = iv_min_precedence ).
      IF lo_replacement IS BOUND.
        lo_left = lo_replacement.
        CONTINUE.
      ENDIF.

      EXIT.
    ENDWHILE.

    ro_node = lo_left.
  ENDMETHOD.

  METHOD parse_postfix.
    IF is_keyword( 'COLLATE' ) = abap_true.
      IF c_prec_collate < iv_min_precedence.
        RETURN.
      ENDIF.
      advance( ).
      ro_node = parse_collate( io_expression ).
    ELSEIF is_keyword( 'ISNULL' ) = abap_true.
      IF c_prec_equality < iv_min_precedence.
        RETURN.
      ENDIF.
      advance( ).
      ro_node = NEW zcl_sqlite_ast_unary(
        iv_operator = 'ISNULL'
        io_operand  = io_expression ).
    ELSEIF is_keyword( 'NOTNULL' ) = abap_true.
      IF c_prec_equality < iv_min_precedence.
        RETURN.
      ENDIF.
      advance( ).
      ro_node = NEW zcl_sqlite_ast_unary(
        iv_operator = 'NOTNULL'
        io_operand  = io_expression ).
    ELSEIF is_keyword( 'NOT' ) = abap_true
        AND is_keyword_at( iv_ahead = 1 iv_keyword = 'NULL' ) = abap_true.
      IF c_prec_equality < iv_min_precedence.
        RETURN.
      ENDIF.
      advance( ).
      advance( ).
      ro_node = NEW zcl_sqlite_ast_unary(
        iv_operator = 'NOTNULL'
        io_operand  = io_expression ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_comparison.
    DATA lv_operator TYPE string.
    DATA lo_right TYPE REF TO zcl_sqlite_ast_node.

    IF is_keyword( 'NOT' ) = abap_true
        AND ( is_keyword_at( iv_ahead = 1 iv_keyword = 'IN' ) = abap_true
           OR is_keyword_at( iv_ahead = 1 iv_keyword = 'BETWEEN' ) = abap_true
           OR is_keyword_at( iv_ahead = 1 iv_keyword = 'LIKE' ) = abap_true
           OR is_keyword_at( iv_ahead = 1 iv_keyword = 'GLOB' ) = abap_true ).
      IF c_prec_equality < iv_min_precedence.
        RETURN.
      ENDIF.
      advance( ).
      lv_operator = current( )-value.
      advance( ).
      CASE lv_operator.
        WHEN 'IN'.
          ro_node = parse_in( io_expression = io_expression iv_negated = abap_true ).
        WHEN 'BETWEEN'.
          ro_node = parse_between( io_expression = io_expression iv_negated = abap_true ).
        WHEN 'LIKE' OR 'GLOB'.
          ro_node = parse_like(
            io_expression = io_expression
            iv_operator   = lv_operator
            iv_negated    = abap_true ).
      ENDCASE.
      RETURN.
    ENDIF.

    IF is_keyword( 'IN' ) = abap_true.
      IF c_prec_equality < iv_min_precedence.
        RETURN.
      ENDIF.
      advance( ).
      ro_node = parse_in( io_expression = io_expression iv_negated = abap_false ).
      RETURN.
    ENDIF.

    IF is_keyword( 'BETWEEN' ) = abap_true.
      IF c_prec_equality < iv_min_precedence.
        RETURN.
      ENDIF.
      advance( ).
      ro_node = parse_between( io_expression = io_expression iv_negated = abap_false ).
      RETURN.
    ENDIF.

    IF is_keyword( 'LIKE' ) = abap_true OR is_keyword( 'GLOB' ) = abap_true.
      IF c_prec_equality < iv_min_precedence.
        RETURN.
      ENDIF.
      lv_operator = current( )-value.
      advance( ).
      ro_node = parse_like(
        io_expression = io_expression
        iv_operator   = lv_operator
        iv_negated    = abap_false ).
      RETURN.
    ENDIF.

    IF is_keyword( 'IS' ) = abap_true.
      IF c_prec_equality < iv_min_precedence.
        RETURN.
      ENDIF.
      advance( ).
      IF is_keyword( 'NOT' ) = abap_true.
        advance( ).
        lv_operator = 'IS NOT'.
      ELSE.
        lv_operator = 'IS'.
      ENDIF.
      lo_right = parse_expression_internal( c_prec_equality + 1 ).
      ro_node = NEW zcl_sqlite_ast_binary(
        iv_operator = lv_operator
        io_left     = io_expression
        io_right    = lo_right ).
      RETURN.
    ENDIF.

    IF is_keyword( 'MATCH' ) = abap_true OR is_keyword( 'REGEXP' ) = abap_true.
      IF c_prec_equality < iv_min_precedence.
        RETURN.
      ENDIF.
      lv_operator = current( )-value.
      advance( ).
      lo_right = parse_expression_internal( c_prec_equality + 1 ).
      ro_node = NEW zcl_sqlite_ast_binary(
        iv_operator = lv_operator
        io_left     = io_expression
        io_right    = lo_right ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_binary.
    DATA lv_operator TYPE string.
    DATA lv_precedence TYPE i.
    DATA lo_right TYPE REF TO zcl_sqlite_ast_node.

    IF is_keyword( 'OR' ) = abap_true.
      IF c_prec_or < iv_min_precedence.
        RETURN.
      ENDIF.
      advance( ).
      lo_right = parse_expression_internal( c_prec_or + 1 ).
      ro_node = NEW zcl_sqlite_ast_binary(
        iv_operator = 'OR'
        io_left     = io_expression
        io_right    = lo_right ).
      RETURN.
    ENDIF.

    IF is_keyword( 'AND' ) = abap_true.
      IF c_prec_and < iv_min_precedence.
        RETURN.
      ENDIF.
      advance( ).
      lo_right = parse_expression_internal( c_prec_and + 1 ).
      ro_node = NEW zcl_sqlite_ast_binary(
        iv_operator = 'AND'
        io_left     = io_expression
        io_right    = lo_right ).
      RETURN.
    ENDIF.

    IF current( )-kind <> zcl_sqlite_tokenizer=>c_operator.
      RETURN.
    ENDIF.

    lv_operator = current( )-text.
    lv_precedence = binary_precedence( lv_operator ).
    IF lv_precedence = 0 OR lv_precedence < iv_min_precedence.
      RETURN.
    ENDIF.

    advance( ).
    lo_right = parse_expression_internal( lv_precedence + 1 ).
    ro_node = NEW zcl_sqlite_ast_binary(
      iv_operator = lv_operator
      io_left     = io_expression
      io_right    = lo_right ).
  ENDMETHOD.


  METHOD parse_prefix.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.
    DATA lv_operator TYPE string.
    DATA lo_operand TYPE REF TO zcl_sqlite_ast_node.

    ls_token = current( ).
    IF ls_token-kind = zcl_sqlite_tokenizer=>c_operator
        AND ( ls_token-text = '-' OR ls_token-text = '+'
           OR ls_token-text = '~' ).
      lv_operator = ls_token-text.
      advance( ).
      lo_operand = parse_expression_internal( c_prec_unary ).
      ro_node = NEW zcl_sqlite_ast_unary(
        iv_operator = lv_operator
        io_operand  = lo_operand ).
    ELSEIF ls_token-kind = zcl_sqlite_tokenizer=>c_keyword
        AND ls_token-value = 'NOT'.
      advance( ).
      lo_operand = parse_expression_internal( c_prec_not ).
      ro_node = NEW zcl_sqlite_ast_unary(
        iv_operator = 'NOT'
        io_operand  = lo_operand ).
    ELSEIF ls_token-kind = zcl_sqlite_tokenizer=>c_keyword
        AND ls_token-value = 'CASE'.
      ro_node = parse_case( ).
    ELSEIF ls_token-kind = zcl_sqlite_tokenizer=>c_keyword
        AND ls_token-value = 'CAST'.
      ro_node = parse_cast( ).
    ELSE.
      ro_node = parse_primary( ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_primary.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    ls_token = current( ).
    CASE ls_token-kind.
      WHEN zcl_sqlite_tokenizer=>c_integer.
        advance( ).
        ro_node = NEW zcl_sqlite_ast_literal(
          iv_kind  = 'INTEGER'
          iv_value = ls_token-value ).
      WHEN zcl_sqlite_tokenizer=>c_float.
        advance( ).
        ro_node = NEW zcl_sqlite_ast_literal(
          iv_kind  = 'REAL'
          iv_value = ls_token-value ).
      WHEN zcl_sqlite_tokenizer=>c_string.
        advance( ).
        ro_node = NEW zcl_sqlite_ast_literal(
          iv_kind  = 'STRING'
          iv_value = ls_token-value ).
      WHEN zcl_sqlite_tokenizer=>c_blob.
        advance( ).
        ro_node = NEW zcl_sqlite_ast_literal(
          iv_kind  = 'BLOB'
          iv_value = ls_token-value ).
      WHEN zcl_sqlite_tokenizer=>c_parameter.
        advance( ).
        ro_node = NEW zcl_sqlite_ast_name(
          iv_kind = zcl_sqlite_ast_name=>c_parameter
          iv_text = ls_token-text ).
      WHEN zcl_sqlite_tokenizer=>c_identifier.
        ro_node = parse_name_or_function( ).
      WHEN zcl_sqlite_tokenizer=>c_lparen.
        ro_node = parse_parenthesized( ).
      WHEN zcl_sqlite_tokenizer=>c_operator.
        IF ls_token-text = '*'.
          advance( ).
          ro_node = NEW zcl_sqlite_ast_name(
            iv_kind = zcl_sqlite_ast_name=>c_star
            iv_text = '*' ).
        ELSE.
          fail( 'syntax error' ).
        ENDIF.
      WHEN zcl_sqlite_tokenizer=>c_keyword.
        CASE ls_token-value.
          WHEN 'NULL'.
            advance( ).
            ro_node = NEW zcl_sqlite_ast_literal(
              iv_kind  = 'NULL'
              iv_value = '' ).
          WHEN 'CURRENT_DATE' OR 'CURRENT_TIME' OR 'CURRENT_TIMESTAMP'.
            advance( ).
            ro_node = NEW zcl_sqlite_ast_literal(
              iv_kind  = ls_token-value
              iv_value = '' ).
          WHEN OTHERS.
            fail( 'syntax error' ).
        ENDCASE.
      WHEN OTHERS.
        fail( 'syntax error' ).
    ENDCASE.
  ENDMETHOD.

  METHOD parse_parenthesized.
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
    ro_node = parse_expression_internal( 0 ).
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
  ENDMETHOD.

  METHOD parse_name_or_function.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.
    DATA lv_name TYPE string.
    DATA lv_text TYPE string.

    ls_token = current( ).
    lv_name = ls_token-value.
    advance( ).

    IF current( )-kind = zcl_sqlite_tokenizer=>c_lparen.
      ro_node = parse_function( lv_name ).
      RETURN.
    ENDIF.

    lv_text = lv_name.
    WHILE current( )-kind = zcl_sqlite_tokenizer=>c_dot.
      advance( ).
      IF current( )-kind = zcl_sqlite_tokenizer=>c_identifier.
        lv_text = lv_text && '.' && current( )-value.
        advance( ).
      ELSEIF current( )-kind = zcl_sqlite_tokenizer=>c_operator
          AND current( )-text = '*'.
        lv_text = lv_text && '.*'.
        advance( ).
        EXIT.
      ELSE.
        fail( 'expected identifier after dot' ).
      ENDIF.
    ENDWHILE.

    ro_node = NEW zcl_sqlite_ast_name(
      iv_kind = zcl_sqlite_ast_name=>c_column
      iv_text = lv_text ).
  ENDMETHOD.

  METHOD parse_function.
    DATA lv_distinct TYPE abap_bool.
    DATA lv_star TYPE abap_bool.
    DATA lt_arguments TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA lo_argument TYPE REF TO zcl_sqlite_ast_node.

    advance( ).

    IF is_keyword( 'DISTINCT' ) = abap_true.
      lv_distinct = abap_true.
      advance( ).
    ENDIF.

    IF is_operator( '*' ) = abap_true.
      lv_star = abap_true.
      advance( ).
    ELSEIF current( )-kind <> zcl_sqlite_tokenizer=>c_rparen.
      DO.
        lo_argument = parse_expression_internal( 0 ).
        APPEND lo_argument TO lt_arguments.
        IF current( )-kind = zcl_sqlite_tokenizer=>c_comma.
          advance( ).
          CONTINUE.
        ENDIF.
        EXIT.
      ENDDO.
    ENDIF.

    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
    ro_node = NEW zcl_sqlite_ast_function(
      iv_name      = iv_name
      iv_distinct  = lv_distinct
      iv_star      = lv_star
      it_arguments = lt_arguments ).
  ENDMETHOD.

  METHOD parse_case.
    DATA lo_base TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_condition TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_result TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_else TYPE REF TO zcl_sqlite_ast_node.
    DATA lt_whens TYPE zcl_sqlite_ast_case=>ty_whens.
    DATA ls_when TYPE zcl_sqlite_ast_case=>ty_when.

    expect_keyword( 'CASE' ).

    IF is_keyword( 'WHEN' ) = abap_false.
      lo_base = parse_expression_internal( 0 ).
    ENDIF.

    WHILE is_keyword( 'WHEN' ) = abap_true.
      advance( ).
      lo_condition = parse_expression_internal( 0 ).
      expect_keyword( 'THEN' ).
      lo_result = parse_expression_internal( 0 ).
      ls_when-condition = lo_condition.
      ls_when-result = lo_result.
      APPEND ls_when TO lt_whens.
      CLEAR ls_when.
    ENDWHILE.

    IF lines( lt_whens ) = 0.
      fail( 'CASE requires WHEN' ).
    ENDIF.

    IF is_keyword( 'ELSE' ) = abap_true.
      advance( ).
      lo_else = parse_expression_internal( 0 ).
    ENDIF.

    expect_keyword( 'END' ).
    ro_node = NEW zcl_sqlite_ast_case(
      it_whens = lt_whens
      io_base  = lo_base
      io_else  = lo_else ).
  ENDMETHOD.

  METHOD parse_cast.
    DATA lo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA lv_type TYPE string.

    expect_keyword( 'CAST' ).
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
    lo_expression = parse_expression_internal( 0 ).
    expect_keyword( 'AS' ).
    lv_type = parse_type_name( ).
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).

    ro_node = NEW zcl_sqlite_ast_cast(
      io_expression = lo_expression
      iv_type       = lv_type ).
  ENDMETHOD.

  METHOD parse_type_name.
    DATA lv_part TYPE string.

    WHILE current( )-kind = zcl_sqlite_tokenizer=>c_identifier.
      lv_part = to_upper( current( )-value ).
      IF rv_type IS INITIAL.
        rv_type = lv_part.
      ELSE.
        " ANORMALY: character literals lose trailing blanks when concatenated
        rv_type = rv_type && | | && lv_part.
      ENDIF.
      advance( ).
    ENDWHILE.

    IF rv_type IS INITIAL.
      fail( 'expected type name' ).
    ENDIF.

    IF current( )-kind = zcl_sqlite_tokenizer=>c_lparen.
      rv_type = rv_type && '('.
      advance( ).
      WHILE current( )-kind <> zcl_sqlite_tokenizer=>c_rparen
          AND current( )-kind <> zcl_sqlite_tokenizer=>c_eof.
        rv_type = rv_type && current( )-text.
        advance( ).
      ENDWHILE.
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
      rv_type = rv_type && ')'.
    ENDIF.
  ENDMETHOD.

  METHOD parse_in.
    DATA lt_values TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA lo_value TYPE REF TO zcl_sqlite_ast_node.

    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
    IF current( )-kind = zcl_sqlite_tokenizer=>c_rparen.
      fail( 'IN requires at least one value' ).
    ENDIF.

    DO.
      lo_value = parse_expression_internal( 0 ).
      APPEND lo_value TO lt_values.
      IF current( )-kind = zcl_sqlite_tokenizer=>c_comma.
        advance( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.

    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
    ro_node = NEW zcl_sqlite_ast_in(
      io_expression = io_expression
      it_values     = lt_values
      iv_negated    = iv_negated ).
  ENDMETHOD.

  METHOD parse_between.
    DATA lo_low TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_high TYPE REF TO zcl_sqlite_ast_node.

    lo_low = parse_expression_internal( c_prec_relational ).
    expect_keyword( 'AND' ).
    lo_high = parse_expression_internal( c_prec_relational ).

    ro_node = NEW zcl_sqlite_ast_between(
      io_expression = io_expression
      io_low        = lo_low
      io_high       = lo_high
      iv_negated    = iv_negated ).
  ENDMETHOD.

  METHOD parse_like.
    DATA lo_pattern TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_escape TYPE REF TO zcl_sqlite_ast_node.

    lo_pattern = parse_expression_internal( c_prec_relational ).
    IF is_keyword( 'ESCAPE' ) = abap_true.
      advance( ).
      lo_escape = parse_expression_internal( c_prec_relational ).
    ENDIF.

    ro_node = NEW zcl_sqlite_ast_like(
      io_expression = io_expression
      io_pattern    = lo_pattern
      iv_operator   = iv_operator
      iv_negated    = iv_negated
      io_escape     = lo_escape ).
  ENDMETHOD.

  METHOD parse_collate.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    ls_token = current( ).
    IF ls_token-kind <> zcl_sqlite_tokenizer=>c_identifier
        AND ls_token-kind <> zcl_sqlite_tokenizer=>c_keyword.
      fail( 'expected collation name' ).
    ENDIF.
    advance( ).

    ro_node = NEW zcl_sqlite_ast_collate(
      io_expression = io_expression
      iv_name       = to_upper( ls_token-value ) ).
  ENDMETHOD.

  METHOD current.
    rs_token = token_at( 0 ).
  ENDMETHOD.

  METHOD token_at.
    DATA lv_index TYPE i.

    lv_index = mv_index + iv_ahead.
    IF lv_index < 1.
      lv_index = 1.
    ENDIF.

    READ TABLE mt_tokens INTO rs_token INDEX lv_index.
    IF sy-subrc <> 0.
      CLEAR rs_token.
      rs_token-kind = zcl_sqlite_tokenizer=>c_eof.
    ENDIF.
  ENDMETHOD.

  METHOD advance.
    IF mv_index < lines( mt_tokens ).
      mv_index = mv_index + 1.
    ENDIF.
  ENDMETHOD.

  METHOD is_keyword.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    ls_token = current( ).
    rv_result = boolc( ls_token-kind = zcl_sqlite_tokenizer=>c_keyword
      AND ls_token-value = to_upper( iv_keyword ) ).
  ENDMETHOD.

  METHOD is_keyword_at.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    ls_token = token_at( iv_ahead ).
    rv_result = boolc( ls_token-kind = zcl_sqlite_tokenizer=>c_keyword
      AND ls_token-value = to_upper( iv_keyword ) ).
  ENDMETHOD.

  METHOD is_operator.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    ls_token = current( ).
    rv_result = boolc( ls_token-kind = zcl_sqlite_tokenizer=>c_operator
      AND ls_token-text = iv_operator ).
  ENDMETHOD.

  METHOD is_kind.
    rv_result = boolc( current( )-kind = iv_kind ).
  ENDMETHOD.

  METHOD expect_keyword.
    IF is_keyword( iv_keyword ) = abap_false.
      fail( |expected { iv_keyword }| ).
    ENDIF.
    advance( ).
  ENDMETHOD.

  METHOD expect_operator.
    IF is_operator( iv_operator ) = abap_false.
      fail( |expected "{ iv_operator }"| ).
    ENDIF.
    advance( ).
  ENDMETHOD.

  METHOD expect_kind.
    IF current( )-kind <> iv_kind.
      fail( |expected { iv_expected }| ).
    ENDIF.
    advance( ).
  ENDMETHOD.

  METHOD binary_precedence.
    CASE iv_operator.
      WHEN '->' OR '->>' OR '||'.
        rv_precedence = c_prec_concat.
      WHEN '*' OR '/' OR '%'.
        rv_precedence = c_prec_multiply.
      WHEN '+' OR '-'.
        rv_precedence = c_prec_additive.
      WHEN '&' OR '|' OR '<<' OR '>>'.
        rv_precedence = c_prec_bitwise.
      WHEN '<' OR '<=' OR '>' OR '>='.
        rv_precedence = c_prec_relational.
      WHEN '=' OR '==' OR '!=' OR '<>'.
        rv_precedence = c_prec_equality.
      WHEN OTHERS.
        rv_precedence = 0.
    ENDCASE.
  ENDMETHOD.

  METHOD fail.
    DATA lv_near TYPE string.

    lv_near = current( )-text.
    IF lv_near IS INITIAL.
      lv_near = 'end of input'.
    ENDIF.

    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = zcx_sqlite_error=>sqlite_error
        iv_message = |near "{ lv_near }": { iv_message }|.
  ENDMETHOD.

ENDCLASS.
