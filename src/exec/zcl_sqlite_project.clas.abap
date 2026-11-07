* Evaluates the result columns of a SELECT for every row of a child operator.
* Without a child operator it produces exactly one row, which is what a
* SELECT without FROM needs.
CLASS zcl_sqlite_project DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_operator.

    TYPES: BEGIN OF ty_column,
             expression TYPE REF TO zcl_sqlite_ast_node,
             name       TYPE string,
           END OF ty_column.
    TYPES ty_columns TYPE STANDARD TABLE OF ty_column WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING io_source  TYPE REF TO zif_sqlite_operator OPTIONAL
                it_columns TYPE ty_columns.

  PRIVATE SECTION.
    DATA mo_source  TYPE REF TO zif_sqlite_operator.
    DATA mt_columns TYPE ty_columns.
    DATA mv_emitted TYPE abap_bool.
    DATA mo_row     TYPE REF TO zcl_sqlite_row.

    METHODS build_row
      RAISING zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_project IMPLEMENTATION.

  METHOD constructor.
    mo_source = io_source.
    mt_columns = it_columns.
  ENDMETHOD.

  METHOD zif_sqlite_operator~open.
    IF mo_source IS BOUND.
      mo_source->open( ).
    ENDIF.
    mv_emitted = abap_false.
    CLEAR mo_row.
  ENDMETHOD.

  METHOD zif_sqlite_operator~next.
    IF mo_source IS BOUND.
      IF mo_source->next( ) = abap_false.
        CLEAR mo_row.
        RETURN abap_false.
      ENDIF.
    ELSE.
      IF mv_emitted = abap_true.
        CLEAR mo_row.
        RETURN abap_false.
      ENDIF.
      mv_emitted = abap_true.
    ENDIF.

    build_row( ).
    RETURN abap_true.
  ENDMETHOD.

  METHOD zif_sqlite_operator~row.
    ro_row = mo_row.
  ENDMETHOD.

  METHOD build_row.
    DATA lo_context TYPE REF TO zif_sqlite_eval_context.
    DATA lo_row     TYPE REF TO zcl_sqlite_row.
    DATA ls_column  TYPE ty_column.
    DATA lo_value   TYPE REF TO zcl_sqlite_value.

    IF mo_source IS BOUND.
      lo_context = mo_source->row( ).
    ELSE.
      lo_context = NEW zcl_sqlite_row( ).
    ENDIF.

    lo_row = NEW zcl_sqlite_row( ).
    LOOP AT mt_columns INTO ls_column.
      lo_value = zcl_sqlite_expr_eval=>evaluate(
        io_expression = ls_column-expression
        io_context    = lo_context ).
      lo_row->add_cell(
        iv_name  = ls_column-name
        io_value = lo_value ).
    ENDLOOP.
    mo_row = lo_row.
  ENDMETHOD.

ENDCLASS.
