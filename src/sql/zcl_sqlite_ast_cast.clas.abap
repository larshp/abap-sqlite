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

    METHODS get_expression
      RETURNING VALUE(ro_expression) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_type
      RETURNING VALUE(rv_type) TYPE string.

  PRIVATE SECTION.
    DATA mo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_type       TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_cast IMPLEMENTATION.

  METHOD constructor.
    mo_expression = io_expression.
    mv_type = iv_type.
  ENDMETHOD.

  METHOD get_expression.
    ro_expression = mo_expression.
  ENDMETHOD.

  METHOD get_type.
    rv_type = mv_type.
  ENDMETHOD.

  METHOD dump.
    rv_text = |CAST({ mo_expression->dump( ) }, { mv_type })|.
  ENDMETHOD.

ENDCLASS.
