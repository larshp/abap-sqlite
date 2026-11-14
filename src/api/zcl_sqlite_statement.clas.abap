* Prepared statement implementation. The statement keeps the parsed SQL shape
* and renders bound values into SQLite literals before execution. This keeps
* parameter handling in one place and works for SELECT, DML and DDL.
CLASS zcl_sqlite_statement DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_statement.

    METHODS constructor
      IMPORTING io_database TYPE REF TO zcl_sqlite_database
                iv_sql      TYPE string
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_parameter,
             slot   TYPE i,
             offset TYPE i,
             length TYPE i,
           END OF ty_parameter,
           ty_parameters TYPE STANDARD TABLE OF ty_parameter WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_name_slot,
             name TYPE string,
             slot TYPE i,
           END OF ty_name_slot,
           ty_name_slots TYPE HASHED TABLE OF ty_name_slot WITH UNIQUE KEY name.

    TYPES: BEGIN OF ty_binding,
             slot  TYPE i,
             value TYPE REF TO zcl_sqlite_value,
           END OF ty_binding,
           ty_bindings TYPE HASHED TABLE OF ty_binding WITH UNIQUE KEY slot.

    DATA mo_database         TYPE REF TO zcl_sqlite_database.
    DATA mv_sql              TYPE string.
    DATA mv_is_query         TYPE abap_bool.
    DATA mv_parameter_count  TYPE i.
    DATA mv_executed         TYPE abap_bool.
    DATA mv_current_row      TYPE i.
    DATA mt_parameters       TYPE ty_parameters.
    DATA mt_name_slots       TYPE ty_name_slots.
    DATA mt_bindings         TYPE ty_bindings.
    DATA mt_columns          TYPE zcl_sqlite_database=>ty_column_names.
    DATA mt_rows             TYPE zcl_sqlite_database=>ty_rows.

    METHODS collect_parameters
      IMPORTING iv_sql TYPE string
      RAISING   zcx_sqlite_error.

    METHODS render_sql
      RETURNING VALUE(rv_sql) TYPE string.

    METHODS value_literal
      IMPORTING iv_slot           TYPE i
      RETURNING VALUE(rv_literal) TYPE string.

    METHODS quote_text
      IMPORTING iv_text           TYPE string
      RETURNING VALUE(rv_literal) TYPE string.

    METHODS current_value
      IMPORTING iv_index        TYPE i
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    METHODS check_column
      IMPORTING iv_index TYPE i
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_statement IMPLEMENTATION.

  METHOD constructor.
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.

    mo_database = io_database.
    mv_sql = iv_sql.

    lo_statement = zcl_sqlite_parser=>parse_statement( iv_sql ).
    mv_is_query = boolc( lo_statement IS INSTANCE OF zcl_sqlite_ast_select ).

    collect_parameters( iv_sql ).
  ENDMETHOD.

  METHOD collect_parameters.
    DATA lt_tokens       TYPE zcl_sqlite_tokenizer=>ty_tokens.
    DATA ls_token        TYPE zcl_sqlite_tokenizer=>ty_token.
    DATA ls_parameter    TYPE ty_parameter.
    DATA ls_name_slot    TYPE ty_name_slot.
    DATA lv_text         TYPE string.
    DATA lv_name         TYPE string.
    DATA lv_slot         TYPE i.
    DATA lv_next_index   TYPE i VALUE 1.

    lt_tokens = zcl_sqlite_tokenizer=>tokenize( iv_sql ).

    LOOP AT lt_tokens INTO ls_token.
      IF ls_token-kind <> zcl_sqlite_tokenizer=>c_parameter.
        CONTINUE.
      ENDIF.

      lv_text = ls_token-text.
      CLEAR lv_name.

      IF lv_text(1) = '?'.
        IF strlen( lv_text ) = 1.
          lv_slot = lv_next_index.
          lv_next_index = lv_next_index + 1.
        ELSE.
          lv_slot = CONV i( substring( val = lv_text
                                       off = 1 ) ).
          IF lv_slot <= 0.
            RAISE EXCEPTION TYPE zcx_sqlite_error
              EXPORTING
                iv_code    = zcx_sqlite_error=>sqlite_range
                iv_message = |invalid parameter index: { lv_text }|.
          ENDIF.
          IF lv_slot >= lv_next_index.
            lv_next_index = lv_slot + 1.
          ENDIF.
        ENDIF.
      ELSE.
        lv_name = to_upper( ls_token-value ).
        IF lv_name IS INITIAL.
          lv_name = to_upper( substring( val = lv_text
                                         off = 1 ) ).
        ENDIF.

        READ TABLE mt_name_slots INTO ls_name_slot WITH KEY name = lv_name.
        IF sy-subrc = 0.
          lv_slot = ls_name_slot-slot.
        ELSE.
          lv_slot = lv_next_index.
          lv_next_index = lv_next_index + 1.
          ls_name_slot-name = lv_name.
          ls_name_slot-slot = lv_slot.
          INSERT ls_name_slot INTO TABLE mt_name_slots.
        ENDIF.
      ENDIF.

      IF lv_slot > mv_parameter_count.
        mv_parameter_count = lv_slot.
      ENDIF.

      ls_parameter-slot = lv_slot.
      ls_parameter-offset = ls_token-offset.
      ls_parameter-length = ls_token-length.
      APPEND ls_parameter TO mt_parameters.
    ENDLOOP.
  ENDMETHOD.

  METHOD render_sql.
    DATA ls_parameter TYPE ty_parameter.
    DATA lv_position  TYPE i VALUE 0.
    DATA lv_start     TYPE i.
    DATA lv_length    TYPE i.

    LOOP AT mt_parameters INTO ls_parameter.
      lv_start = ls_parameter-offset - 1.
      lv_length = lv_start - lv_position.
      IF lv_length > 0.
        rv_sql = rv_sql && substring(
          val = mv_sql
          off = lv_position
          len = lv_length ).
      ENDIF.

      rv_sql = rv_sql && value_literal( ls_parameter-slot ).
      lv_position = lv_start + ls_parameter-length.
    ENDLOOP.

    lv_length = strlen( mv_sql ) - lv_position.
    IF lv_length > 0.
      rv_sql = rv_sql && substring(
        val = mv_sql
        off = lv_position
        len = lv_length ).
    ENDIF.
  ENDMETHOD.

  METHOD value_literal.
    DATA ls_binding TYPE ty_binding.
    DATA lo_value   TYPE REF TO zcl_sqlite_value.

    READ TABLE mt_bindings INTO ls_binding WITH KEY slot = iv_slot.
    IF sy-subrc <> 0 OR ls_binding-value IS NOT BOUND.
      rv_literal = 'NULL'.
      RETURN.
    ENDIF.

    lo_value = ls_binding-value.
    CASE lo_value->value_type( ).
      WHEN zcl_sqlite_value=>c_null.
        rv_literal = 'NULL'.
      WHEN zcl_sqlite_value=>c_integer.
        rv_literal = |{ lo_value->as_integer( ) }|.
      WHEN zcl_sqlite_value=>c_real.
        rv_literal = |{ lo_value->as_real( ) }|.
      WHEN zcl_sqlite_value=>c_text.
        rv_literal = quote_text( lo_value->as_text( ) ).
      WHEN zcl_sqlite_value=>c_blob.
        rv_literal = |x'{ lo_value->as_blob( ) }'|.
      WHEN OTHERS.
        rv_literal = 'NULL'.
    ENDCASE.
  ENDMETHOD.

  METHOD quote_text.
    DATA lv_quote  TYPE string.
    DATA lv_double TYPE string.

    lv_quote = ''''.
    lv_double = ''''''.
    rv_literal = lv_quote && replace(
      val  = iv_text
      sub  = lv_quote
      with = lv_double
      occ  = 0 ) && lv_quote.
  ENDMETHOD.

  METHOD zif_sqlite_statement~bind.
    DATA ls_binding   TYPE ty_binding.
    DATA ls_name_slot TYPE ty_name_slot.
    DATA lv_name      TYPE string.
    DATA lv_slot      TYPE i.

    IF iv_name IS NOT INITIAL AND iv_index > 0.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_misuse
          iv_message = 'bind by index or name, not both'.
    ENDIF.

    IF iv_name IS NOT INITIAL.
      lv_name = to_upper( iv_name ).
      READ TABLE mt_name_slots INTO ls_name_slot WITH KEY name = lv_name.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_range
            iv_message = |no such parameter: { iv_name }|.
      ENDIF.
      lv_slot = ls_name_slot-slot.
    ELSEIF iv_index > 0.
      IF iv_index > mv_parameter_count.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_range
            iv_message = |parameter index out of range: { iv_index }|.
      ENDIF.
      lv_slot = iv_index.
    ELSE.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_misuse
          iv_message = 'bind requires an index or a name'.
    ENDIF.

    ls_binding-slot = lv_slot.
    IF io_value IS BOUND.
      ls_binding-value = io_value.
    ELSE.
      ls_binding-value = zcl_sqlite_value=>null( ).
    ENDIF.

    READ TABLE mt_bindings TRANSPORTING NO FIELDS WITH KEY slot = lv_slot.
    IF sy-subrc = 0.
      MODIFY TABLE mt_bindings FROM ls_binding.
    ELSE.
      INSERT ls_binding INTO TABLE mt_bindings.
    ENDIF.
  ENDMETHOD.

  METHOD zif_sqlite_statement~step.
    DATA rs_result TYPE zcl_sqlite_database=>ty_result.

    IF mv_is_query = abap_true.
      IF mv_executed = abap_false.
        rs_result = mo_database->query( render_sql( ) ).
        mt_columns = rs_result-columns.
        mt_rows = rs_result-rows.
        mv_executed = abap_true.
        mv_current_row = 0.
      ENDIF.

      IF mv_current_row < lines( mt_rows ).
        mv_current_row = mv_current_row + 1.
        rv_found = abap_true.
      ENDIF.
    ELSEIF mv_executed = abap_false.
      mo_database->execute( render_sql( ) ).
      mv_executed = abap_true.

    ENDIF.
  ENDMETHOD.

  METHOD zif_sqlite_statement~column_count.
    rv_count = lines( mt_columns ).
  ENDMETHOD.

  METHOD check_column.
    IF iv_index < 1 OR iv_index > lines( mt_columns ).
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_range
          iv_message = |column index out of range: { iv_index }|.
    ENDIF.
  ENDMETHOD.

  METHOD current_value.
    DATA ls_row TYPE zcl_sqlite_database=>ty_row.

    IF mv_current_row = 0 OR mv_current_row > lines( mt_rows ).
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_misuse
          iv_message = 'statement has no current row'.
    ENDIF.

    check_column( iv_index ).

    READ TABLE mt_rows INTO ls_row INDEX mv_current_row.
    READ TABLE ls_row INTO ro_value INDEX iv_index.
    IF ro_value IS NOT BOUND.
      ro_value = zcl_sqlite_value=>null( ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_sqlite_statement~column_name.
    check_column( iv_index ).
    READ TABLE mt_columns INTO rv_name INDEX iv_index.
  ENDMETHOD.

  METHOD zif_sqlite_statement~column_type.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = current_value( iv_index ).
    rv_type = lo_value->value_type( ).
  ENDMETHOD.

  METHOD zif_sqlite_statement~column_value.
    ro_value = current_value( iv_index ).
  ENDMETHOD.

  METHOD zif_sqlite_statement~reset.
    CLEAR mv_executed.
    CLEAR mv_current_row.
    CLEAR mt_columns.
    CLEAR mt_rows.
  ENDMETHOD.

ENDCLASS.
