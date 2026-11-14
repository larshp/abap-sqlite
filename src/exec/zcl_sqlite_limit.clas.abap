* Applies LIMIT and OFFSET to a child operator.
CLASS zcl_sqlite_limit DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_operator.

    METHODS constructor
      IMPORTING io_source TYPE REF TO zif_sqlite_operator
                io_limit  TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                io_offset TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

  PRIVATE SECTION.
    DATA mo_source    TYPE REF TO zif_sqlite_operator.
    DATA mo_limit     TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_offset    TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_limit     TYPE int8.
    DATA mv_offset    TYPE int8.
    DATA mv_skipped   TYPE int8.
    DATA mv_emitted   TYPE int8.
    DATA mv_has_limit TYPE abap_bool.

    METHODS evaluate_count
      IMPORTING io_expression   TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS is_integer_text
      IMPORTING iv_text         TYPE string
      RETURNING VALUE(rv_valid) TYPE abap_bool.

    METHODS is_space_char
      IMPORTING iv_char          TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

ENDCLASS.


CLASS zcl_sqlite_limit IMPLEMENTATION.

  METHOD constructor.
    mo_source = io_source.
    mo_limit = io_limit.
    mo_offset = io_offset.
  ENDMETHOD.

  METHOD zif_sqlite_operator~open.
    mo_source->open( ).
    mv_skipped = 0.
    mv_emitted = 0.

    IF mo_offset IS BOUND.
      mv_offset = evaluate_count( mo_offset ).
      IF mv_offset < 0.
        mv_offset = 0.
      ENDIF.
    ELSE.
      mv_offset = 0.
    ENDIF.

    IF mo_limit IS BOUND.
      mv_limit = evaluate_count( mo_limit ).
      IF mv_limit < 0.
        mv_has_limit = abap_false.
      ELSE.
        mv_has_limit = abap_true.
      ENDIF.
    ELSE.
      mv_limit = 0.
      mv_has_limit = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD zif_sqlite_operator~next.
    WHILE mv_skipped < mv_offset.
      IF mo_source->next( ) = abap_false.
        RETURN abap_false.
      ENDIF.
      mv_skipped = mv_skipped + 1.
    ENDWHILE.

    IF mv_has_limit = abap_true AND mv_emitted >= mv_limit.
      RETURN abap_false.
    ENDIF.

    IF mo_source->next( ) = abap_false.
      RETURN abap_false.
    ENDIF.

    mv_emitted = mv_emitted + 1.
    RETURN abap_true.
  ENDMETHOD.

  METHOD zif_sqlite_operator~row.
    ro_row = mo_source->row( ).
  ENDMETHOD.

  METHOD evaluate_count.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lv_real  TYPE f.
    DATA lv_floor TYPE f.
    DATA lv_text  TYPE string.

    lo_value = zcl_sqlite_expr_eval=>evaluate( io_expression ).
    IF lo_value->is_null( ) = abap_true.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_mismatch
          iv_message = 'datatype mismatch'.
    ENDIF.

    CASE lo_value->value_type( ).
      WHEN zcl_sqlite_value=>c_integer.
        rv_value = lo_value->as_integer( ).
      WHEN zcl_sqlite_value=>c_real.
        lv_real = lo_value->as_real( ).
        lv_floor = floor( lv_real ).
        IF lv_real <> lv_floor.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_mismatch
              iv_message = 'datatype mismatch'.
        ENDIF.
        rv_value = zcl_sqlite_expr_eval=>value_to_integer( lo_value ).
      WHEN zcl_sqlite_value=>c_text.
        lv_text = lo_value->as_text( ).
        IF is_integer_text( lv_text ) = abap_false.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_mismatch
              iv_message = 'datatype mismatch'.
        ENDIF.
        rv_value = zcl_sqlite_expr_eval=>value_to_integer( lo_value ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_mismatch
            iv_message = 'datatype mismatch'.
    ENDCASE.
  ENDMETHOD.

  METHOD is_integer_text.
    DATA lv_length TYPE i.
    DATA lv_index  TYPE i.
    DATA lv_start  TYPE i.
    DATA lv_end    TYPE i.
    DATA lv_char   TYPE string.

    lv_length = strlen( iv_text ).
    IF lv_length = 0.
      RETURN.
    ENDIF.

    lv_start = 0.
    WHILE lv_start < lv_length.
      lv_char = substring( val = iv_text
                           off = lv_start
                           len = 1 ).
      IF is_space_char( lv_char ) = abap_false.
        EXIT.
      ENDIF.
      lv_start = lv_start + 1.
    ENDWHILE.

    lv_end = lv_length.
    WHILE lv_end > lv_start.
      lv_char = substring( val = iv_text
                           off = lv_end - 1
                           len = 1 ).
      IF is_space_char( lv_char ) = abap_false.
        EXIT.
      ENDIF.
      lv_end = lv_end - 1.
    ENDWHILE.

    IF lv_start >= lv_end.
      RETURN.
    ENDIF.

    lv_char = substring( val = iv_text
                         off = lv_start
                         len = 1 ).
    IF lv_char = |+| OR lv_char = |-|.
      lv_start = lv_start + 1.
    ENDIF.
    IF lv_start >= lv_end.
      RETURN.
    ENDIF.

    lv_index = lv_start.
    WHILE lv_index < lv_end.
      lv_char = substring( val = iv_text
                           off = lv_index
                           len = 1 ).
      IF lv_char < |0| OR lv_char > |9|.
        RETURN.
      ENDIF.
      lv_index = lv_index + 1.
    ENDWHILE.

    rv_valid = abap_true.
  ENDMETHOD.

  METHOD is_space_char.
    rv_result = boolc(
      iv_char = | |
      OR iv_char = cl_abap_char_utilities=>horizontal_tab
      OR iv_char = cl_abap_char_utilities=>vertical_tab
      OR iv_char = cl_abap_char_utilities=>newline
      OR iv_char = cl_abap_char_utilities=>form_feed
      OR iv_char = substring( val = cl_abap_char_utilities=>cr_lf
                              len = 1 ) ).
  ENDMETHOD.

ENDCLASS.
