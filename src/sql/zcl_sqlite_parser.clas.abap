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

    CLASS-METHODS parse_statement
      IMPORTING iv_sql              TYPE string
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    CLASS-METHODS dump_statement
      IMPORTING iv_sql         TYPE string
      RETURNING VALUE(rv_text) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS parse_script
      IMPORTING iv_sql               TYPE string
      RETURNING VALUE(rt_statements) TYPE zcl_sqlite_ast_node=>ty_nodes
      RAISING   zcx_sqlite_error.

    CLASS-METHODS dump_script
      IMPORTING iv_sql          TYPE string
      RETURNING VALUE(rt_texts) TYPE zcl_sqlite_ast_node=>ty_names
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    CLASS-METHODS parse_script_statement
      IMPORTING iv_sql              TYPE string
                iv_start            TYPE i
                iv_base_line        TYPE i
                iv_base_column      TYPE i
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

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

    TYPES: BEGIN OF ty_select_tail,
             mt_order_by TYPE zcl_sqlite_ast_order_by=>ty_list,
             mo_limit    TYPE REF TO zcl_sqlite_ast_node,
             mo_offset   TYPE REF TO zcl_sqlite_ast_node,
           END OF ty_select_tail.

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

    METHODS parse_exists
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

    METHODS parse_create
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_create_table
      IMPORTING iv_temporary        TYPE abap_bool
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_create_table
      RAISING   zcx_sqlite_error.

    METHODS parse_create_index
      IMPORTING iv_unique           TYPE abap_bool
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_create_index
      RAISING   zcx_sqlite_error.

    METHODS parse_drop
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_drop
      RAISING   zcx_sqlite_error.

    METHODS parse_statement_body
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_transaction
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_transaction
      RAISING   zcx_sqlite_error.

    METHODS parse_pragma
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_pragma
      RAISING   zcx_sqlite_error.

    METHODS parse_pragma_value
      RETURNING VALUE(rv_value) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS parse_explain
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_explain
      RAISING   zcx_sqlite_error.

    METHODS parse_insert
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_insert
      RAISING   zcx_sqlite_error.

    METHODS parse_update
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_update
      RAISING   zcx_sqlite_error.

    METHODS parse_delete
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_delete
      RAISING   zcx_sqlite_error.

    METHODS parse_or_conflict_action
      RETURNING VALUE(rv_action) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS parse_assignment_list
      RETURNING VALUE(rt_assignments) TYPE zcl_sqlite_ast_assignment=>ty_list
      RAISING   zcx_sqlite_error.

    METHODS parse_assignment
      RETURNING VALUE(ro_assignment) TYPE REF TO zcl_sqlite_ast_assignment
      RAISING   zcx_sqlite_error.

    METHODS parse_select_or_dml
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_select_statement
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_select_core
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_select
      RAISING   zcx_sqlite_error.

    METHODS parse_select_tail
      RETURNING VALUE(rs_tail) TYPE ty_select_tail
      RAISING   zcx_sqlite_error.

    METHODS parse_parenthesized_select
      RETURNING VALUE(ro_ref) TYPE REF TO zcl_sqlite_ast_subquery_ref
      RAISING   zcx_sqlite_error.

    METHODS parse_with
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_with
      RAISING   zcx_sqlite_error.

    METHODS parse_cte
      RETURNING VALUE(ro_cte) TYPE REF TO zcl_sqlite_ast_cte
      RAISING   zcx_sqlite_error.

    METHODS is_select_start
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS parse_values
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_values
      RAISING   zcx_sqlite_error.

    METHODS parse_values_row
      RETURNING VALUE(ro_row) TYPE REF TO zcl_sqlite_ast_values_row
      RAISING   zcx_sqlite_error.

    METHODS parse_result_columns
      RETURNING VALUE(rt_columns) TYPE zcl_sqlite_ast_result_column=>ty_list
      RAISING   zcx_sqlite_error.

    METHODS parse_result_column
      RETURNING VALUE(ro_column) TYPE REF TO zcl_sqlite_ast_result_column
      RAISING   zcx_sqlite_error.

    METHODS parse_optional_alias
      RETURNING VALUE(rv_alias) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS parse_alias_name
      RETURNING VALUE(rv_alias) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS parse_from_items
      RETURNING VALUE(rt_items) TYPE zcl_sqlite_ast_node=>ty_nodes
      RAISING   zcx_sqlite_error.

    METHODS parse_from_item
      RETURNING VALUE(ro_item) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_table_ref
      RETURNING VALUE(ro_ref) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_join
      IMPORTING io_left        TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(ro_join) TYPE REF TO zcl_sqlite_ast_join
      RAISING   zcx_sqlite_error.

    METHODS is_join_start
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS parse_expression_list
      RETURNING VALUE(rt_expressions) TYPE zcl_sqlite_ast_node=>ty_nodes
      RAISING   zcx_sqlite_error.

    METHODS parse_order_by_list
      RETURNING VALUE(rt_order_by) TYPE zcl_sqlite_ast_order_by=>ty_list
      RAISING   zcx_sqlite_error.

    METHODS parse_order_by
      RETURNING VALUE(ro_order_by) TYPE REF TO zcl_sqlite_ast_order_by
      RAISING   zcx_sqlite_error.

    METHODS parse_column_def
      RETURNING VALUE(ro_column) TYPE REF TO zcl_sqlite_ast_column_def
      RAISING   zcx_sqlite_error.

    METHODS parse_table_constraint
      RETURNING VALUE(ro_constraint) TYPE REF TO zcl_sqlite_ast_constraint
      RAISING   zcx_sqlite_error.

    METHODS parse_column_constraint
      RETURNING VALUE(ro_constraint) TYPE REF TO zcl_sqlite_ast_constraint
      RAISING   zcx_sqlite_error.

    METHODS parse_constraint_name
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS parse_conflict_clause
      RETURNING VALUE(rv_action) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS parse_default_expression
      RETURNING VALUE(ro_expression) TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS parse_reference_clause
      RETURNING VALUE(rs_reference) TYPE zcl_sqlite_ast_constraint=>ty_reference
      RAISING   zcx_sqlite_error.

    METHODS parse_reference_action
      RETURNING VALUE(rv_action) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS parse_foreign_key_clauses
      CHANGING cs_reference TYPE zcl_sqlite_ast_constraint=>ty_reference
      RAISING  zcx_sqlite_error.

    METHODS parse_indexed_column
      RETURNING VALUE(ro_column) TYPE REF TO zcl_sqlite_ast_indexed_column
      RAISING   zcx_sqlite_error.

    METHODS parse_indexed_columns
      RETURNING VALUE(rt_columns) TYPE zcl_sqlite_ast_indexed_column=>ty_list
      RAISING   zcx_sqlite_error.

    METHODS parse_name_list
      RETURNING VALUE(rt_names) TYPE zcl_sqlite_ast_node=>ty_names
      RAISING   zcx_sqlite_error.

    METHODS parse_optional_storage
      RETURNING VALUE(rv_storage) TYPE string.

    METHODS parse_table_options
      CHANGING cv_without_rowid TYPE abap_bool
               cv_strict        TYPE abap_bool
      RAISING  zcx_sqlite_error.

    METHODS parse_object_name
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS parse_identifier
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS parse_optional_type_name
      RETURNING VALUE(rv_type) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS parse_collation_name
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS is_table_constraint_start
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS is_column_constraint_start
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS is_word
      IMPORTING iv_word          TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS is_word_at
      IMPORTING iv_ahead         TYPE i
                iv_word          TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS expect_word
      IMPORTING iv_word TYPE string
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

  METHOD parse_statement.
    DATA lo_parser TYPE REF TO zcl_sqlite_parser.

    lo_parser = NEW #( iv_sql ).
    ro_statement = lo_parser->parse_statement_body( ).

    WHILE lo_parser->is_kind( zcl_sqlite_tokenizer=>c_semicolon ) = abap_true.
      lo_parser->advance( ).
    ENDWHILE.
    IF lo_parser->is_kind( zcl_sqlite_tokenizer=>c_eof ) = abap_false.
      lo_parser->fail( 'syntax error' ).
    ENDIF.
  ENDMETHOD.

  METHOD dump_statement.
    rv_text = parse_statement( iv_sql )->dump( ).
  ENDMETHOD.

  METHOD parse_script.
    DATA lt_tokens      TYPE zcl_sqlite_tokenizer=>ty_tokens.
    DATA ls_token       TYPE zcl_sqlite_tokenizer=>ty_token.
    DATA lv_start       TYPE i VALUE 1.
    DATA lv_base_line   TYPE i VALUE 1.
    DATA lv_base_column TYPE i VALUE 1.
    DATA lv_length      TYPE i.
    DATA lv_has_content TYPE abap_bool.
    DATA lv_sql         TYPE string.

    lt_tokens = zcl_sqlite_tokenizer=>tokenize( iv_sql ).
    LOOP AT lt_tokens INTO ls_token.
      IF ls_token-kind = zcl_sqlite_tokenizer=>c_semicolon.
        IF lv_has_content = abap_true.
          lv_length = ls_token-offset - lv_start.
          IF lv_length > 0.
            lv_sql = substring(
              val = iv_sql
              off = lv_start - 1
              len = lv_length ).
            APPEND parse_script_statement(
              iv_sql         = lv_sql
              iv_start       = lv_start
              iv_base_line   = lv_base_line
              iv_base_column = lv_base_column ) TO rt_statements.
          ENDIF.
        ENDIF.
        lv_start = ls_token-offset + ls_token-length.
        lv_base_line = ls_token-line.
        lv_base_column = ls_token-column + ls_token-length.
        CLEAR lv_has_content.
        CONTINUE.
      ENDIF.
      IF ls_token-kind <> zcl_sqlite_tokenizer=>c_eof
          AND ls_token-kind <> zcl_sqlite_tokenizer=>c_comment.
        lv_has_content = abap_true.
      ENDIF.
    ENDLOOP.

    IF lv_has_content = abap_true.
      lv_sql = substring(
        val = iv_sql
        off = lv_start - 1 ).
      APPEND parse_script_statement(
        iv_sql         = lv_sql
        iv_start       = lv_start
        iv_base_line   = lv_base_line
        iv_base_column = lv_base_column ) TO rt_statements.
    ENDIF.
  ENDMETHOD.

  METHOD parse_script_statement.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA lv_position TYPE i.
    DATA lv_line     TYPE i.
    DATA lv_column   TYPE i.

    TRY.
        ro_statement = parse_statement( iv_sql ).
      CATCH zcx_sqlite_error INTO lo_error.
        lv_position = iv_start - 1 + lo_error->position.
        IF lo_error->line <= 1.
          lv_line = iv_base_line.
          lv_column = iv_base_column + lo_error->column - 1.
        ELSE.
          lv_line = iv_base_line + lo_error->line - 1.
          lv_column = lo_error->column.
        ENDIF.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code     = lo_error->code
            iv_message  = lo_error->message
            iv_position = lv_position
            iv_line     = lv_line
            iv_column   = lv_column.
    ENDTRY.
  ENDMETHOD.

  METHOD dump_script.
    DATA lt_statements TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA lo_statement  TYPE REF TO zcl_sqlite_ast_node.

    lt_statements = parse_script( iv_sql ).
    LOOP AT lt_statements INTO lo_statement.
      APPEND lo_statement->dump( ) TO rt_texts.
    ENDLOOP.
  ENDMETHOD.

  METHOD parse_statement_body.
    IF is_keyword( 'CREATE' ) = abap_true.
      ro_statement = parse_create( ).
    ELSEIF is_keyword( 'DROP' ) = abap_true.
      ro_statement = parse_drop( ).
    ELSEIF is_keyword( 'INSERT' ) = abap_true.
      ro_statement = parse_insert( ).
    ELSEIF is_keyword( 'UPDATE' ) = abap_true.
      ro_statement = parse_update( ).
    ELSEIF is_keyword( 'DELETE' ) = abap_true.
      ro_statement = parse_delete( ).
    ELSEIF is_keyword( 'BEGIN' ) = abap_true
        OR is_keyword( 'COMMIT' ) = abap_true
        OR is_keyword( 'END' ) = abap_true
        OR is_keyword( 'ROLLBACK' ) = abap_true.
      ro_statement = parse_transaction( ).
    ELSEIF is_keyword( 'PRAGMA' ) = abap_true.
      ro_statement = parse_pragma( ).
    ELSEIF is_keyword( 'EXPLAIN' ) = abap_true.
      ro_statement = parse_explain( ).
    ELSEIF is_keyword( 'SELECT' ) = abap_true
        OR is_keyword( 'VALUES' ) = abap_true
        OR is_keyword( 'WITH' ) = abap_true
        OR is_kind( zcl_sqlite_tokenizer=>c_lparen ) = abap_true.
      ro_statement = parse_select_statement( ).
    ELSE.
      fail( 'expected CREATE, DROP, INSERT, UPDATE, DELETE, BEGIN, COMMIT, END, ROLLBACK, PRAGMA, EXPLAIN, SELECT, VALUES or WITH' ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_transaction.
    DATA lv_action      TYPE string.
    DATA lv_mode        TYPE string.
    DATA lv_transaction TYPE abap_bool.
    DATA lv_to          TYPE string.
    DATA lv_savepoint   TYPE abap_bool.

    lv_action = current( )-value.
    CASE lv_action.
      WHEN 'BEGIN'.
        advance( ).
        IF is_keyword( 'DEFERRED' ) = abap_true
            OR is_keyword( 'IMMEDIATE' ) = abap_true
            OR is_keyword( 'EXCLUSIVE' ) = abap_true.
          lv_mode = current( )-value.
          advance( ).
        ENDIF.
        IF is_keyword( 'TRANSACTION' ) = abap_true.
          lv_transaction = abap_true.
          advance( ).
        ENDIF.
      WHEN 'COMMIT' OR 'END'.
        advance( ).
        IF is_keyword( 'TRANSACTION' ) = abap_true.
          lv_transaction = abap_true.
          advance( ).
        ENDIF.
      WHEN 'ROLLBACK'.
        advance( ).
        IF is_keyword( 'TRANSACTION' ) = abap_true.
          lv_transaction = abap_true.
          advance( ).
        ENDIF.
        IF is_keyword( 'TO' ) = abap_true.
          advance( ).
          IF is_keyword( 'SAVEPOINT' ) = abap_true.
            lv_savepoint = abap_true.
            advance( ).
          ENDIF.
          lv_to = parse_identifier( ).
        ENDIF.
      WHEN OTHERS.
        fail( 'expected transaction statement' ).
    ENDCASE.

    ro_statement = NEW zcl_sqlite_ast_transaction(
      iv_action      = lv_action
      iv_mode        = lv_mode
      iv_transaction = lv_transaction
      iv_to          = lv_to
      iv_savepoint   = lv_savepoint ).
  ENDMETHOD.

  METHOD parse_pragma.
    DATA lv_name      TYPE string.
    DATA lv_separator TYPE string.
    DATA lv_value     TYPE string.

    expect_keyword( 'PRAGMA' ).
    lv_name = parse_object_name( ).
    IF is_operator( '=' ) = abap_true.
      lv_separator = '='.
      advance( ).
      lv_value = parse_pragma_value( ).
    ELSEIF is_kind( zcl_sqlite_tokenizer=>c_lparen ) = abap_true.
      lv_separator = '('.
      advance( ).
      lv_value = parse_pragma_value( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
    ENDIF.

    ro_statement = NEW zcl_sqlite_ast_pragma(
      iv_name      = lv_name
      iv_separator = lv_separator
      iv_value     = lv_value ).
  ENDMETHOD.

  METHOD parse_pragma_value.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    IF is_operator( '+' ) = abap_true OR is_operator( '-' ) = abap_true.
      rv_value = current( )-text.
      advance( ).
      ls_token = current( ).
      IF ls_token-kind <> zcl_sqlite_tokenizer=>c_integer
          AND ls_token-kind <> zcl_sqlite_tokenizer=>c_float.
        fail( 'expected numeric pragma value' ).
      ENDIF.
      rv_value = rv_value && ls_token-text.
      advance( ).
      RETURN.
    ENDIF.

    ls_token = current( ).
    CASE ls_token-kind.
      WHEN zcl_sqlite_tokenizer=>c_integer
          OR zcl_sqlite_tokenizer=>c_float
          OR zcl_sqlite_tokenizer=>c_string
          OR zcl_sqlite_tokenizer=>c_identifier
          OR zcl_sqlite_tokenizer=>c_keyword
          OR zcl_sqlite_tokenizer=>c_blob
          OR zcl_sqlite_tokenizer=>c_parameter.
        rv_value = rv_value && ls_token-text.
        advance( ).
      WHEN OTHERS.
        fail( 'expected pragma value' ).
    ENDCASE.
  ENDMETHOD.

  METHOD parse_explain.
    DATA lv_query_plan TYPE abap_bool.
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.

    expect_keyword( 'EXPLAIN' ).
    IF is_keyword( 'QUERY' ) = abap_true.
      advance( ).
      expect_keyword( 'PLAN' ).
      lv_query_plan = abap_true.
    ENDIF.
    lo_statement = parse_statement_body( ).

    ro_statement = NEW zcl_sqlite_ast_explain(
      iv_query_plan = lv_query_plan
      io_statement  = lo_statement ).
  ENDMETHOD.

  METHOD parse_create.
    DATA lv_temporary TYPE abap_bool.

    expect_keyword( 'CREATE' ).
    IF is_keyword( 'TEMP' ) = abap_true OR is_keyword( 'TEMPORARY' ) = abap_true.
      lv_temporary = abap_true.
      advance( ).
    ENDIF.

    IF lv_temporary = abap_true.
      IF is_keyword( 'TABLE' ) = abap_false.
        fail( 'expected TABLE after TEMP' ).
      ENDIF.
      ro_statement = parse_create_table( lv_temporary ).
    ELSEIF is_keyword( 'TABLE' ) = abap_true.
      ro_statement = parse_create_table( lv_temporary ).
    ELSEIF is_keyword( 'UNIQUE' ) = abap_true.
      advance( ).
      ro_statement = parse_create_index( abap_true ).
    ELSEIF is_keyword( 'INDEX' ) = abap_true.
      ro_statement = parse_create_index( abap_false ).
    ELSE.
      fail( 'expected TABLE or INDEX' ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_create_table.
    DATA lv_name          TYPE string.
    DATA lv_if_not_exists TYPE abap_bool.
    DATA lv_without_rowid TYPE abap_bool.
    DATA lv_strict        TYPE abap_bool.
    DATA lt_columns       TYPE zcl_sqlite_ast_create_table=>ty_columns.
    DATA lt_constraints   TYPE zcl_sqlite_ast_create_table=>ty_constraints.
    DATA lo_column        TYPE REF TO zcl_sqlite_ast_column_def.
    DATA lo_constraint    TYPE REF TO zcl_sqlite_ast_constraint.

    expect_keyword( 'TABLE' ).
    IF is_keyword( 'IF' ) = abap_true.
      advance( ).
      expect_keyword( 'NOT' ).
      expect_keyword( 'EXISTS' ).
      lv_if_not_exists = abap_true.
    ENDIF.
    lv_name = parse_object_name( ).
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
    IF is_kind( zcl_sqlite_tokenizer=>c_rparen ) = abap_true.
      fail( 'expected column definition' ).
    ENDIF.

    DO.
      IF is_table_constraint_start( ) = abap_true.
        lo_constraint = parse_table_constraint( ).
        APPEND lo_constraint TO lt_constraints.
      ELSE.
        lo_column = parse_column_def( ).
        APPEND lo_column TO lt_columns.
      ENDIF.

      IF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true.
        advance( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.

    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
    parse_table_options(
      CHANGING
        cv_without_rowid = lv_without_rowid
        cv_strict        = lv_strict ).

    IF lines( lt_columns ) = 0.
      fail( 'CREATE TABLE requires a column definition' ).
    ENDIF.

    ro_statement = NEW zcl_sqlite_ast_create_table(
      iv_name          = lv_name
      iv_temporary     = iv_temporary
      iv_if_not_exists = lv_if_not_exists
      it_columns       = lt_columns
      it_constraints   = lt_constraints
      iv_without_rowid = lv_without_rowid
      iv_strict        = lv_strict ).
  ENDMETHOD.

  METHOD parse_create_index.
    DATA lv_name          TYPE string.
    DATA lv_table_name    TYPE string.
    DATA lv_if_not_exists TYPE abap_bool.
    DATA lt_columns       TYPE zcl_sqlite_ast_indexed_column=>ty_list.
    DATA lo_where         TYPE REF TO zcl_sqlite_ast_node.

    expect_keyword( 'INDEX' ).
    IF is_keyword( 'IF' ) = abap_true.
      advance( ).
      expect_keyword( 'NOT' ).
      expect_keyword( 'EXISTS' ).
      lv_if_not_exists = abap_true.
    ENDIF.
    lv_name = parse_object_name( ).
    expect_keyword( 'ON' ).
    lv_table_name = parse_object_name( ).
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
    lt_columns = parse_indexed_columns( ).
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).

    IF is_keyword( 'WHERE' ) = abap_true.
      advance( ).
      lo_where = parse_expression_internal( 0 ).
    ENDIF.

    ro_statement = NEW zcl_sqlite_ast_create_index(
      iv_name          = lv_name
      iv_table_name    = lv_table_name
      iv_unique        = iv_unique
      iv_if_not_exists = lv_if_not_exists
      it_columns       = lt_columns
      io_where         = lo_where ).
  ENDMETHOD.

  METHOD parse_drop.
    DATA lv_object_type TYPE string.
    DATA lv_name        TYPE string.
    DATA lv_if_exists   TYPE abap_bool.

    expect_keyword( 'DROP' ).
    IF is_keyword( 'TABLE' ) = abap_true OR is_keyword( 'INDEX' ) = abap_true.
      lv_object_type = current( )-value.
      advance( ).
    ELSE.
      fail( 'expected TABLE or INDEX' ).
    ENDIF.

    IF is_keyword( 'IF' ) = abap_true.
      advance( ).
      expect_keyword( 'EXISTS' ).
      lv_if_exists = abap_true.
    ENDIF.
    lv_name = parse_object_name( ).

    ro_statement = NEW zcl_sqlite_ast_drop(
      iv_object_type = lv_object_type
      iv_name        = lv_name
      iv_if_exists   = lv_if_exists ).
  ENDMETHOD.

  METHOD parse_insert.
    DATA lv_conflict       TYPE string.
    DATA lv_table          TYPE string.
    DATA lt_columns        TYPE zcl_sqlite_ast_node=>ty_names.
    DATA lo_values         TYPE REF TO zcl_sqlite_ast_values.
    DATA lo_select         TYPE REF TO zcl_sqlite_ast_node.
    DATA lv_default_values TYPE abap_bool.

    expect_keyword( 'INSERT' ).
    lv_conflict = parse_or_conflict_action( ).
    expect_keyword( 'INTO' ).
    lv_table = parse_object_name( ).

    IF is_kind( zcl_sqlite_tokenizer=>c_lparen ) = abap_true.
      advance( ).
      lt_columns = parse_name_list( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
    ENDIF.

    IF is_keyword( 'DEFAULT' ) = abap_true.
      advance( ).
      expect_keyword( 'VALUES' ).
      lv_default_values = abap_true.
    ELSEIF is_keyword( 'VALUES' ) = abap_true.
      lo_values = parse_values( ).
    ELSE.
      lo_select = parse_select_statement( ).
    ENDIF.

    ro_statement = NEW zcl_sqlite_ast_insert(
      iv_conflict       = lv_conflict
      iv_table          = lv_table
      it_columns        = lt_columns
      io_values         = lo_values
      io_select         = lo_select
      iv_default_values = lv_default_values ).
  ENDMETHOD.

  METHOD parse_update.
    DATA lv_conflict    TYPE string.
    DATA lv_table       TYPE string.
    DATA lv_alias       TYPE string.
    DATA lt_assignments TYPE zcl_sqlite_ast_assignment=>ty_list.
    DATA lt_from        TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA lo_where       TYPE REF TO zcl_sqlite_ast_node.

    expect_keyword( 'UPDATE' ).
    lv_conflict = parse_or_conflict_action( ).
    lv_table = parse_object_name( ).
    lv_alias = parse_optional_alias( ).
    expect_keyword( 'SET' ).
    lt_assignments = parse_assignment_list( ).

    IF is_keyword( 'FROM' ) = abap_true.
      advance( ).
      lt_from = parse_from_items( ).
    ENDIF.
    IF is_keyword( 'WHERE' ) = abap_true.
      advance( ).
      lo_where = parse_expression_internal( 0 ).
    ENDIF.

    ro_statement = NEW zcl_sqlite_ast_update(
      iv_conflict    = lv_conflict
      iv_table       = lv_table
      iv_alias       = lv_alias
      it_assignments = lt_assignments
      it_from        = lt_from
      io_where       = lo_where ).
  ENDMETHOD.

  METHOD parse_delete.
    DATA lv_table TYPE string.
    DATA lv_alias TYPE string.
    DATA lo_where TYPE REF TO zcl_sqlite_ast_node.

    expect_keyword( 'DELETE' ).
    expect_keyword( 'FROM' ).
    lv_table = parse_object_name( ).
    lv_alias = parse_optional_alias( ).
    IF is_keyword( 'WHERE' ) = abap_true.
      advance( ).
      lo_where = parse_expression_internal( 0 ).
    ENDIF.

    ro_statement = NEW zcl_sqlite_ast_delete(
      iv_table = lv_table
      iv_alias = lv_alias
      io_where = lo_where ).
  ENDMETHOD.

  METHOD parse_or_conflict_action.
    IF is_keyword( 'OR' ) = abap_false.
      RETURN.
    ENDIF.

    advance( ).
    CASE current( )-value.
      WHEN 'ROLLBACK' OR 'ABORT' OR 'REPLACE' OR 'FAIL' OR 'IGNORE'.
        rv_action = |OR { current( )-value }|.
        advance( ).
      WHEN OTHERS.
        fail( 'expected conflict action' ).
    ENDCASE.
  ENDMETHOD.

  METHOD parse_assignment_list.
    DO.
      APPEND parse_assignment( ) TO rt_assignments.
      IF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true.
        advance( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.
  ENDMETHOD.

  METHOD parse_assignment.
    DATA lv_column     TYPE string.
    DATA lo_expression TYPE REF TO zcl_sqlite_ast_node.

    lv_column = parse_identifier( ).
    expect_operator( '=' ).
    lo_expression = parse_expression_internal( 0 ).

    ro_assignment = NEW zcl_sqlite_ast_assignment(
      iv_column     = lv_column
      io_expression = lo_expression ).
  ENDMETHOD.

  METHOD parse_select_or_dml.
    IF is_keyword( 'INSERT' ) = abap_true.
      ro_statement = parse_insert( ).
    ELSEIF is_keyword( 'UPDATE' ) = abap_true.
      ro_statement = parse_update( ).
    ELSEIF is_keyword( 'DELETE' ) = abap_true.
      ro_statement = parse_delete( ).
    ELSE.
      ro_statement = parse_select_statement( ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_select_statement.
    DATA lo_select   TYPE REF TO zcl_sqlite_ast_select.
    DATA lo_values   TYPE REF TO zcl_sqlite_ast_values.
    DATA lo_body     TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_right    TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_compound TYPE REF TO zcl_sqlite_ast_compound.
    DATA lv_kind     TYPE string.
    DATA lv_operator TYPE string.
    DATA lv_all      TYPE abap_bool.
    DATA ls_tail     TYPE ty_select_tail.

    IF is_keyword( 'WITH' ) = abap_true.
      ro_statement = parse_with( ).
      RETURN.
    ENDIF.

    IF is_keyword( 'SELECT' ) = abap_true.
      lo_select = parse_select_core( ).
      lo_body = lo_select.
      lv_kind = 'SELECT'.
    ELSEIF is_keyword( 'VALUES' ) = abap_true.
      lo_values = parse_values( ).
      lo_body = lo_values.
      lv_kind = 'VALUES'.
    ELSEIF is_kind( zcl_sqlite_tokenizer=>c_lparen ) = abap_true.
      lo_body = parse_parenthesized_select( ).
      lv_kind = 'PAREN'.
    ELSE.
      fail( 'expected SELECT or VALUES' ).
    ENDIF.

    WHILE is_keyword( 'UNION' ) = abap_true
        OR is_keyword( 'INTERSECT' ) = abap_true
        OR is_keyword( 'EXCEPT' ) = abap_true.
      lv_operator = current( )-value.
      lv_all = abap_false.
      advance( ).
      IF lv_operator = 'UNION' AND is_keyword( 'ALL' ) = abap_true.
        lv_all = abap_true.
        advance( ).
      ENDIF.

      IF is_keyword( 'SELECT' ) = abap_true.
        lo_right = parse_select_core( ).
      ELSEIF is_keyword( 'VALUES' ) = abap_true.
        lo_right = parse_values( ).
      ELSEIF is_kind( zcl_sqlite_tokenizer=>c_lparen ) = abap_true.
        lo_right = parse_parenthesized_select( ).
      ELSE.
        fail( 'expected SELECT or VALUES after compound operator' ).
      ENDIF.

      lo_compound = NEW zcl_sqlite_ast_compound(
        io_left     = lo_body
        iv_operator = lv_operator
        iv_all      = lv_all
        io_right    = lo_right ).
      lo_body = lo_compound.
      lv_kind = 'COMPOUND'.
    ENDWHILE.

    ls_tail = parse_select_tail( ).
    CASE lv_kind.
      WHEN 'SELECT'.
        ro_statement = lo_select->with_tail(
          it_order_by = ls_tail-mt_order_by
          io_limit    = ls_tail-mo_limit
          io_offset   = ls_tail-mo_offset ).
      WHEN 'VALUES'.
        ro_statement = lo_values->with_tail(
          it_order_by = ls_tail-mt_order_by
          io_limit    = ls_tail-mo_limit
          io_offset   = ls_tail-mo_offset ).
      WHEN 'COMPOUND'.
        ro_statement = lo_compound->with_tail(
          it_order_by = ls_tail-mt_order_by
          io_limit    = ls_tail-mo_limit
          io_offset   = ls_tail-mo_offset ).
      WHEN OTHERS.
        IF lines( ls_tail-mt_order_by ) > 0
            OR ls_tail-mo_limit IS BOUND
            OR ls_tail-mo_offset IS BOUND.
          fail( 'unexpected ORDER BY or LIMIT after parenthesized select' ).
        ENDIF.
        ro_statement = lo_body.
    ENDCASE.
  ENDMETHOD.

  METHOD parse_select_core.
    DATA lv_distinct TYPE abap_bool.
    DATA lt_columns  TYPE zcl_sqlite_ast_result_column=>ty_list.
    DATA lt_from     TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA lo_where    TYPE REF TO zcl_sqlite_ast_node.
    DATA lt_group_by TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA lo_having   TYPE REF TO zcl_sqlite_ast_node.

    expect_keyword( 'SELECT' ).
    IF is_keyword( 'DISTINCT' ) = abap_true.
      advance( ).
      lv_distinct = abap_true.
    ELSEIF is_keyword( 'ALL' ) = abap_true.
      advance( ).
    ENDIF.

    lt_columns = parse_result_columns( ).

    IF is_keyword( 'FROM' ) = abap_true.
      advance( ).
      lt_from = parse_from_items( ).
    ENDIF.
    IF is_keyword( 'WHERE' ) = abap_true.
      advance( ).
      lo_where = parse_expression_internal( 0 ).
    ENDIF.
    IF is_keyword( 'GROUP' ) = abap_true.
      advance( ).
      expect_keyword( 'BY' ).
      lt_group_by = parse_expression_list( ).
    ENDIF.
    IF is_keyword( 'HAVING' ) = abap_true.
      advance( ).
      lo_having = parse_expression_internal( 0 ).
    ENDIF.

    ro_statement = NEW zcl_sqlite_ast_select(
      iv_distinct = lv_distinct
      it_columns  = lt_columns
      it_from     = lt_from
      io_where    = lo_where
      it_group_by = lt_group_by
      io_having   = lo_having ).
  ENDMETHOD.

  METHOD parse_select_tail.
    IF is_keyword( 'ORDER' ) = abap_true.
      advance( ).
      expect_keyword( 'BY' ).
      rs_tail-mt_order_by = parse_order_by_list( ).
    ENDIF.
    IF is_keyword( 'LIMIT' ) = abap_true.
      advance( ).
      rs_tail-mo_limit = parse_expression_internal( 0 ).
      IF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true.
        advance( ).
        rs_tail-mo_offset = rs_tail-mo_limit.
        rs_tail-mo_limit = parse_expression_internal( 0 ).
      ENDIF.
      IF is_keyword( 'OFFSET' ) = abap_true.
        advance( ).
        rs_tail-mo_offset = parse_expression_internal( 0 ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD parse_parenthesized_select.
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.

    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
    lo_statement = parse_select_statement( ).
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).

    ro_ref = NEW zcl_sqlite_ast_subquery_ref( io_statement = lo_statement ).
  ENDMETHOD.

  METHOD parse_with.
    DATA lv_recursive TYPE abap_bool.
    DATA lt_ctes      TYPE zcl_sqlite_ast_cte=>ty_list.
    DATA lo_cte       TYPE REF TO zcl_sqlite_ast_cte.
    DATA lo_body      TYPE REF TO zcl_sqlite_ast_node.

    expect_keyword( 'WITH' ).
    IF is_keyword( 'RECURSIVE' ) = abap_true.
      lv_recursive = abap_true.
      advance( ).
    ENDIF.

    DO.
      lo_cte = parse_cte( ).
      APPEND lo_cte TO lt_ctes.
      IF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true.
        advance( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.

    lo_body = parse_select_or_dml( ).
    ro_statement = NEW zcl_sqlite_ast_with(
      iv_recursive = lv_recursive
      it_ctes      = lt_ctes
      io_statement = lo_body ).
  ENDMETHOD.

  METHOD parse_cte.
    DATA lv_name         TYPE string.
    DATA lv_materialized TYPE string.
    DATA lt_columns      TYPE zcl_sqlite_ast_node=>ty_names.
    DATA lo_statement    TYPE REF TO zcl_sqlite_ast_node.

    lv_name = parse_identifier( ).
    IF is_kind( zcl_sqlite_tokenizer=>c_lparen ) = abap_true.
      advance( ).
      lt_columns = parse_name_list( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
    ENDIF.
    expect_keyword( 'AS' ).

    IF is_word( 'NOT' ) = abap_true
        AND is_word_at( iv_ahead = 1 iv_word = 'MATERIALIZED' ) = abap_true.
      lv_materialized = 'NOT MATERIALIZED'.
      advance( ).
      advance( ).
    ELSEIF is_word( 'MATERIALIZED' ) = abap_true.
      lv_materialized = 'MATERIALIZED'.
      advance( ).
    ENDIF.

    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
    lo_statement = parse_select_statement( ).
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).

    ro_cte = NEW zcl_sqlite_ast_cte(
      iv_name         = lv_name
      it_columns      = lt_columns
      io_statement    = lo_statement
      iv_materialized = lv_materialized ).
  ENDMETHOD.

  METHOD is_select_start.
    rv_result = boolc(
      is_keyword( 'SELECT' ) = abap_true
      OR is_keyword( 'VALUES' ) = abap_true
      OR is_keyword( 'WITH' ) = abap_true ).
  ENDMETHOD.

  METHOD parse_values.
    DATA lt_rows TYPE zcl_sqlite_ast_values_row=>ty_list.
    DATA lo_row  TYPE REF TO zcl_sqlite_ast_values_row.

    expect_keyword( 'VALUES' ).
    DO.
      lo_row = parse_values_row( ).
      APPEND lo_row TO lt_rows.
      IF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true.
        advance( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.

    ro_statement = NEW zcl_sqlite_ast_values( it_rows = lt_rows ).
  ENDMETHOD.

  METHOD parse_values_row.
    DATA lt_values TYPE zcl_sqlite_ast_node=>ty_nodes.

    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
    IF is_kind( zcl_sqlite_tokenizer=>c_rparen ) = abap_true.
      fail( 'expected value' ).
    ENDIF.
    lt_values = parse_expression_list( ).
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).

    ro_row = NEW zcl_sqlite_ast_values_row( it_values = lt_values ).
  ENDMETHOD.

  METHOD parse_result_columns.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_result_column.

    DO.
      lo_column = parse_result_column( ).
      APPEND lo_column TO rt_columns.
      IF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true.
        advance( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.
  ENDMETHOD.

  METHOD parse_result_column.
    DATA lo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA lv_alias      TYPE string.

    lo_expression = parse_expression_internal( 0 ).
    lv_alias = parse_optional_alias( ).
    ro_column = NEW zcl_sqlite_ast_result_column(
      io_expression = lo_expression
      iv_alias      = lv_alias ).
  ENDMETHOD.

  METHOD parse_optional_alias.
    IF is_keyword( 'AS' ) = abap_true.
      advance( ).
      rv_alias = parse_alias_name( ).
    ELSEIF is_kind( zcl_sqlite_tokenizer=>c_identifier ) = abap_true.
      rv_alias = current( )-value.
      advance( ).
    ELSEIF is_kind( zcl_sqlite_tokenizer=>c_string ) = abap_true.
      rv_alias = current( )-value.
      advance( ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_alias_name.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    ls_token = current( ).
    IF ls_token-kind <> zcl_sqlite_tokenizer=>c_identifier
        AND ls_token-kind <> zcl_sqlite_tokenizer=>c_string
        AND ls_token-kind <> zcl_sqlite_tokenizer=>c_keyword.
      fail( 'expected alias' ).
    ENDIF.
    advance( ).
    rv_alias = ls_token-value.
  ENDMETHOD.

  METHOD parse_from_items.
    DATA lo_item TYPE REF TO zcl_sqlite_ast_node.

    DO.
      lo_item = parse_from_item( ).
      APPEND lo_item TO rt_items.
      IF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true.
        advance( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.
  ENDMETHOD.

  METHOD parse_from_item.
    DATA lo_left TYPE REF TO zcl_sqlite_ast_node.

    lo_left = parse_table_ref( ).
    WHILE is_join_start( ) = abap_true.
      lo_left = parse_join( lo_left ).
    ENDWHILE.
    ro_item = lo_left.
  ENDMETHOD.

  METHOD parse_table_ref.
    DATA lv_name      TYPE string.
    DATA lv_alias     TYPE string.
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.

    IF is_kind( zcl_sqlite_tokenizer=>c_lparen ) = abap_true.
      advance( ).
      lo_statement = parse_select_statement( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
      lv_alias = parse_optional_alias( ).
      ro_ref = NEW zcl_sqlite_ast_subquery_ref(
        io_statement = lo_statement
        iv_alias     = lv_alias ).
      RETURN.
    ENDIF.

    lv_name = parse_object_name( ).
    IF is_keyword( 'AS' ) = abap_true.
      advance( ).
      lv_alias = parse_alias_name( ).
    ELSEIF is_kind( zcl_sqlite_tokenizer=>c_identifier ) = abap_true.
      lv_alias = current( )-value.
      advance( ).
    ENDIF.

    ro_ref = NEW zcl_sqlite_ast_table_ref(
      iv_name  = lv_name
      iv_alias = lv_alias ).
  ENDMETHOD.

  METHOD parse_join.
    DATA lv_join_type TYPE string.
    DATA lo_right     TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_on        TYPE REF TO zcl_sqlite_ast_node.
    DATA lt_using     TYPE zcl_sqlite_ast_join=>ty_using.

    IF is_keyword( 'INNER' ) = abap_true.
      advance( ).
      expect_keyword( 'JOIN' ).
      lv_join_type = 'INNER JOIN'.
    ELSEIF is_keyword( 'LEFT' ) = abap_true.
      advance( ).
      IF is_keyword( 'OUTER' ) = abap_true.
        advance( ).
      ENDIF.
      expect_keyword( 'JOIN' ).
      lv_join_type = 'LEFT JOIN'.
    ELSEIF is_keyword( 'CROSS' ) = abap_true.
      advance( ).
      expect_keyword( 'JOIN' ).
      lv_join_type = 'CROSS JOIN'.
    ELSEIF is_keyword( 'JOIN' ) = abap_true.
      advance( ).
      lv_join_type = 'INNER JOIN'.
    ELSE.
      fail( 'expected JOIN' ).
    ENDIF.

    lo_right = parse_table_ref( ).
    IF is_keyword( 'ON' ) = abap_true.
      advance( ).
      lo_on = parse_expression_internal( 0 ).
    ELSEIF is_keyword( 'USING' ) = abap_true.
      advance( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
      lt_using = parse_name_list( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
    ENDIF.

    ro_join = NEW zcl_sqlite_ast_join(
      iv_join_type = lv_join_type
      io_left      = io_left
      io_right     = lo_right
      io_on        = lo_on
      it_using     = lt_using ).
  ENDMETHOD.

  METHOD is_join_start.
    rv_result = boolc(
      is_keyword( 'JOIN' ) = abap_true
      OR is_keyword( 'INNER' ) = abap_true
      OR is_keyword( 'LEFT' ) = abap_true
      OR is_keyword( 'CROSS' ) = abap_true ).
  ENDMETHOD.

  METHOD parse_expression_list.
    DATA lo_expression TYPE REF TO zcl_sqlite_ast_node.

    DO.
      lo_expression = parse_expression_internal( 0 ).
      APPEND lo_expression TO rt_expressions.
      IF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true.
        advance( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.
  ENDMETHOD.

  METHOD parse_order_by_list.
    DATA lo_order_by TYPE REF TO zcl_sqlite_ast_order_by.

    DO.
      lo_order_by = parse_order_by( ).
      APPEND lo_order_by TO rt_order_by.
      IF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true.
        advance( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.
  ENDMETHOD.

  METHOD parse_order_by.
    DATA lv_direction TYPE string.
    DATA lv_nulls     TYPE string.
    DATA lo_expression TYPE REF TO zcl_sqlite_ast_node.

    lo_expression = parse_expression_internal( 0 ).
    IF is_keyword( 'ASC' ) = abap_true OR is_keyword( 'DESC' ) = abap_true.
      lv_direction = current( )-value.
      advance( ).
    ENDIF.
    IF is_keyword( 'NULLS' ) = abap_true.
      advance( ).
      IF is_keyword( 'FIRST' ) = abap_true OR is_keyword( 'LAST' ) = abap_true.
        lv_nulls = current( )-value.
        advance( ).
      ELSE.
        fail( 'expected FIRST or LAST' ).
      ENDIF.
    ENDIF.

    ro_order_by = NEW zcl_sqlite_ast_order_by(
      io_expression = lo_expression
      iv_direction  = lv_direction
      iv_nulls      = lv_nulls ).
  ENDMETHOD.

  METHOD parse_column_def.
    DATA lv_name        TYPE string.
    DATA lv_type_name   TYPE string.
    DATA lt_constraints TYPE zcl_sqlite_ast_column_def=>ty_constraints.
    DATA lo_constraint  TYPE REF TO zcl_sqlite_ast_constraint.

    lv_name = parse_identifier( ).
    lv_type_name = parse_optional_type_name( ).
    WHILE is_column_constraint_start( ) = abap_true.
      lo_constraint = parse_column_constraint( ).
      APPEND lo_constraint TO lt_constraints.
    ENDWHILE.

    ro_column = NEW zcl_sqlite_ast_column_def(
      iv_name        = lv_name
      iv_type_name   = lv_type_name
      it_constraints = lt_constraints ).
  ENDMETHOD.

  METHOD parse_table_constraint.
    DATA lv_name          TYPE string.
    DATA lv_conflict      TYPE string.
    DATA lt_columns       TYPE zcl_sqlite_ast_node=>ty_names.
    DATA lt_indexed       TYPE zcl_sqlite_ast_indexed_column=>ty_list.
    DATA lo_expression    TYPE REF TO zcl_sqlite_ast_node.
    DATA ls_reference     TYPE zcl_sqlite_ast_constraint=>ty_reference.

    lv_name = parse_constraint_name( ).
    IF is_keyword( 'PRIMARY' ) = abap_true.
      advance( ).
      expect_keyword( 'KEY' ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
      lt_indexed = parse_indexed_columns( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
      lv_conflict = parse_conflict_clause( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind            = 'PRIMARY KEY'
        iv_name            = lv_name
        it_indexed_columns = lt_indexed
        iv_conflict        = lv_conflict ).
    ELSEIF is_keyword( 'UNIQUE' ) = abap_true.
      advance( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
      lt_indexed = parse_indexed_columns( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
      lv_conflict = parse_conflict_clause( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind            = 'UNIQUE'
        iv_name            = lv_name
        it_indexed_columns = lt_indexed
        iv_conflict        = lv_conflict ).
    ELSEIF is_keyword( 'CHECK' ) = abap_true.
      advance( ).
      lo_expression = parse_parenthesized( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind       = 'CHECK'
        iv_name       = lv_name
        io_expression = lo_expression ).
    ELSEIF is_keyword( 'FOREIGN' ) = abap_true.
      advance( ).
      expect_keyword( 'KEY' ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
      lt_columns = parse_name_list( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
      expect_keyword( 'REFERENCES' ).
      ls_reference = parse_reference_clause( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind      = 'FOREIGN KEY'
        iv_name      = lv_name
        it_columns   = lt_columns
        is_reference = ls_reference ).
    ELSE.
      fail( 'expected table constraint' ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_column_constraint.
    DATA lv_name        TYPE string.
    DATA lv_conflict    TYPE string.
    DATA lv_order       TYPE string.
    DATA lv_collation   TYPE string.
    DATA lv_storage     TYPE string.
    DATA lv_autoincrement TYPE abap_bool.
    DATA lo_expression  TYPE REF TO zcl_sqlite_ast_node.
    DATA ls_reference   TYPE zcl_sqlite_ast_constraint=>ty_reference.

    lv_name = parse_constraint_name( ).
    IF is_keyword( 'PRIMARY' ) = abap_true.
      advance( ).
      expect_keyword( 'KEY' ).
      IF is_keyword( 'ASC' ) = abap_true OR is_keyword( 'DESC' ) = abap_true.
        lv_order = current( )-value.
        advance( ).
      ENDIF.
      lv_conflict = parse_conflict_clause( ).
      IF is_keyword( 'AUTOINCREMENT' ) = abap_true.
        lv_autoincrement = abap_true.
        advance( ).
      ENDIF.
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind          = 'PRIMARY KEY'
        iv_name          = lv_name
        iv_order         = lv_order
        iv_conflict      = lv_conflict
        iv_autoincrement = lv_autoincrement ).
    ELSEIF is_keyword( 'NOT' ) = abap_true.
      advance( ).
      expect_keyword( 'NULL' ).
      lv_conflict = parse_conflict_clause( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind     = 'NOT NULL'
        iv_name     = lv_name
        iv_conflict = lv_conflict ).
    ELSEIF is_keyword( 'UNIQUE' ) = abap_true.
      advance( ).
      lv_conflict = parse_conflict_clause( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind     = 'UNIQUE'
        iv_name     = lv_name
        iv_conflict = lv_conflict ).
    ELSEIF is_keyword( 'CHECK' ) = abap_true.
      advance( ).
      lo_expression = parse_parenthesized( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind       = 'CHECK'
        iv_name       = lv_name
        io_expression = lo_expression ).
    ELSEIF is_keyword( 'DEFAULT' ) = abap_true.
      advance( ).
      lo_expression = parse_default_expression( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind       = 'DEFAULT'
        iv_name       = lv_name
        io_expression = lo_expression ).
    ELSEIF is_keyword( 'COLLATE' ) = abap_true.
      advance( ).
      lv_collation = parse_collation_name( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind      = 'COLLATE'
        iv_name      = lv_name
        iv_collation = lv_collation ).
    ELSEIF is_keyword( 'REFERENCES' ) = abap_true.
      advance( ).
      ls_reference = parse_reference_clause( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind      = 'REFERENCES'
        iv_name      = lv_name
        is_reference = ls_reference ).
    ELSEIF is_keyword( 'GENERATED' ) = abap_true.
      advance( ).
      IF is_keyword( 'ALWAYS' ) = abap_true.
        advance( ).
      ENDIF.
      expect_keyword( 'AS' ).
      lo_expression = parse_parenthesized( ).
      lv_storage = parse_optional_storage( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind       = 'GENERATED'
        iv_name       = lv_name
        io_expression = lo_expression
        iv_storage    = lv_storage ).
    ELSEIF is_keyword( 'AS' ) = abap_true.
      advance( ).
      lo_expression = parse_parenthesized( ).
      lv_storage = parse_optional_storage( ).
      ro_constraint = NEW zcl_sqlite_ast_constraint(
        iv_kind       = 'GENERATED'
        iv_name       = lv_name
        io_expression = lo_expression
        iv_storage    = lv_storage ).
    ELSE.
      fail( 'expected column constraint' ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_constraint_name.
    IF is_keyword( 'CONSTRAINT' ) = abap_false.
      RETURN.
    ENDIF.
    advance( ).
    rv_name = parse_identifier( ).
  ENDMETHOD.

  METHOD parse_conflict_clause.
    IF is_keyword( 'ON' ) = abap_false
        OR is_keyword_at( iv_ahead = 1 iv_keyword = 'CONFLICT' ) = abap_false.
      RETURN.
    ENDIF.

    advance( ).
    advance( ).
    CASE current( )-value.
      WHEN 'ROLLBACK' OR 'ABORT' OR 'FAIL' OR 'IGNORE' OR 'REPLACE'.
        rv_action = current( )-value.
        advance( ).
      WHEN OTHERS.
        fail( 'expected conflict action' ).
    ENDCASE.
  ENDMETHOD.

  METHOD parse_default_expression.
    IF is_kind( zcl_sqlite_tokenizer=>c_lparen ) = abap_true.
      ro_expression = parse_parenthesized( ).
    ELSE.
      ro_expression = parse_expression_internal( c_prec_unary ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_reference_clause.
    rs_reference-table_name = parse_object_name( ).
    IF is_kind( zcl_sqlite_tokenizer=>c_lparen ) = abap_true.
      advance( ).
      rs_reference-columns = parse_name_list( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
    ENDIF.
    parse_foreign_key_clauses( CHANGING cs_reference = rs_reference ).
  ENDMETHOD.

  METHOD parse_reference_action.
    IF is_keyword( 'SET' ) = abap_true.
      advance( ).
      IF is_keyword( 'NULL' ) = abap_true.
        rv_action = 'SET NULL'.
        advance( ).
      ELSEIF is_keyword( 'DEFAULT' ) = abap_true.
        rv_action = 'SET DEFAULT'.
        advance( ).
      ELSE.
        fail( 'expected NULL or DEFAULT' ).
      ENDIF.
    ELSEIF is_keyword( 'CASCADE' ) = abap_true OR is_keyword( 'RESTRICT' ) = abap_true.
      rv_action = current( )-value.
      advance( ).
    ELSEIF is_keyword( 'NO' ) = abap_true.
      advance( ).
      expect_keyword( 'ACTION' ).
      rv_action = 'NO ACTION'.
    ELSE.
      fail( 'expected foreign key action' ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_foreign_key_clauses.
    DO.
      IF is_keyword( 'ON' ) = abap_true.
        advance( ).
        IF is_keyword( 'DELETE' ) = abap_true.
          advance( ).
          cs_reference-on_delete = parse_reference_action( ).
        ELSEIF is_keyword( 'UPDATE' ) = abap_true.
          advance( ).
          cs_reference-on_update = parse_reference_action( ).
        ELSE.
          fail( 'expected DELETE or UPDATE' ).
        ENDIF.
      ELSEIF is_keyword( 'MATCH' ) = abap_true.
        advance( ).
        cs_reference-match_name = parse_identifier( ).
      ELSEIF is_keyword( 'NOT' ) = abap_true
          AND is_keyword_at( iv_ahead = 1 iv_keyword = 'DEFERRABLE' ) = abap_true.
        advance( ).
        advance( ).
        cs_reference-deferrable = 'NOT DEFERRABLE'.
      ELSEIF is_keyword( 'DEFERRABLE' ) = abap_true.
        advance( ).
        cs_reference-deferrable = 'DEFERRABLE'.
      ELSEIF is_keyword( 'INITIALLY' ) = abap_true.
        advance( ).
        IF is_keyword( 'DEFERRED' ) = abap_true OR is_keyword( 'IMMEDIATE' ) = abap_true.
          cs_reference-initially = current( )-value.
          advance( ).
        ELSE.
          fail( 'expected DEFERRED or IMMEDIATE' ).
        ENDIF.
      ELSE.
        EXIT.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD parse_indexed_column.
    DATA lv_name      TYPE string.
    DATA lv_collation TYPE string.
    DATA lv_order     TYPE string.

    lv_name = parse_identifier( ).
    IF is_keyword( 'COLLATE' ) = abap_true.
      advance( ).
      lv_collation = parse_collation_name( ).
    ENDIF.
    IF is_keyword( 'ASC' ) = abap_true OR is_keyword( 'DESC' ) = abap_true.
      lv_order = current( )-value.
      advance( ).
    ENDIF.

    ro_column = NEW zcl_sqlite_ast_indexed_column(
      iv_name      = lv_name
      iv_collation = lv_collation
      iv_order     = lv_order ).
  ENDMETHOD.

  METHOD parse_indexed_columns.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_indexed_column.

    IF is_kind( zcl_sqlite_tokenizer=>c_rparen ) = abap_true.
      fail( 'expected indexed column' ).
    ENDIF.

    DO.
      lo_column = parse_indexed_column( ).
      APPEND lo_column TO rt_columns.
      IF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true.
        advance( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.
  ENDMETHOD.

  METHOD parse_name_list.
    DATA lv_name TYPE string.

    IF is_kind( zcl_sqlite_tokenizer=>c_rparen ) = abap_true.
      fail( 'expected column name' ).
    ENDIF.

    DO.
      lv_name = parse_identifier( ).
      APPEND lv_name TO rt_names.
      IF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true.
        advance( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.
  ENDMETHOD.

  METHOD parse_optional_storage.
    IF is_word( 'VIRTUAL' ) = abap_true OR is_word( 'STORED' ) = abap_true.
      rv_storage = to_upper( current( )-value ).
      advance( ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_table_options.
    DO.
      IF is_word( 'WITHOUT' ) = abap_true.
        advance( ).
        expect_word( 'ROWID' ).
        cv_without_rowid = abap_true.
      ELSEIF is_word( 'STRICT' ) = abap_true.
        advance( ).
        cv_strict = abap_true.
      ELSEIF is_kind( zcl_sqlite_tokenizer=>c_comma ) = abap_true
          AND ( is_word_at( iv_ahead = 1 iv_word = 'WITHOUT' ) = abap_true
             OR is_word_at( iv_ahead = 1 iv_word = 'STRICT' ) = abap_true ).
        advance( ).
      ELSE.
        EXIT.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD parse_object_name.
    DATA lv_part TYPE string.

    rv_name = parse_identifier( ).
    WHILE is_kind( zcl_sqlite_tokenizer=>c_dot ) = abap_true.
      advance( ).
      lv_part = parse_identifier( ).
      rv_name = rv_name && '.' && lv_part.
    ENDWHILE.
  ENDMETHOD.

  METHOD parse_identifier.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    ls_token = current( ).
    IF ls_token-kind <> zcl_sqlite_tokenizer=>c_identifier
        AND ls_token-kind <> zcl_sqlite_tokenizer=>c_keyword.
      fail( 'expected identifier' ).
    ENDIF.
    advance( ).
    rv_name = ls_token-value.
  ENDMETHOD.

  METHOD parse_optional_type_name.
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

    IF rv_type IS NOT INITIAL
        AND current( )-kind = zcl_sqlite_tokenizer=>c_lparen.
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

  METHOD parse_collation_name.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    ls_token = current( ).
    IF ls_token-kind <> zcl_sqlite_tokenizer=>c_identifier
        AND ls_token-kind <> zcl_sqlite_tokenizer=>c_keyword.
      fail( 'expected collation name' ).
    ENDIF.
    advance( ).
    rv_name = to_upper( ls_token-value ).
  ENDMETHOD.

  METHOD is_table_constraint_start.
    rv_result = boolc(
      is_keyword( 'CONSTRAINT' ) = abap_true
      OR is_keyword( 'PRIMARY' ) = abap_true
      OR is_keyword( 'UNIQUE' ) = abap_true
      OR is_keyword( 'CHECK' ) = abap_true
      OR is_keyword( 'FOREIGN' ) = abap_true ).
  ENDMETHOD.

  METHOD is_column_constraint_start.
    rv_result = boolc(
      is_keyword( 'CONSTRAINT' ) = abap_true
      OR is_keyword( 'PRIMARY' ) = abap_true
      OR is_keyword( 'NOT' ) = abap_true
      OR is_keyword( 'UNIQUE' ) = abap_true
      OR is_keyword( 'CHECK' ) = abap_true
      OR is_keyword( 'DEFAULT' ) = abap_true
      OR is_keyword( 'COLLATE' ) = abap_true
      OR is_keyword( 'REFERENCES' ) = abap_true
      OR is_keyword( 'GENERATED' ) = abap_true
      OR is_keyword( 'AS' ) = abap_true ).
  ENDMETHOD.

  METHOD is_word.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    ls_token = current( ).
    rv_result = boolc(
      ( ls_token-kind = zcl_sqlite_tokenizer=>c_identifier
        OR ls_token-kind = zcl_sqlite_tokenizer=>c_keyword )
      AND to_upper( ls_token-value ) = to_upper( iv_word ) ).
  ENDMETHOD.

  METHOD is_word_at.
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.

    ls_token = token_at( iv_ahead ).
    rv_result = boolc(
      ( ls_token-kind = zcl_sqlite_tokenizer=>c_identifier
        OR ls_token-kind = zcl_sqlite_tokenizer=>c_keyword )
      AND to_upper( ls_token-value ) = to_upper( iv_word ) ).
  ENDMETHOD.

  METHOD expect_word.
    IF is_word( iv_word ) = abap_false.
      fail( |expected { iv_word }| ).
    ENDIF.
    advance( ).
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
    ELSEIF ls_token-kind = zcl_sqlite_tokenizer=>c_keyword
        AND ls_token-value = 'EXISTS'.
      ro_node = parse_exists( ).
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
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.

    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
    IF is_select_start( ) = abap_true.
      lo_statement = parse_select_statement( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
      ro_node = NEW zcl_sqlite_ast_subquery( io_statement = lo_statement ).
    ELSE.
      ro_node = parse_expression_internal( 0 ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_exists.
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.

    expect_keyword( 'EXISTS' ).
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
    lo_statement = parse_select_statement( ).
    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).

    ro_node = NEW zcl_sqlite_ast_exists( io_statement = lo_statement ).
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
    rv_type = parse_optional_type_name( ).
    IF rv_type IS INITIAL.
      fail( 'expected type name' ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_in.
    DATA lt_values TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA lo_value TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.

    expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_lparen iv_expected = '(' ).
    IF is_select_start( ) = abap_true.
      lo_statement = parse_select_statement( ).
      expect_kind( iv_kind = zcl_sqlite_tokenizer=>c_rparen iv_expected = ')' ).
      ro_node = NEW zcl_sqlite_ast_in(
        io_expression = io_expression
        it_values     = lt_values
        iv_negated    = iv_negated
        io_select     = lo_statement ).
      RETURN.
    ENDIF.

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
    DATA ls_token TYPE zcl_sqlite_tokenizer=>ty_token.
    DATA lv_text  TYPE string.

    ls_token = current( ).
    CASE ls_token-kind.
      WHEN zcl_sqlite_tokenizer=>c_eof.
        lv_text = 'incomplete input'.
      WHEN zcl_sqlite_tokenizer=>c_illegal.
        lv_text = |unrecognized token: "{ ls_token-text }"|.
      WHEN OTHERS.
        lv_text = |near "{ ls_token-text }": syntax error|.
    ENDCASE.

    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code     = zcx_sqlite_error=>sqlite_error
        iv_message  = lv_text
        iv_position = ls_token-offset
        iv_line     = ls_token-line
        iv_column   = ls_token-column.
  ENDMETHOD.

ENDCLASS.
