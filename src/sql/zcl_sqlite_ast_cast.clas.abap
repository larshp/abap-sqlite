* A CAST expression with a normalized SQLite type name.
CLASS zcl_sqlite_ast_cast DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_expression TYPE REF TO zcl_sqlite_ast_node
                iv_type       TYPE string.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_type       TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_cast IMPLEMENTATION.

  METHOD constructor.
    mo_expression = io_expression.
    mv_type = iv_type.
  ENDMETHOD.

  METHOD dump.
    rv_text = |CAST({ mo_expression->dump( ) }, { mv_type })|.
  ENDMETHOD.

ENDCLASS.
