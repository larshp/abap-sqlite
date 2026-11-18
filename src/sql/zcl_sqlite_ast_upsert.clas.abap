* One ON CONFLICT clause of an INSERT statement.
CLASS zcl_sqlite_ast_upsert DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_target_columns TYPE zcl_sqlite_ast_indexed_column=>ty_list.
    TYPES ty_assignments TYPE zcl_sqlite_ast_assignment=>ty_list.

    METHODS constructor
      IMPORTING it_target_columns TYPE ty_target_columns OPTIONAL
                io_target_where   TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                iv_action         TYPE string
                it_assignments    TYPE ty_assignments OPTIONAL
                io_where          TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

    METHODS dump REDEFINITION.

    METHODS get_target_columns
      RETURNING VALUE(rt_target_columns) TYPE ty_target_columns.

    METHODS get_target_where
      RETURNING VALUE(ro_target_where) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_action
      RETURNING VALUE(rv_action) TYPE string.

    METHODS get_assignments
      RETURNING VALUE(rt_assignments) TYPE ty_assignments.

    METHODS get_where
      RETURNING VALUE(ro_where) TYPE REF TO zcl_sqlite_ast_node.

  PRIVATE SECTION.
    DATA mt_target_columns TYPE ty_target_columns.
    DATA mo_target_where   TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_action         TYPE string.
    DATA mt_assignments    TYPE ty_assignments.
    DATA mo_where          TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump_assignments
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_upsert IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mt_target_columns = it_target_columns.
    mo_target_where = io_target_where.
    mv_action = iv_action.
    mt_assignments = it_assignments.
    mo_where = io_where.
  ENDMETHOD.

  METHOD dump.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_indexed_column.
    DATA lv_columns TYPE string.

    rv_text = |ON CONFLICT|.
    IF lines( mt_target_columns ) > 0.
      LOOP AT mt_target_columns INTO lo_column.
        IF lv_columns IS NOT INITIAL.
          lv_columns = lv_columns && |, |.
        ENDIF.
        lv_columns = lv_columns && lo_column->dump( ).
      ENDLOOP.
      rv_text = rv_text && | (| && lv_columns && |)|.
    ENDIF.
    IF mo_target_where IS BOUND.
      rv_text = rv_text && | WHERE | && mo_target_where->dump( ).
    ENDIF.
    rv_text = rv_text && | DO | && mv_action.
    IF mv_action = 'UPDATE'.
      rv_text = rv_text && | SET | && dump_assignments( ).
      IF mo_where IS BOUND.
        rv_text = rv_text && | WHERE | && mo_where->dump( ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD dump_assignments.
    DATA lo_assignment TYPE REF TO zcl_sqlite_ast_assignment.

    LOOP AT mt_assignments INTO lo_assignment.
      IF rv_text IS NOT INITIAL.
        rv_text = rv_text && |, |.
      ENDIF.
      rv_text = rv_text && lo_assignment->dump( ).
    ENDLOOP.
  ENDMETHOD.

  METHOD get_target_columns.
    rt_target_columns = mt_target_columns.
  ENDMETHOD.

  METHOD get_target_where.
    ro_target_where = mo_target_where.
  ENDMETHOD.

  METHOD get_action.
    rv_action = mv_action.
  ENDMETHOD.

  METHOD get_assignments.
    rt_assignments = mt_assignments.
  ENDMETHOD.

  METHOD get_where.
    ro_where = mo_where.
  ENDMETHOD.

ENDCLASS.
