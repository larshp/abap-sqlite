* Replays a materialized result as a query operator. Used for subqueries in
* FROM and for other result sets that have already been evaluated.
CLASS zcl_sqlite_row_source DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_operator.

    METHODS constructor
      IMPORTING it_columns TYPE zcl_sqlite_join=>ty_columns
                it_rows    TYPE zif_sqlite_subquery_runner=>ty_rows
                io_outer   TYPE REF TO zif_sqlite_eval_context OPTIONAL.

  PRIVATE SECTION.
    DATA mt_columns TYPE zcl_sqlite_join=>ty_columns.
    DATA mt_rows    TYPE zif_sqlite_subquery_runner=>ty_rows.
    DATA mo_outer   TYPE REF TO zif_sqlite_eval_context.
    DATA mv_index   TYPE i.
    DATA mo_row     TYPE REF TO zcl_sqlite_row.

    METHODS build_row
      IMPORTING it_values     TYPE zcl_sqlite_record=>ty_values
      RETURNING VALUE(ro_row) TYPE REF TO zcl_sqlite_row.

ENDCLASS.


CLASS zcl_sqlite_row_source IMPLEMENTATION.

  METHOD constructor.
    mt_columns = it_columns.
    mt_rows = it_rows.
    mo_outer = io_outer.
  ENDMETHOD.

  METHOD zif_sqlite_operator~open.
    mv_index = 0.
    CLEAR mo_row.
  ENDMETHOD.

  METHOD zif_sqlite_operator~next.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.

    mv_index = mv_index + 1.
    IF mv_index > lines( mt_rows ).
      CLEAR mo_row.
      RETURN abap_false.
    ENDIF.

    READ TABLE mt_rows INTO lt_values INDEX mv_index.
    mo_row = build_row( lt_values ).
    RETURN abap_true.
  ENDMETHOD.

  METHOD zif_sqlite_operator~row.
    ro_row = mo_row.
  ENDMETHOD.

  METHOD build_row.
    DATA ls_column TYPE zcl_sqlite_join=>ty_column.
    DATA lo_value  TYPE REF TO zcl_sqlite_value.
    DATA lv_index  TYPE i.

    ro_row = NEW zcl_sqlite_row( ).
    IF mo_outer IS BOUND.
      ro_row->set_outer_context( mo_outer ).
    ENDIF.

    LOOP AT mt_columns INTO ls_column.
      lv_index = lv_index + 1.
      READ TABLE it_values INTO lo_value INDEX lv_index.
      IF sy-subrc <> 0.
        lo_value = zcl_sqlite_value=>null( ).
      ENDIF.
      ro_row->add_cell(
        iv_name       = ls_column-name
        iv_table_name = ls_column-table_name
        io_value      = lo_value
        iv_collation  = ls_column-collation
        iv_hidden     = ls_column-hidden ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
