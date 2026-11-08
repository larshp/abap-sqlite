* Nested-loop join of two child operators. The right side is materialized so it
* can be rescanned for every left row and null-extended for LEFT JOIN.
CLASS zcl_sqlite_join DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_operator.

    TYPES: BEGIN OF ty_column,
             name       TYPE string,
             table_name TYPE string,
             hidden     TYPE abap_bool,
           END OF ty_column.
    TYPES ty_columns TYPE STANDARD TABLE OF ty_column WITH DEFAULT KEY.
    TYPES ty_names TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING io_left          TYPE REF TO zif_sqlite_operator
                io_right         TYPE REF TO zif_sqlite_operator
                iv_join_type     TYPE string
                io_on            TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                it_using         TYPE ty_names OPTIONAL
                it_right_columns TYPE ty_columns OPTIONAL
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    DATA mo_left          TYPE REF TO zif_sqlite_operator.
    DATA mo_right         TYPE REF TO zif_sqlite_operator.
    DATA mv_join_type     TYPE string.
    DATA mo_on            TYPE REF TO zcl_sqlite_ast_node.
    DATA mt_using         TYPE ty_names.
    DATA mt_right_columns TYPE ty_columns.
    DATA mt_right_rows    TYPE STANDARD TABLE OF REF TO zcl_sqlite_row WITH DEFAULT KEY.
    DATA mv_left_ready    TYPE abap_bool.
    DATA mv_left_row      TYPE REF TO zcl_sqlite_row.
    DATA mv_right_index   TYPE i.
    DATA mv_matched       TYPE abap_bool.
    DATA mo_row           TYPE REF TO zcl_sqlite_row.

    METHODS load_right
      RAISING zcx_sqlite_error.

    METHODS matches
      IMPORTING io_left         TYPE REF TO zcl_sqlite_row
                io_right        TYPE REF TO zcl_sqlite_row
      RETURNING VALUE(rv_match) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS using_match
      IMPORTING io_left         TYPE REF TO zcl_sqlite_row
                io_right        TYPE REF TO zcl_sqlite_row
      RETURNING VALUE(rv_match) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS build_row
      IMPORTING io_left       TYPE REF TO zcl_sqlite_row
                io_right      TYPE REF TO zcl_sqlite_row OPTIONAL
                it_hidden     TYPE ty_names OPTIONAL
      RETURNING VALUE(ro_row) TYPE REF TO zcl_sqlite_row
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_join IMPLEMENTATION.

  METHOD constructor.
    IF io_left IS NOT BOUND OR io_right IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'join needs two child operators'.
    ENDIF.

    mo_left = io_left.
    mo_right = io_right.
    mv_join_type = iv_join_type.
    mo_on = io_on.
    mt_using = it_using.
    mt_right_columns = it_right_columns.
  ENDMETHOD.

  METHOD zif_sqlite_operator~open.
    mo_left->open( ).
    mo_right->open( ).
    load_right( ).
    CLEAR mv_left_row.
    mv_left_ready = abap_false.
    mv_right_index = 0.
    mv_matched = abap_false.
    CLEAR mo_row.
  ENDMETHOD.

  METHOD zif_sqlite_operator~next.
    DATA lo_right TYPE REF TO zcl_sqlite_row.

    DO.
      IF mv_left_ready = abap_false.
        IF mo_left->next( ) = abap_false.
          CLEAR mo_row.
          RETURN abap_false.
        ENDIF.
        mv_left_row = mo_left->row( ).
        mv_left_ready = abap_true.
        mv_right_index = 1.
        mv_matched = abap_false.
      ENDIF.

      WHILE mv_right_index <= lines( mt_right_rows ).
        READ TABLE mt_right_rows INTO lo_right INDEX mv_right_index.
        mv_right_index = mv_right_index + 1.
        IF matches(
            io_left  = mv_left_row
            io_right = lo_right ) = abap_true.
          mv_matched = abap_true.
          mo_row = build_row(
            io_left   = mv_left_row
            io_right  = lo_right
            it_hidden = mt_using ).
          RETURN abap_true.
        ENDIF.
      ENDWHILE.

      IF mv_join_type = 'LEFT JOIN' AND mv_matched = abap_false.
        mo_row = build_row(
          io_left   = mv_left_row
          it_hidden = mt_using ).
        mv_left_ready = abap_false.
        RETURN abap_true.
      ENDIF.

      mv_left_ready = abap_false.
    ENDDO.
  ENDMETHOD.

  METHOD zif_sqlite_operator~row.
    ro_row = mo_row.
  ENDMETHOD.

  METHOD load_right.
    CLEAR mt_right_rows.

    WHILE mo_right->next( ) = abap_true.
      APPEND mo_right->row( ) TO mt_right_rows.
    ENDWHILE.
  ENDMETHOD.

  METHOD matches.
    DATA lo_row   TYPE REF TO zcl_sqlite_row.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    IF mv_join_type = 'CROSS JOIN'.
      rv_match = abap_true.
      RETURN.
    ENDIF.

    IF mo_on IS BOUND.
      lo_row = build_row(
        io_left  = io_left
        io_right = io_right ).
      lo_value = zcl_sqlite_expr_eval=>evaluate(
        io_expression = mo_on
        io_context    = lo_row ).
      rv_match = zcl_sqlite_expr_eval=>is_true( lo_value ).
      RETURN.
    ENDIF.

    IF lines( mt_using ) = 0.
      rv_match = abap_true.
      RETURN.
    ENDIF.

    rv_match = using_match(
      io_left  = io_left
      io_right = io_right ).
  ENDMETHOD.

  METHOD using_match.
    DATA lo_context    TYPE REF TO zif_sqlite_eval_context.
    DATA lo_left_value TYPE REF TO zcl_sqlite_value.
    DATA lo_right_value TYPE REF TO zcl_sqlite_value.
    DATA lv_name       TYPE string.

    LOOP AT mt_using INTO lv_name.
      lo_context = io_left.
      lo_left_value = lo_context->value_of( lv_name ).
      lo_context = io_right.
      lo_right_value = lo_context->value_of( lv_name ).

      IF lo_left_value->is_null( ) = abap_true
          OR lo_right_value->is_null( ) = abap_true.
        RETURN.
      ENDIF.
      IF zcl_sqlite_expr_eval=>compare_values(
          io_left      = lo_left_value
          io_right     = lo_right_value
          iv_collation = 'BINARY' ) <> 0.
        RETURN.
      ENDIF.
    ENDLOOP.

    rv_match = abap_true.
  ENDMETHOD.

  METHOD build_row.
    DATA ls_column TYPE ty_column.
    DATA lv_hidden TYPE abap_bool.
    DATA lv_name   TYPE string.

    ro_row = NEW zcl_sqlite_row( ).
    ro_row->copy_cells( io_row = io_left ).

    IF io_right IS BOUND.
      ro_row->copy_cells(
        io_row    = io_right
        it_hidden = it_hidden ).
      RETURN.
    ENDIF.

    LOOP AT mt_right_columns INTO ls_column.
      lv_hidden = ls_column-hidden.
      LOOP AT it_hidden INTO lv_name.
        IF to_upper( ls_column-name ) = to_upper( lv_name ).
          lv_hidden = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      ro_row->add_cell(
        iv_name       = ls_column-name
        iv_table_name = ls_column-table_name
        io_value      = zcl_sqlite_value=>null( )
        iv_hidden     = lv_hidden ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
