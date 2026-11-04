* A COLLATE postfix expression.
CLASS zcl_sqlite_ast_collate DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_expression TYPE REF TO zcl_sqlite_ast_node
                iv_name       TYPE string.

    METHODS dump REDEFINITION.

    METHODS get_expression
      RETURNING VALUE(ro_expression) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_name
      RETURNING VALUE(rv_name) TYPE string.

  PRIVATE SECTION.
    DATA mo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_name       TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_collate IMPLEMENTATION.

  METHOD constructor.
    mo_expression = io_expression.
    mv_name = iv_name.
  ENDMETHOD.

  METHOD get_expression.
    ro_expression = mo_expression.
  ENDMETHOD.

  METHOD get_name.
    rv_name = mv_name.
  ENDMETHOD.

  METHOD dump.
    rv_text = |COLLATE({ mo_expression->dump( ) }, { mv_name })|.
  ENDMETHOD.

ENDCLASS.
