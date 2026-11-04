* A CREATE INDEX statement.
CLASS zcl_sqlite_ast_create_index DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_columns TYPE zcl_sqlite_ast_indexed_column=>ty_list.

    METHODS constructor
      IMPORTING iv_name          TYPE string
                iv_table_name    TYPE string
                iv_unique        TYPE abap_bool DEFAULT abap_false
                iv_if_not_exists TYPE abap_bool DEFAULT abap_false
                it_columns       TYPE ty_columns OPTIONAL
                io_where         TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

    METHODS get_name
      RETURNING VALUE(rv_name) TYPE string.

    METHODS get_table_name
      RETURNING VALUE(rv_table_name) TYPE string.

    METHODS is_unique
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS get_columns
      RETURNING VALUE(rt_columns) TYPE ty_columns.

    METHODS get_where
      RETURNING VALUE(ro_where) TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_name          TYPE string.
    DATA mv_table_name    TYPE string.
    DATA mv_unique        TYPE abap_bool.
    DATA mv_if_not_exists TYPE abap_bool.
    DATA mt_columns       TYPE ty_columns.
    DATA mo_where         TYPE REF TO zcl_sqlite_ast_node.

ENDCLASS.


CLASS zcl_sqlite_ast_create_index IMPLEMENTATION.

  METHOD constructor.
    mv_name = iv_name.
    mv_table_name = iv_table_name.
    mv_unique = iv_unique.
    mv_if_not_exists = iv_if_not_exists.
    mt_columns = it_columns.
    mo_where = io_where.
  ENDMETHOD.

  METHOD get_name.
    rv_name = mv_name.
  ENDMETHOD.

  METHOD get_table_name.
    rv_table_name = mv_table_name.
  ENDMETHOD.

  METHOD is_unique.
    rv_result = mv_unique.
  ENDMETHOD.

  METHOD get_columns.
    rt_columns = mt_columns.
  ENDMETHOD.

  METHOD get_where.
    ro_where = mo_where.
  ENDMETHOD.

  METHOD dump.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_indexed_column.
    DATA lv_columns TYPE string.

    rv_text = |CREATE |.
    IF mv_unique = abap_true.
      rv_text = rv_text && |UNIQUE |.
    ENDIF.
    rv_text = rv_text && |INDEX |.
    IF mv_if_not_exists = abap_true.
      rv_text = rv_text && |IF NOT EXISTS |.
    ENDIF.
    rv_text = rv_text && mv_name && | ON | && mv_table_name && | (|.

    LOOP AT mt_columns INTO lo_column.
      IF lv_columns IS NOT INITIAL.
        " ANORMALY: character literals lose trailing blanks when concatenated
        lv_columns = lv_columns && |, |.
      ENDIF.
      lv_columns = lv_columns && lo_column->dump( ).
    ENDLOOP.
    rv_text = rv_text && lv_columns && |)|.

    IF mo_where IS BOUND.
      rv_text = rv_text && | WHERE | && mo_where->dump( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
