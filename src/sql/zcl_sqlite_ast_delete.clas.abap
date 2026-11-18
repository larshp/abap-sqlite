* A DELETE statement.
CLASS zcl_sqlite_ast_delete DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_returning TYPE zcl_sqlite_ast_result_column=>ty_list.

    METHODS constructor
      IMPORTING iv_table     TYPE string
                iv_alias     TYPE string OPTIONAL
                io_where     TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                it_returning TYPE ty_returning OPTIONAL.

    METHODS dump REDEFINITION.

    METHODS get_table
      RETURNING VALUE(rv_table) TYPE string.

    METHODS get_alias
      RETURNING VALUE(rv_alias) TYPE string.

    METHODS get_where
      RETURNING VALUE(ro_where) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_returning
      RETURNING VALUE(rt_returning) TYPE ty_returning.

  PRIVATE SECTION.
    DATA mv_table     TYPE string.
    DATA mv_alias     TYPE string.
    DATA mo_where     TYPE REF TO zcl_sqlite_ast_node.
    DATA mt_returning TYPE ty_returning.

ENDCLASS.


CLASS zcl_sqlite_ast_delete IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_table = iv_table.
    mv_alias = iv_alias.
    mo_where = io_where.
    mt_returning = it_returning.
  ENDMETHOD.

  METHOD dump.
    rv_text = |DELETE FROM { mv_table }|.
    IF mv_alias IS NOT INITIAL.
      rv_text = rv_text && | AS | && mv_alias.
    ENDIF.
    IF mo_where IS BOUND.
      rv_text = rv_text && | WHERE | && mo_where->dump( ).
    ENDIF.
    IF lines( mt_returning ) > 0.
      rv_text = rv_text && | RETURNING |.
      LOOP AT mt_returning INTO DATA(lo_returning).
        IF sy-tabix > 1.
          rv_text = rv_text && |, |.
        ENDIF.
        rv_text = rv_text && lo_returning->dump( ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD get_table.
    rv_table = mv_table.
  ENDMETHOD.

  METHOD get_alias.
    rv_alias = mv_alias.
  ENDMETHOD.

  METHOD get_where.
    ro_where = mo_where.
  ENDMETHOD.

  METHOD get_returning.
    rt_returning = mt_returning.
  ENDMETHOD.

ENDCLASS.
