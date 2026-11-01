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
    IF lo_parser->is_keyword( 'CREATE' ) = abap_true.
      ro_statement = lo_parser->parse_create( ).
    ELSEIF lo_parser->is_keyword( 'DROP' ) = abap_true.
      ro_statement = lo_parser->parse_drop( ).
    ELSE.
      lo_parser->fail( 'expected CREATE or DROP' ).
    ENDIF.

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
    rv_type = parse_optional_type_name( ).
    IF rv_type IS INITIAL.
      fail( 'expected type name' ).
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
