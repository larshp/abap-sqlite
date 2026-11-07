* A DELETE statement.
CLASS zcl_sqlite_ast_delete DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_table TYPE string
                iv_alias TYPE string OPTIONAL
                io_where TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_table TYPE string.
    DATA mv_alias TYPE string.
    DATA mo_where TYPE REF TO zcl_sqlite_ast_node.

ENDCLASS.


CLASS zcl_sqlite_ast_delete IMPLEMENTATION.

  METHOD constructor.
    mv_table = iv_table.
    mv_alias = iv_alias.
    mo_where = io_where.
  ENDMETHOD.

  METHOD dump.
    rv_text = |DELETE FROM { mv_table }|.
    IF mv_alias IS NOT INITIAL.
      rv_text = rv_text && | AS | && mv_alias.
    ENDIF.
    IF mo_where IS BOUND.
      rv_text = rv_text && | WHERE | && mo_where->dump( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
