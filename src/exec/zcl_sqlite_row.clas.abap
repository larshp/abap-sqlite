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
           END OF ty_cell.
    TYPES ty_cells TYPE STANDARD TABLE OF ty_cell WITH DEFAULT KEY.

    METHODS add_cell
      IMPORTING iv_name       TYPE string
                iv_table_name TYPE string OPTIONAL
                io_value      TYPE REF TO zcl_sqlite_value.

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
    APPEND ls_cell TO mt_cells.
  ENDMETHOD.

  METHOD values.
    DATA ls_cell TYPE ty_cell.

    LOOP AT mt_cells INTO ls_cell.
      APPEND ls_cell-value TO rt_values.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_sqlite_eval_context~value_of.
    DATA ls_cell TYPE ty_cell.

    LOOP AT mt_cells INTO ls_cell.
      IF to_upper( ls_cell-name ) = to_upper( iv_name ).
        ro_value = ls_cell-value.
        RETURN.
      ENDIF.
      IF ls_cell-table_name IS NOT INITIAL
          AND to_upper( |{ ls_cell-table_name }.{ ls_cell-name }| ) = to_upper( iv_name ).
        ro_value = ls_cell-value.
        RETURN.
      ENDIF.
    ENDLOOP.

    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING iv_message = |no such column: { iv_name }|.
  ENDMETHOD.

ENDCLASS.
