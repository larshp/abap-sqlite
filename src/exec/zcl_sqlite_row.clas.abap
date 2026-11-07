* One row of a query pipeline. Cells keep their column and table names so
* expressions can resolve unqualified and qualified column references.
CLASS zcl_sqlite_row DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_eval_context.

    TYPES ty_values TYPE zcl_sqlite_record=>ty_values.

    TYPES: BEGIN OF ty_cell,
             name       TYPE string,
             table_name TYPE string,
             value      TYPE REF TO zcl_sqlite_value,
             hidden     TYPE abap_bool,
           END OF ty_cell.
    TYPES ty_cells TYPE STANDARD TABLE OF ty_cell WITH DEFAULT KEY.
    TYPES ty_names TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    METHODS add_cell
      IMPORTING iv_name       TYPE string
                iv_table_name TYPE string OPTIONAL
                io_value      TYPE REF TO zcl_sqlite_value
                iv_hidden     TYPE abap_bool DEFAULT abap_false.

    METHODS cells
      RETURNING VALUE(rt_cells) TYPE ty_cells.

    METHODS copy_cells
      IMPORTING io_row    TYPE REF TO zcl_sqlite_row
                it_hidden TYPE ty_names OPTIONAL
                iv_null   TYPE abap_bool DEFAULT abap_false.

    METHODS values
      RETURNING VALUE(rt_values) TYPE ty_values.

  PRIVATE SECTION.
    DATA mt_cells TYPE ty_cells.

ENDCLASS.


CLASS zcl_sqlite_row IMPLEMENTATION.

  METHOD add_cell.
    DATA ls_cell TYPE ty_cell.

    ls_cell-name = iv_name.
    ls_cell-table_name = iv_table_name.
    ls_cell-value = io_value.
    ls_cell-hidden = iv_hidden.
    APPEND ls_cell TO mt_cells.
  ENDMETHOD.

  METHOD cells.
    rt_cells = mt_cells.
  ENDMETHOD.

  METHOD copy_cells.
    DATA ls_cell       TYPE ty_cell.
    DATA lv_hidden     TYPE abap_bool.
    DATA lv_hidden_name TYPE string.

    LOOP AT io_row->cells( ) INTO ls_cell.
      lv_hidden = ls_cell-hidden.
      LOOP AT it_hidden INTO lv_hidden_name.
        IF to_upper( ls_cell-name ) = to_upper( lv_hidden_name ).
          lv_hidden = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      ls_cell-hidden = lv_hidden.
      IF iv_null = abap_true.
        ls_cell-value = zcl_sqlite_value=>null( ).
      ENDIF.
      APPEND ls_cell TO mt_cells.
    ENDLOOP.
  ENDMETHOD.

  METHOD values.
    DATA ls_cell TYPE ty_cell.

    LOOP AT mt_cells INTO ls_cell.
      APPEND ls_cell-value TO rt_values.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_sqlite_eval_context~value_of.
    DATA ls_cell        TYPE ty_cell.
    DATA lo_match       TYPE REF TO zcl_sqlite_value.
    DATA lv_match_table TYPE string.
    DATA lv_matches     TYPE i.

    LOOP AT mt_cells INTO ls_cell.
      IF ls_cell-hidden = abap_true.
        CONTINUE.
      ENDIF.
      IF to_upper( ls_cell-name ) <> to_upper( iv_name ).
        CONTINUE.
      ENDIF.
      IF lv_matches = 0.
        lo_match = ls_cell-value.
        lv_match_table = ls_cell-table_name.
      ELSEIF to_upper( ls_cell-table_name ) <> to_upper( lv_match_table ).
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING iv_message = |ambiguous column name: { iv_name }|.
      ENDIF.
      lv_matches = lv_matches + 1.
    ENDLOOP.

    IF lv_matches > 0.
      ro_value = lo_match.
      RETURN.
    ENDIF.

    LOOP AT mt_cells INTO ls_cell.
      IF ls_cell-table_name IS NOT INITIAL
          AND to_upper( |{ ls_cell-table_name }.{ ls_cell-name }| ) = to_upper( iv_name ).
        ro_value = ls_cell-value.
        RETURN.
      ENDIF.
    ENDLOOP.

    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING iv_message = |no such column: { iv_name }|.
  ENDMETHOD.

  METHOD zif_sqlite_eval_context~aggregate.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING iv_message = |misuse of aggregate: { io_function->get_name( ) }()|.
  ENDMETHOD.

ENDCLASS.
